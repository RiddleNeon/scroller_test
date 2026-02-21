import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wurp/main.dart';

class LocalSeenService {
  static const String _seenBoxName = 'seen_videos';
  static const String _settingsBoxName = 'seen_settings';
  static const String _cursorBoxName = 'feed_cursors';
  static late Box<DateTime> _seenBox;
  static late Box _settingsBox;
  static late Box _cursorBox;

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static late final String userId;

  static Future<void> init() async {
    print("starting initialization of LocalSeenService...");
    await Hive.initFlutter();

    _seenBox = await Hive.openBox<DateTime>(_seenBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
    _cursorBox = await Hive.openBox(_cursorBoxName);

    await _cursorBox.clear();
    await _seenBox.clear();

    print("cleared!");

    userId = auth!.currentUser!.uid;
    await syncWithFirestore();
    await cleanUpOldEntries();

    print("initialized LocalSeenService with ${_seenBox.length} seen videos for user $userId, last sync: ${_settingsBox.get('lastSyncTimestamp')}");
  }

  static void markAsSeen(String videoId) {
    _seenBox.put(videoId, DateTime.now());
  }

  static bool hasSeen(String videoId) {
    return _seenBox.containsKey(videoId);
  }

  static Set<String> get allSeenIds => _seenBox.keys.cast<String>().toSet();

  static Future<void> cleanUpOldEntries() async {
    if (_seenBox.length <= 5000) return;

    final entries = _seenBox.toMap().entries.toList();
    entries.sort((a, b) => a.value.compareTo(b.value));

    final amountToDelete = _seenBox.length - 5000;
    final keysToDelete = entries.take(amountToDelete).map((e) => e.key as String).toList();

    await _seenBox.deleteAll(keysToDelete);
  }


  static Future<void> syncWithFirestore({bool onlyLoad = true}) async {
    final lastSync = _settingsBox.get('lastSyncTimestamp') as DateTime? ??
        DateTime.now().subtract(const Duration(days: 7));
    
    
    if (!onlyLoad) {
      print("Uploading local changes to Firestore...");

      final Map<String, DateTime> localEntries =
      Map<String, DateTime>.from(_seenBox.toMap());

      final batch = _firestore.batch();
      int uploadCount = 0;

      for (final entry in localEntries.entries) {
        if (entry.value.isAfter(lastSync)) {
          final docRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('recent_interactions')
              .doc(entry.key);

          batch.set(docRef, {
            'videoId': entry.key,
            'timestamp': Timestamp.fromDate(entry.value),
          }, SetOptions(merge: true));

          uploadCount++;
        }
      }

      if (uploadCount > 0) {
        await batch.commit();
      }

      print("Uploaded $uploadCount local entries");
    }

    
    final snapshot = await _firestore
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

    final Map<String, DateTime> newEntries = {}; 

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final String videoId = data['videoId'];
      final DateTime seenAt = (data['timestamp'] as Timestamp).toDate();

      final local = _seenBox.get(videoId); 
      if (local == null || seenAt.isAfter(local)) {
        newEntries[videoId] = seenAt;
      }
    }

    print("Syncing ${newEntries.length} entries from Firestore...");
    await _seenBox.putAll(newEntries);
    
    
    final Map<String, DateTime> tagOldestSeen = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final List<String> tags =
      data['tags'] != null ? List<String>.from(data['tags']) : [];
      final DateTime seenAt = (data['timestamp'] as Timestamp).toDate();

      for (final tag in tags) {
        if (!tagOldestSeen.containsKey(tag) ||
            seenAt.isBefore(tagOldestSeen[tag]!)) {
          tagOldestSeen[tag] = seenAt;
        }
      }
    }

    for (final entry in tagOldestSeen.entries) {
      final existingCursor = getTagCursor(entry.key);
      if (existingCursor == null || entry.value.isBefore(existingCursor)) {
        await saveTagCursor(entry.key, entry.value);
      }
    }

    print("Updated tag cursors for ${tagOldestSeen.length} tags");
    
    
    final latestInteractionTime =
    (snapshot.docs.first.data()['timestamp'] as Timestamp).toDate();

    await _settingsBox.put('lastSyncTimestamp', latestInteractionTime);
  }



  static DateTime? getNewestSeenTimestamp() {
    return _cursorBox.get('newestSeenTimestamp') as DateTime?;
  }

  static Future<void> saveNewestSeenTimestamp(DateTime timestamp) async {
    await _cursorBox.put('newestSeenTimestamp', timestamp);
  }

  static DateTime? getOldestSeenTimestamp() {
    return _cursorBox.get('oldestSeenTimestamp') as DateTime?;
  }

  static Future<void> saveOldestSeenTimestamp(DateTime timestamp) async {
    await _cursorBox.put('oldestSeenTimestamp', timestamp);
  }

  static DateTime? getTrendingCursor() {
    return _cursorBox.get('trendingCursor') as DateTime?;
  }

  static Future<void> saveTrendingCursor(DateTime timestamp) async {
    await _cursorBox.put('trendingCursor', timestamp);
  }

  static Future<void> resetCursors() async {
    await _cursorBox.clear();
  }
  
  
  static DateTime? getTagCursor(String tag) {
    return _cursorBox.get('tag_cursor_$tag') as DateTime?;
  }

  static Future<void> saveTagCursor(String tag, DateTime timestamp) async {
    await _cursorBox.put('tag_cursor_$tag', timestamp);
  }
}