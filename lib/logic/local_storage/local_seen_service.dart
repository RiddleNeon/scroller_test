import 'package:cloud_firestore/cloud_firestore.dart' hide Filter;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart' hide FieldValue;
import 'package:sembast_web/sembast_web.dart' hide Filter, FieldValue;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:wurp/logic/feed_recommendation/user_interaction.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/main.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart' as sembast_sqflite;

/// Cross-platform persistent local storage for seen/liked/following data.
///
/// Backend:
///   Web    → sembast_web  (IndexedDB) — survives hot restarts & debug sessions
///   Mobile → sembast_sqflite (SQLite) — same as before, rock-solid
///
/// pubspec.yaml dependencies to add:
///   sembast: ^3.7.4
///   sembast_web: ^2.4.2
///   sembast_sqflite: ^2.2.1
///   sqflite: ^2.3.3
///   path_provider: ^2.1.2
///   path: ^1.9.0
class LocalSeenService {
  // ---------------------------------------------------------------------------
  // Store names  (= "tables")
  // ---------------------------------------------------------------------------
  static const String _dbName        = 'local_seen';
  static const String _seenStore     = 'seen_videos';
  static const String _settingsStore = 'settings';
  static const String _cursorStore   = 'cursors';
  static const String _cursorDirtyStore = 'cursor_dirty';
  static const String _interactionStore = 'interactions';
  static const String _blacklistStore   = 'blacklisted_tags';
  static const String _likeStore        = 'like_vals';
  static const String _followingStore   = 'following';

  // ---------------------------------------------------------------------------
  // Settings keys
  // ---------------------------------------------------------------------------
  static const String _lastSyncKey            = 'lastSyncTimestamp';
  static const String _lastSyncLikesKey       = 'lastSyncLikesTimestamp';
  static const String _lastSyncDislikesKey    = 'lastSyncDislikesTimestamp';
  static const String _lastSyncPreferencesKey = 'lastSyncPreferencesTimestamp';
  static const String _lastSyncFollowingKey   = 'lastSyncFollowingTimestamp';

  // ---------------------------------------------------------------------------
  // Sembast stores  (key=String for all)
  // ---------------------------------------------------------------------------
  final _seen        = StoreRef<String, int>(_seenStore);        // value: ms epoch
  final _settings    = StoreRef<String, int>(_settingsStore);    // value: ms epoch
  final _cursors     = StoreRef<String, int>(_cursorStore);      // value: ms epoch
  final _cursorDirty = StoreRef<String, int>(_cursorDirtyStore); // value: ms epoch
  final _interactions = StoreRef<String, Map<String, Object?>>(_interactionStore);
  final _blacklist   = StoreRef<String, int>(_blacklistStore);   // value: ms epoch
  final _likes       = StoreRef<String, bool>(_likeStore);       // true=like false=dislike
  final _following   = StoreRef<String, int>(_followingStore);   // value: ms epoch

  late Database _db;
  late final String userId;

  // ---------------------------------------------------------------------------
  // Init / dispose
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    userId = auth!.currentUser!.uid;

    final dbName = '${userId}_$_dbName';

