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
  static const String _blacklistedTagsBoxName = 'blacklisted_tags';
  static const String _likeValsBoxName = 'likec_videos';
  static const double maxLocalStorage = 5e7; //50k

  // Settings keys
  static const String _lastSyncKey = 'lastSyncTimestamp';
  static const String _lastSyncLikesKey = 'lastSyncLikesTimestamp';
  static const String _lastSyncDislikesKey = 'lastSyncDislikesTimestamp';
  static const String _lastSyncPreferencesKey = 'lastSyncPreferencesTimestamp';

  // Firestore paths:
  // users/{uid}/liked_videos/{videoId}
  // users/{uid}/disliked_videos/{videoId}
  // users/{uid}/profile/preferences  →  fields: cursor_vector, blacklisted_tags, etc.

  late Box<DateTime> _seenBox;
  late Box _settingsBox;
  late Box _cursorBox;
  late Box<DateTime> _cursorDirtyBox; // tracks when each cursor was last modified locally
  late Box _interactionBox;
  late Box<DateTime> _blacklistedTagsBox;
  late Box<bool> _likeValsBox; //bool: true -> like, false -> dislike, not in box: nothing

  late final String userId;

  static bool hiveInitialized = false;

  Future<void> init() async {
    userId = auth!.currentUser!.uid;

    if (!hiveInitialized) {
      await Hive.initFlutter("user_$userId");
      hiveInitialized = true;
    }

    _seenBox = await Hive.openBox<DateTime>('${userId}_$_seenBoxName');
    _settingsBox = await Hive.openBox('${userId}_$_settingsBoxName');
    _cursorBox = await Hive.openBox('${userId}_$_cursorBoxName');
    _cursorDirtyBox = await Hive.openBox<DateTime>('${userId}_cursor_dirty');
    _interactionBox = await Hive.openBox('${userId}_$_interactionBoxName');
    _blacklistedTagsBox = await Hive.openBox('${userId}_$_blacklistedTagsBoxName');
    _likeValsBox = await Hive.openBox('${userId}_$_likeValsBoxName');

/*    await _cursorBox.clear();
    await _seenBox.clear();
    await _interactionBox.clear();*/

    await syncWithFirestore();
    await cleanUpOldEntries();
    print("initialized LocalSeenService with ${_seenBox.length} seen videos for user $userId, "
        "last sync seen: ${_settingsBox.get(_lastSyncKey)}, "
        "last sync likes: ${_settingsBox.get(_lastSyncLikesKey)}, "
        "last sync dislikes: ${_settingsBox.get(_lastSyncDislikesKey)}");
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

  // ---------------------------------------------------------------------------
  // MAIN SYNC
  // ---------------------------------------------------------------------------

  Future<void> syncWithFirestore({bool onlyLoad = true}) async {
    final lastSyncSeen = _settingsBox.get(_lastSyncKey) as DateTime? ??
        DateTime.now().subtract(const Duration(days: 7));
    final lastSyncLikes = _settingsBox.get(_lastSyncLikesKey) as DateTime? ??
        DateTime.now().subtract(const Duration(days: 7));
    final lastSyncDislikes = _settingsBox.get(_lastSyncDislikesKey) as DateTime? ??
        DateTime.now().subtract(const Duration(days: 7));
    final lastSyncPreferences = _settingsBox.get(_lastSyncPreferencesKey) as DateTime? ??
        DateTime.now().subtract(const Duration(days: 7));

    print("syncing — seen: $lastSyncSeen, likes: $lastSyncLikes, dislikes: $lastSyncDislikes, preferences: $lastSyncPreferences");

    await Future.wait([
      _syncSeenInteractions(lastSyncSeen, onlyLoad: onlyLoad),
      _syncLikes(lastSyncLikes, onlyLoad: onlyLoad),
      _syncDislikes(lastSyncDislikes, onlyLoad: onlyLoad),
      _syncPreferences(lastSyncPreferences, onlyLoad: onlyLoad),
    ]);
    print("successfully synced!");
  }

  // ---------------------------------------------------------------------------
  // seen / interactions
  // ---------------------------------------------------------------------------

  Future<void> _syncSeenInteractions(DateTime lastSync, {required bool onlyLoad}) async {
    if (!onlyLoad) {
      print("Uploading local seen-changes to Firestore...");

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
      print("Uploaded $uploadCount local seen entries");
    }

    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('recent_interactions')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(lastSync))
        .orderBy('timestamp', descending: true)
        .get();

    if (snapshot.docs.isEmpty) {
      print("Nothing new from Firestore (seen)");
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

    print("Syncing ${newSeenEntries.length} seen entries from Firestore...");
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
    await _settingsBox.put(_lastSyncKey, latestTime);
  }

  // ---------------------------------------------------------------------------
  // likes  →  users/{uid}/liked_videos/{videoId}
  // ---------------------------------------------------------------------------

  Future<void> _syncLikes(DateTime lastSync, {required bool onlyLoad}) async {
    final likesRef = firestore.collection('users').doc(userId).collection('liked_videos');

    if (!onlyLoad) {
      print("Uploading local likes to Firestore...");
      final batch = firestore.batch();
      int count = 0;

      for (final key in _likeValsBox.keys) {
        final videoId = key as String;
        if (_likeValsBox.get(videoId) != true) continue;
        batch.set(
          likesRef.doc(videoId),
          {'videoId': videoId, 'likedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
        count++;
      }

      if (count > 0) await batch.commit();
      print("Uploaded $count liked videos");
    }

    final snapshot = await likesRef
        .where('likedAt', isGreaterThan: Timestamp.fromDate(lastSync))
        .orderBy('likedAt', descending: true)
        .get();

    if (snapshot.docs.isEmpty) {
      print("Nothing new from Firestore (likes)");
      return;
    }

    await _likeValsBox.putAll({for (final doc in snapshot.docs) doc.id: true});
    print("Synced ${snapshot.docs.length} new liked videos from Firestore");

    // lastSync auf neuesten Eintrag setzen
    final latestLikedAt = (snapshot.docs.first.data()['likedAt'] as Timestamp?)?.toDate();
    if (latestLikedAt != null) {
      await _settingsBox.put(_lastSyncLikesKey, latestLikedAt);
    }
  }

  // ---------------------------------------------------------------------------
  // dislikes  →  users/{uid}/disliked_videos/{videoId}
  // ---------------------------------------------------------------------------

  Future<void> _syncDislikes(DateTime lastSync, {required bool onlyLoad}) async {
    final dislikesRef = firestore.collection('users').doc(userId).collection('disliked_videos');

    if (!onlyLoad) {
      print("Uploading local dislikes to Firestore...");
      final batch = firestore.batch();
      int count = 0;

      for (final key in _likeValsBox.keys) {
        final videoId = key as String;
        if (_likeValsBox.get(videoId) != false) continue;
        batch.set(
          dislikesRef.doc(videoId),
          {'videoId': videoId, 'dislikedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
        count++;
      }

      if (count > 0) await batch.commit();
      print("Uploaded $count disliked videos");
    }

    final snapshot = await dislikesRef
        .where('dislikedAt', isGreaterThan: Timestamp.fromDate(lastSync))
        .orderBy('dislikedAt', descending: true)
        .get();

    if (snapshot.docs.isEmpty) {
      print("Nothing new from Firestore (dislikes)");
      return;
    }

    await _likeValsBox.putAll({for (final doc in snapshot.docs) doc.id: false});
    print("Synced ${snapshot.docs.length} new disliked videos from Firestore");

    final latestDislikedAt = (snapshot.docs.first.data()['dislikedAt'] as Timestamp?)?.toDate();
    if (latestDislikedAt != null) {
      await _settingsBox.put(_lastSyncDislikesKey, latestDislikedAt);
    }
  }

  // ---------------------------------------------------------------------------
  // cursors + blacklisted tags  →  users/{uid}/profile/preferences
  //
  //  {
  //    cursor_vector:    { "tag_cursor_cooking": Timestamp, "trendingCursor": Timestamp, ... }
  //    blacklisted_tags: { "cooking": Timestamp, "news": Timestamp, ... }
  //  }
  // ---------------------------------------------------------------------------

  DocumentReference get _preferencesDoc => firestore
      .collection('users')
      .doc(userId)
      .collection('profile')
      .doc('preferences');

  Future<void> _syncPreferences(DateTime lastSync, {required bool onlyLoad}) async {
    if (!onlyLoad) {
      print("Uploading cursors & blacklisted tags to Firestore...");

      final Map<String, Timestamp> changedCursors = {
        for (final key in _cursorBox.keys)
          if ((_cursorDirtyBox.get(key))?.isAfter(lastSync) ?? false)
            key as String: Timestamp.fromDate(_cursorBox.get(key) as DateTime),
      };

      final Map<String, Timestamp> changedBlacklistedTags = {
        for (final key in _blacklistedTagsBox.keys)
          if ((_blacklistedTagsBox.get(key) as DateTime).isAfter(lastSync))
            key as String: Timestamp.fromDate(_blacklistedTagsBox.get(key) as DateTime),
      };

      if (changedCursors.isNotEmpty || changedBlacklistedTags.isNotEmpty) {
        await _preferencesDoc.set(
          {
            if (changedCursors.isNotEmpty) 'cursor_vector': changedCursors,
            if (changedBlacklistedTags.isNotEmpty) 'blacklisted_tags': changedBlacklistedTags,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        print("Uploaded ${changedCursors.length} cursors, ${changedBlacklistedTags.length} blacklisted tags");
      } else {
        print("No preference changes since last sync — skipping upload");
      }
    }

    final doc = await _preferencesDoc.get();
    if (!doc.exists) {
      print("Nothing new from Firestore (preferences)");
      return;
    }

    final data = doc.data() as Map<String, dynamic>?;

    final remoteUpdatedAt = (data?['updatedAt'] as Timestamp?)?.toDate();
    if (remoteUpdatedAt != null && !remoteUpdatedAt.isAfter(lastSync)) {
      print("Preferences unchanged since last sync — skipping download");
      return;
    }

    final remoteCursors = data?['cursor_vector'] as Map<String, dynamic>?;
    int cursorSyncCount = 0;
    if (remoteCursors != null) {
      for (final entry in remoteCursors.entries) {
        final remoteTs = (entry.value as Timestamp).toDate();
        final local = _cursorBox.get(entry.key) as DateTime?;
        if (local == null || remoteTs.isBefore(local)) {
          await _cursorBox.put(entry.key, remoteTs);
          cursorSyncCount++;
        }
      }
      print("Synced $cursorSyncCount/${remoteCursors.length} cursors from Firestore");
    }

    final remoteTags = data?['blacklisted_tags'] as Map<String, dynamic>?;
    if (remoteTags != null) {
      final Map<String, DateTime> toWrite = {};
      for (final entry in remoteTags.entries) {
        final remoteTs = (entry.value as Timestamp).toDate();
        final local = _blacklistedTagsBox.get(entry.key);
        if (local == null || remoteTs.isBefore(local)) {
          toWrite[entry.key] = remoteTs;
        }
      }
      await _blacklistedTagsBox.putAll(toWrite);
      print("Synced ${toWrite.length} blacklisted tags from Firestore");
    }

    if (remoteUpdatedAt != null) {
      await _settingsBox.put(_lastSyncPreferencesKey, remoteUpdatedAt);
      print("synced to ${remoteUpdatedAt.toLocal()}");
    }
  }

  // ---------------------------------------------------------------------------
  // Cursor helpers
  // ---------------------------------------------------------------------------

  DateTime? getNewestSeenTimestamp() => _cursorBox.get('newestSeenTimestamp') as DateTime?;

  Future<void> saveNewestSeenTimestamp(DateTime timestamp) async {
    await _cursorBox.put('newestSeenTimestamp', timestamp);
    await _cursorDirtyBox.put('newestSeenTimestamp', DateTime.now());
  }

  DateTime? getOldestSeenTimestamp() => _cursorBox.get('oldestSeenTimestamp') as DateTime?;

  Future<void> saveOldestSeenTimestamp(DateTime timestamp) async {
    await _cursorBox.put('oldestSeenTimestamp', timestamp);
    await _cursorDirtyBox.put('oldestSeenTimestamp', DateTime.now());
  }

  DateTime? getTrendingCursor() => _cursorBox.get('trendingCursor') as DateTime?;

  Future<void> saveTrendingCursor(DateTime timestamp) async {
    await _cursorBox.put('trendingCursor', timestamp);
    await _cursorDirtyBox.put('trendingCursor', DateTime.now());
  }

  Future<void> resetCursors() async {
    await _cursorBox.clear();
    await _cursorDirtyBox.clear();
  }

  DateTime? getTagCursor(String tag) => _cursorBox.get('tag_cursor_$tag') as DateTime?;

  Future<void> saveTagCursor(String tag, DateTime timestamp) async {
    await _cursorBox.put('tag_cursor_$tag', timestamp);
    await _cursorDirtyBox.put('tag_cursor_$tag', DateTime.now());
    print("saved cursor of $tag");
  }

  // ---------------------------------------------------------------------------
  // Blacklisted tags helpers
  // ---------------------------------------------------------------------------

  Future<void> saveBlacklistedTag(String tag, DateTime timestamp) async {
    await _blacklistedTagsBox.put(tag, timestamp);
  }

  List<String> getBlacklistedTags() {
    return _blacklistedTagsBox.keys.map((e) => e.toString()).toList();
  }

  // ---------------------------------------------------------------------------
  // Like / dislike helpers
  // ---------------------------------------------------------------------------

  Future<void> saveLike(String videoId) async {
    print("saved like for $videoId");
    await _likeValsBox.put(videoId, true);
  }

  Future<void> removeLike(String videoId) async {
    print("removed like for $videoId");
    await _likeValsBox.delete(videoId);
  }

  Future<void> saveDislike(String videoId) async {
    print("saved dislike for $videoId");
    await _likeValsBox.put(videoId, false);
  }

  Future<void> removeDislike(String videoId) async {
    print("removed dislike for $videoId");
    await _likeValsBox.delete(videoId);
  }

  bool isLiked(String videoId) => _likeValsBox.get(videoId) == true;
  bool isDisliked(String videoId) => _likeValsBox.get(videoId) == false;
}