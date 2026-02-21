import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wurp/logic/feed_recommendation/user_interaction.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/main.dart';

class LocalSeenService {
  static const String _seenBoxName = 'seen_videos';
  static const String _settingsBoxName = 'seen_settings';
  static const String _cursorBoxName = 'feed_cursors';
  static const String _interactionBoxName = 'seen_interactions';
  static const double maxLocalStorage = 5e7; //50k

  late Box<DateTime> _seenBox;
  late Box _settingsBox;
  late Box _cursorBox;
  late Box _interactionBox;

  late final String userId;
  
  static bool hiveInitialized = false;

  Future<void> init() async {
    print("starting initialization of LocalSeenService...");
    userId = auth!.currentUser!.uid;
    
    if(!hiveInitialized) {
      await Hive.initFlutter("user_$userId");
      hiveInitialized = true;
    }
    
    _seenBox = await Hive.openBox<DateTime>('${userId}_$_seenBoxName');
    _settingsBox = await Hive.openBox('${userId}_$_settingsBoxName');
    _cursorBox = await Hive.openBox('${userId}_$_cursorBoxName');
    _interactionBox = await Hive.openBox('${userId}_$_interactionBoxName');

    await _cursorBox.clear();
    await _seenBox.clear();
    await _interactionBox.clear();

    print("cleared!");

    await syncWithFirestore();
    await cleanUpOldEntries();
    print("initialized LocalSeenService with ${_seenBox.length} seen videos for user $userId, last sync: ${_settingsBox.get('lastSyncTimestamp')}");
  }
  
  Future<void> dispose() {
    return Hive.close();
  }

  void markAsSeen(Video video) {
    _seenBox.put(video.id, DateTime.now());
    _interactionBox.put(video.id, {
      'authorId': video.authorId,
      'tags': video.tags,
    });
  }

  bool hasSeen(String videoId) => _seenBox.containsKey(videoId);

  Set<String> get allSeenIds => _seenBox.keys.cast<String>().toSet();

  List<UserInteraction> getRecentInteractionsLocal({int limit = 50}) {
    final entries = _seenBox.toMap().entries.toList();

    entries.sort((a, b) => (b.value).compareTo(a.value));

    return entries.take(limit).map((e) {
      final videoId = e.key as String;
      final seenAt = e.value;
      final meta = _interactionBox.get(videoId) as Map?;

      return UserInteraction(
        videoId: videoId,
        authorId: meta?['authorId'] as String? ?? '',
        tags: meta?['tags'] != null ? List<String>.from(meta!['tags'] as List) : [],
        watchTime: 0,
        //dummy values bc those are not stored
        videoDuration: 1,
        timestamp: seenAt,
      );
    }).toList();
  }

  Future<void> cleanUpOldEntries() async {
    if (_seenBox.length <= 5000) return;

    final entries = _seenBox.toMap().entries.toList();
    entries.sort((a, b) => (a.value).compareTo(b.value));

    final amountToDelete = _seenBox.length - 5000;
    final keysToDelete = entries.take(amountToDelete).map((e) => e.key as String).toList();

    await _seenBox.deleteAll(keysToDelete);
    await _interactionBox.deleteAll(keysToDelete);
  }

  Future<void> syncWithFirestore({bool onlyLoad = true}) async {
    final lastSync = _settingsBox.get('lastSyncTimestamp') as DateTime? ?? DateTime.now().subtract(const Duration(days: 7));

    if (!onlyLoad) {
      print("Uploading local changes to Firestore...");

      final localEntries = Map<String, DateTime>.from(
        _seenBox.toMap()..removeWhere((key, value) => (value).isBefore(lastSync)),
      );

      final batch = firestore.batch();
      int uploadCount = 0;

      final docRef = firestore.collection('users').doc(userId).collection('recent_interactions');

      for (final entry in localEntries.entries) {
        final meta = _interactionBox.get(entry.key) as Map?;
        batch.set(
          docRef.doc(entry.key),
          {
            'videoId': entry.key,
            'timestamp': Timestamp.fromDate(entry.value),
            if (meta != null) 'authorId': meta['authorId'],
            if (meta != null) 'tags': meta['tags'],
          },
          SetOptions(merge: true),
        );
        uploadCount++;
      }

      if (uploadCount > 0) await batch.commit();
      print("Uploaded $uploadCount local entries");
    }

    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('recent_interactions')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(lastSync))
        .orderBy('timestamp', descending: true)
        .get();

    if (snapshot.docs.isEmpty) {
      print("Nothing new from Firestore");
      return;
    }

    final Map<String, DateTime> newSeenEntries = {};
    final Map<String, Map<String, dynamic>> newInteractionEntries = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final videoId = data['videoId'] as String;
      final seenAt = (data['timestamp'] as Timestamp).toDate();

      final local = _seenBox.get(videoId);
      if (local == null || seenAt.isAfter(local)) {
        newSeenEntries[videoId] = seenAt;
        newInteractionEntries[videoId] = {
          'authorId': data['authorId'] ?? '',
          'tags': data['tags'] ?? [],
        };
      }
    }

    print("Syncing ${newSeenEntries.length} entries from Firestore...");
    await _seenBox.putAll(newSeenEntries);
    await _interactionBox.putAll(newInteractionEntries);

    final Map<String, DateTime> tagOldestSeen = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final tags = data['tags'] != null ? List<String>.from(data['tags'] as List) : <String>[];
      final seenAt = (data['timestamp'] as Timestamp).toDate();

      for (final tag in tags) {
        if (!tagOldestSeen.containsKey(tag) || seenAt.isBefore(tagOldestSeen[tag]!)) {
          tagOldestSeen[tag] = seenAt;
        }
      }
    }

    for (final entry in tagOldestSeen.entries) {
      final existing = getTagCursor(entry.key);
      if (existing == null || entry.value.isBefore(existing)) {
        await saveTagCursor(entry.key, entry.value);
      }
    }
    print("Updated tag cursors for ${tagOldestSeen.length} tags");

    final latestTime = (snapshot.docs.first.data()['timestamp'] as Timestamp).toDate();
    await _settingsBox.put('lastSyncTimestamp', latestTime);
  }

  DateTime? getNewestSeenTimestamp() => _cursorBox.get('newestSeenTimestamp') as DateTime?;

  Future<void> saveNewestSeenTimestamp(DateTime timestamp) async => _cursorBox.put('newestSeenTimestamp', timestamp);

  DateTime? getOldestSeenTimestamp() => _cursorBox.get('oldestSeenTimestamp') as DateTime?;

  Future<void> saveOldestSeenTimestamp(DateTime timestamp) async => _cursorBox.put('oldestSeenTimestamp', timestamp);

  DateTime? getTrendingCursor() => _cursorBox.get('trendingCursor') as DateTime?;

  Future<void> saveTrendingCursor(DateTime timestamp) async => _cursorBox.put('trendingCursor', timestamp);

  Future<void> resetCursors() async => _cursorBox.clear();

  DateTime? getTagCursor(String tag) => _cursorBox.get('tag_cursor_$tag') as DateTime?;

  Future<void> saveTagCursor(String tag, DateTime timestamp) async => _cursorBox.put('tag_cursor_$tag', timestamp);
}