    if (kIsWeb) {
      _db = await databaseFactoryWeb.openDatabase(dbName);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dir.path, '$dbName.db');
      final factory = sembast_sqflite.getDatabaseFactorySqflite(sqflite.databaseFactory);
      _db = await factory.openDatabase(dbPath);
    }

    print("before initialisation: ${await _seen.count(_db)} seen videos for user $userId, "
        "last sync seen: ${_getDateTimeFromMs(await _settings.record(_lastSyncKey).get(_db))}, "
        "last sync likes: ${_getDateTimeFromMs(await _settings.record(_lastSyncLikesKey).get(_db))}, "
        "last sync dislikes: ${_getDateTimeFromMs(await _settings.record(_lastSyncDislikesKey).get(_db))}");

    await syncWithFirestore();
    await cleanUpOldEntries();

    print("initialized LocalSeenService with ${await _seen.count(_db)} seen videos for user $userId, "
        "last sync seen: ${_getDateTimeFromMs(await _settings.record(_lastSyncKey).get(_db))}, "
        "last sync likes: ${_getDateTimeFromMs(await _settings.record(_lastSyncLikesKey).get(_db))}, "
        "last sync dislikes: ${_getDateTimeFromMs(await _settings.record(_lastSyncDislikesKey).get(_db))}");
  }

  Future<void> dispose() async {
    await _db.close();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  DateTime? _getDateTimeFromMs(int? ms) =>
      ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;

  int _toMs(DateTime dt) => dt.millisecondsSinceEpoch;

  Future<DateTime?> _getSetting(String key) async {
    final ms = await _settings.record(key).get(_db);
    return _getDateTimeFromMs(ms);
  }

  Future<void> _setSetting(String key, DateTime value) async {
    await _settings.record(key).put(_db, _toMs(value));
  }

  // ---------------------------------------------------------------------------
  // Seen
  // ---------------------------------------------------------------------------

  void markAsSeen(Video video) {
    // Fire-and-forget — non-blocking
    _db.transaction((txn) async {
      await _seen.record(video.id).put(txn, _toMs(DateTime.now()));
      await _interactions.record(video.id).put(txn, {
        'authorId': video.authorId,
        'tags': video.tags,
      });
    });
  }

  Future<bool> hasSeen(String videoId) async {
    return await _seen.record(videoId).exists(_db);
  }

  /// Synchronous version — only use if you called [loadAllSeenIds] first.
  bool hasSeenSync(String videoId) => _seenCache.contains(videoId);
  Set<String> _seenCache = {};

  /// Call once after init() if you need synchronous hasSeen() checks.
  Future<void> loadAllSeenIds() async {
    final keys = await _seen.findKeys(_db);
    _seenCache = keys.toSet();
  }

  Future<Set<String>> getAllSeenIds() async {
    final keys = await _seen.findKeys(_db);
    return keys.toSet();
  }

  Future<List<UserInteraction>> getRecentInteractionsLocal({int limit = 50}) async {
    final records = await _seen.find(
      _db,
      finder: Finder(sortOrders: [SortOrder(Field.value, false)], limit: limit),
    );

    final result = <UserInteraction>[];
    for (final record in records) {
      final videoId = record.key;
      final seenAt = DateTime.fromMillisecondsSinceEpoch(record.value);
      final meta = await _interactions.record(videoId).get(_db);

      result.add(UserInteraction(
        videoId: videoId,
        authorId: meta?['authorId'] as String? ?? '',
        tags: meta?['tags'] != null ? List<String>.from(meta!['tags'] as List) : [],
        watchTime: 0,
        videoDuration: 1,
        timestamp: seenAt,
      ));
    }
    return result;
  }

  Future<void> cleanUpOldEntries() async {
    final count = await _seen.count(_db);
    if (count <= 5000) return;

    final oldest = await _seen.find(
      _db,
      finder: Finder(
        sortOrders: [SortOrder(Field.value, true)],
        limit: count - 5000,
      ),
    );
    final keysToDelete = oldest.map((r) => r.key).toList();

    await _db.transaction((txn) async {
      for (final key in keysToDelete) {
        await _seen.record(key).delete(txn);
        await _interactions.record(key).delete(txn);
      }
    });
    print("Cleaned up ${keysToDelete.length} old seen entries");
  }

  // ---------------------------------------------------------------------------
  // MAIN SYNC
  // ---------------------------------------------------------------------------

  Future<void> syncWithFirestore({bool onlyLoad = true}) async {
    final lastSyncSeen = await _getSetting(_lastSyncKey) ??
        DateTime.now().subtract(const Duration(days: 7));
    final lastSyncLikes = await _getSetting(_lastSyncLikesKey) ??
        DateTime.now().subtract(const Duration(days: 7));
    final lastSyncDislikes = await _getSetting(_lastSyncDislikesKey) ??
        DateTime.now().subtract(const Duration(days: 7));
    final lastSyncPreferences = await _getSetting(_lastSyncPreferencesKey) ??
        DateTime.now().subtract(const Duration(days: 7));
    final lastSyncFollowing = await _getSetting(_lastSyncFollowingKey) ??
        DateTime.now().subtract(const Duration(days: 7));

    print("syncing — seen: $lastSyncSeen, likes: $lastSyncLikes, "
        "dislikes: $lastSyncDislikes, preferences: $lastSyncPreferences, "
        "following: $lastSyncFollowing");

    await Future.wait([
      _syncSeenInteractions(lastSyncSeen, onlyLoad: onlyLoad),
      _syncLikes(lastSyncLikes, onlyLoad: onlyLoad),
      _syncDislikes(lastSyncDislikes, onlyLoad: onlyLoad),
      _syncPreferences(lastSyncPreferences, onlyLoad: onlyLoad),
      _syncFollowing(lastSyncFollowing, onlyLoad: onlyLoad),
    ]);
    print("successfully synced!");
  }

  Future<void> _syncSeenInteractions(DateTime lastSync, {required bool onlyLoad}) async {
    if (!onlyLoad) {
      print("Uploading local seen-changes to Firestore...");
      final records = await _seen.find(
        _db,
        finder: Finder(
          filter: Filter.greaterThan(Field.value, _toMs(lastSync)),
        ),
      );

      final batch = firestore.batch();
      final docRef = firestore.collection('users').doc(userId).collection('recent_interactions');

      for (final record in records) {
        final meta = await _interactions.record(record.key).get(_db);
        batch.set(
          docRef.doc(record.key),
          {
            'videoId': record.key,
            'timestamp': Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(record.value)),
            if (meta != null) 'authorId': meta['authorId'],
            if (meta != null) 'tags': meta['tags'],
          },
          SetOptions(merge: true),
        );
      }

      if (records.isNotEmpty) await batch.commit();
      print("Uploaded ${records.length} local seen entries");
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
    print("seen snapshot: 🔥 Source: ${snapshot.metadata.isFromCache ? "CACHE" : "SERVER"}");

    await _db.transaction((txn) async {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final videoId = data['videoId'] as String;
        final seenAt = (data['timestamp'] as Timestamp).toDate();

        final local = await _seen.record(videoId).get(txn);
        if (local == null || seenAt.millisecondsSinceEpoch > local) {
          await _seen.record(videoId).put(txn, _toMs(seenAt));
          await _interactions.record(videoId).put(txn, {
            'authorId': data['authorId'] ?? '',
            'tags': data['tags'] ?? [],
          });
        }
      }
    });

    print("Synced ${snapshot.docs.length} seen entries from Firestore");

    // Update tag cursors
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
      final existing = await getTagCursor(entry.key);
      if (existing == null || entry.value.isBefore(existing)) {
        await saveTagCursor(entry.key, entry.value);
      }
    }
    print("Updated tag cursors for ${tagOldestSeen.length} tags");

    final latestTime = (snapshot.docs.first.data()['timestamp'] as Timestamp).toDate();
    await _setSetting(_lastSyncKey, latestTime);
  }

  // ---------------------------------------------------------------------------
  // Likes sync
  // ---------------------------------------------------------------------------

  Future<void> _syncLikes(DateTime lastSync, {required bool onlyLoad}) async {
    final likesRef = firestore.collection('users').doc(userId).collection('liked_videos');

    if (!onlyLoad) {
      print("Uploading local likes to Firestore...");
      final records = await _likes.find(_db, finder: Finder(filter: Filter.equals(Field.value, true)));
      final batch = firestore.batch();

      for (final record in records) {
        batch.set(
          likesRef.doc(record.key),
          {'videoId': record.key, 'likedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      }
      if (records.isNotEmpty) await batch.commit();
      print("Uploaded ${records.length} liked videos");
    }

    final snapshot = await likesRef
        .where('likedAt', isGreaterThan: Timestamp.fromDate(lastSync))
        .orderBy('likedAt', descending: true)
        .get();

    if (snapshot.docs.isEmpty) {
      print("Nothing new from Firestore (likes)");
      return;
    }

    await _db.transaction((txn) async {
      for (final doc in snapshot.docs) {
        await _likes.record(doc.id).put(txn, true);
      }
    });
    print("Synced ${snapshot.docs.length} new liked videos from Firestore");

    final latestLikedAt = (snapshot.docs.first.data()['likedAt'] as Timestamp?)?.toDate();
    if (latestLikedAt != null) await _setSetting(_lastSyncLikesKey, latestLikedAt);
  }

  // ---------------------------------------------------------------------------
  // Dislikes sync
  // ---------------------------------------------------------------------------

  Future<void> _syncDislikes(DateTime lastSync, {required bool onlyLoad}) async {
    final dislikesRef = firestore.collection('users').doc(userId).collection('disliked_videos');

    if (!onlyLoad) {
      print("Uploading local dislikes to Firestore...");
      final records = await _likes.find(_db, finder: Finder(filter: Filter.equals(Field.value, false)));
      final batch = firestore.batch();

      for (final record in records) {
        batch.set(
          dislikesRef.doc(record.key),
          {'videoId': record.key, 'dislikedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      }
      if (records.isNotEmpty) await batch.commit();
      print("Uploaded ${records.length} disliked videos");
    }

    final snapshot = await dislikesRef
        .where('dislikedAt', isGreaterThan: Timestamp.fromDate(lastSync))
        .orderBy('dislikedAt', descending: true)
        .get();

    if (snapshot.docs.isEmpty) {
      print("Nothing new from Firestore (dislikes)");
      return;
    }

    await _db.transaction((txn) async {
      for (final doc in snapshot.docs) {
        await _likes.record(doc.id).put(txn, false);
      }
    });
    print("Synced ${snapshot.docs.length} new disliked videos from Firestore");

    final latestDislikedAt = (snapshot.docs.first.data()['dislikedAt'] as Timestamp?)?.toDate();
    if (latestDislikedAt != null) await _setSetting(_lastSyncDislikesKey, latestDislikedAt);
  }

  // ---------------------------------------------------------------------------
  // Preferences sync (cursors + blacklisted tags)
  // ---------------------------------------------------------------------------

  DocumentReference get _preferencesDoc => firestore
      .collection('users')
      .doc(userId)
      .collection('profile')
      .doc('preferences');

  Future<void> _syncPreferences(DateTime lastSync, {required bool onlyLoad}) async {
    if (!onlyLoad) {
      print("Uploading cursors & blacklisted tags to Firestore...");

      // Only upload cursors that changed since lastSync
      final allCursorKeys = await _cursors.findKeys(_db);
      final Map<String, Timestamp> changedCursors = {};
      for (final key in allCursorKeys) {
        final dirtyMs = await _cursorDirty.record(key).get(_db);
        if (dirtyMs != null && DateTime.fromMillisecondsSinceEpoch(dirtyMs).isAfter(lastSync)) {
          final ms = await _cursors.record(key).get(_db);
          if (ms != null) {
            changedCursors[key] = Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(ms));
          }
        }
      }

      final allTagKeys = await _blacklist.findKeys(_db);
      final Map<String, Timestamp> changedBlacklist = {};
      for (final key in allTagKeys) {
        final ms = await _blacklist.record(key).get(_db);
        if (ms != null && DateTime.fromMillisecondsSinceEpoch(ms).isAfter(lastSync)) {
          changedBlacklist[key] = Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(ms));
        }
      }

      if (changedCursors.isNotEmpty || changedBlacklist.isNotEmpty) {
        await _preferencesDoc.set(
          {
            if (changedCursors.isNotEmpty) 'cursor_vector': changedCursors,
            if (changedBlacklist.isNotEmpty) 'blacklisted_tags': changedBlacklist,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        print("Uploaded ${changedCursors.length} cursors, ${changedBlacklist.length} blacklisted tags");
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
    if (remoteCursors != null) {
      int count = 0;
      await _db.transaction((txn) async {
        for (final entry in remoteCursors.entries) {
          final remoteTs = (entry.value as Timestamp).toDate();
          final localMs = await _cursors.record(entry.key).get(txn);
          final local = _getDateTimeFromMs(localMs);
          if (local == null || remoteTs.isBefore(local)) {
            await _cursors.record(entry.key).put(txn, _toMs(remoteTs));
            count++;
          }
        }
      });
      print("Synced $count/${remoteCursors.length} cursors from Firestore");
    }

    final remoteTags = data?['blacklisted_tags'] as Map<String, dynamic>?;
    if (remoteTags != null) {
      int count = 0;
      await _db.transaction((txn) async {
        for (final entry in remoteTags.entries) {
          final remoteTs = (entry.value as Timestamp).toDate();
          final localMs = await _blacklist.record(entry.key).get(txn);
          final local = _getDateTimeFromMs(localMs);
          if (local == null || remoteTs.isBefore(local)) {
            await _blacklist.record(entry.key).put(txn, _toMs(remoteTs));
            count++;
          }
        }
      });
      print("Synced $count blacklisted tags from Firestore");
    }

    if (remoteUpdatedAt != null) {
      await _setSetting(_lastSyncPreferencesKey, remoteUpdatedAt);
    }
  }

  // ---------------------------------------------------------------------------
  // Following sync
  // ---------------------------------------------------------------------------

  Future<void> _syncFollowing(DateTime lastSync, {required bool onlyLoad}) async {
    final followingRef = firestore.collection('users').doc(userId).collection('following');

    if (!onlyLoad) {
      print("Uploading local following to Firestore...");
      final records = await _following.find(
        _db,
        finder: Finder(filter: Filter.greaterThan(Field.value, _toMs(lastSync))),
      );

      final batch = firestore.batch();
      for (final record in records) {
        batch.set(
          followingRef.doc(record.key),
          {'followedAt': Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(record.value))},
          SetOptions(merge: true),
        );
      }
      if (records.isNotEmpty) await batch.commit();
      print("Uploaded ${records.length} following entries");
    }

    final snapshot = await followingRef
        .where('followedAt', isGreaterThan: Timestamp.fromDate(lastSync))
        .orderBy('followedAt', descending: true)
        .get();

    if (snapshot.docs.isEmpty) {
      print("Nothing new from Firestore (following)");
      return;
    }
    print("following snapshot: 🔥 Source: ${snapshot.metadata.isFromCache ? "CACHE" : "SERVER"}");

    await _db.transaction((txn) async {
      for (final doc in snapshot.docs) {
        final followedAt = (doc.data()['followedAt'] as Timestamp).toDate();
        final localMs = await _following.record(doc.id).get(txn);
        final local = _getDateTimeFromMs(localMs);
        if (local == null || followedAt.isAfter(local)) {
          await _following.record(doc.id).put(txn, _toMs(followedAt));
        }
      }
    });
    print("Synced ${snapshot.docs.length} new following entries from Firestore");

    final latestFollowedAt = (snapshot.docs.first.data()['followedAt'] as Timestamp?)?.toDate();
    if (latestFollowedAt != null) await _setSetting(_lastSyncFollowingKey, latestFollowedAt);
  }

  // ---------------------------------------------------------------------------
  // Cursor helpers
  // ---------------------------------------------------------------------------

  Future<DateTime?> getNewestSeenTimestamp() async =>
      _getDateTimeFromMs(await _cursors.record('newestSeenTimestamp').get(_db));

  Future<void> saveNewestSeenTimestamp(DateTime timestamp) async {
    await _cursors.record('newestSeenTimestamp').put(_db, _toMs(timestamp));
    await _cursorDirty.record('newestSeenTimestamp').put(_db, _toMs(DateTime.now()));
  }

  Future<DateTime?> getOldestSeenTimestamp() async =>
      _getDateTimeFromMs(await _cursors.record('oldestSeenTimestamp').get(_db));

  Future<void> saveOldestSeenTimestamp(DateTime timestamp) async {
    await _cursors.record('oldestSeenTimestamp').put(_db, _toMs(timestamp));
    await _cursorDirty.record('oldestSeenTimestamp').put(_db, _toMs(DateTime.now()));
  }

  Future<DateTime?> getTrendingCursor() async =>
      _getDateTimeFromMs(await _cursors.record('trendingCursor').get(_db));

  Future<void> saveTrendingCursor(DateTime timestamp) async {
    await _cursors.record('trendingCursor').put(_db, _toMs(timestamp));
    await _cursorDirty.record('trendingCursor').put(_db, _toMs(DateTime.now()));
  }

  Future<void> resetCursors() async {
    await _cursors.drop(_db);
    await _cursorDirty.drop(_db);
  }

  Future<DateTime?> getTagCursor(String tag) async =>
      _getDateTimeFromMs(await _cursors.record('tag_cursor_$tag').get(_db));

  Future<void> saveTagCursor(String tag, DateTime timestamp) async {
    await _cursors.record('tag_cursor_$tag').put(_db, _toMs(timestamp));
    await _cursorDirty.record('tag_cursor_$tag').put(_db, _toMs(DateTime.now()));
  }

  // ---------------------------------------------------------------------------
  // Blacklisted tags helpers
  // ---------------------------------------------------------------------------

  Future<void> saveBlacklistedTag(String tag, DateTime timestamp) async {
    await _blacklist.record(tag).put(_db, _toMs(timestamp));
  }

  Future<List<String>> getBlacklistedTags() async {
    return await _blacklist.findKeys(_db);
  }

  // ---------------------------------------------------------------------------
  // Like / dislike helpers
  // ---------------------------------------------------------------------------

  Future<void> saveLike(String videoId) async {
    print("saved like for $videoId");
    await _likes.record(videoId).put(_db, true);
  }

  Future<void> removeLike(String videoId) async {
    print("removed like for $videoId");
    await _likes.record(videoId).delete(_db);
  }

  Future<void> saveDislike(String videoId) async {
    print("saved dislike for $videoId");
    await _likes.record(videoId).put(_db, false);
  }

  Future<void> removeDislike(String videoId) async {
    print("removed dislike for $videoId");
    await _likes.record(videoId).delete(_db);
  }

  Future<bool> isLiked(String videoId) async =>
      await _likes.record(videoId).get(_db) == true;

  Future<bool> isDisliked(String videoId) async =>
      await _likes.record(videoId).get(_db) == false;

  // ---------------------------------------------------------------------------
  // Following helpers
  // ---------------------------------------------------------------------------

  Future<void> followUser(String followedUserId) async {
    await _following.record(followedUserId).put(_db, _toMs(DateTime.now()));
  }

  Future<void> unfollowUser(String followedUserId) async {
    await _following.record(followedUserId).delete(_db);
  }

  Future<bool> isFollowing(String followedUserId) async =>
      await _following.record(followedUserId).exists(_db);

  Future<Set<String>> getAllFollowingIds() async {
    final keys = await _following.findKeys(_db);
    return keys.toSet();
  }

  Future<DateTime?> followedAt(String followedUserId) async =>
      _getDateTimeFromMs(await _following.record(followedUserId).get(_db));
}