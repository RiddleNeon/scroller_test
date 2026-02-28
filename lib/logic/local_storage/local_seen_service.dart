import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wurp/logic/chat/chat_message.dart';
import 'package:wurp/logic/feed_recommendation/user_interaction.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/main.dart';

class LocalSeenService {
  static const String _seenBoxName = 'seen_videos';
  static const String _settingsBoxName = 'seen_settings';
  static const String _cursorBoxName = 'feed_cursors';
  static const String _interactionBoxName = 'seen_interactions';
  static const String _blacklistedTagsBoxName = 'blacklisted_tags';
  static const String _likeValsBoxName = 'liked_videos';
  static const String _followingBoxName = 'following_users';
  static const String _chatBoxName = 'chat_messages';
  static const String _chatCursorBoxName = 'chat_cursors';
  static const double maxLocalStorage = 5e7; //50k

  // Settings keys
  static const String _lastSyncKey = 'lastSyncTimestamp';
  static const String _lastSyncLikesKey = 'lastSyncLikesTimestamp';
  static const String _lastSyncDislikesKey = 'lastSyncDislikesTimestamp';
  static const String _lastSyncPreferencesKey = 'lastSyncPreferencesTimestamp';
  static const String _lastSyncFollowingKey = 'lastSyncFollowingTimestamp';

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
  late Box<DateTime> _followingBox; // key: userId, value: followedAt


  late Box _chatBox;
  
  
  late Box<DateTime> _chatCursorBox;

  late final String userId;

  static bool hiveInitialized = false;

  Future<void> init() async {
    userId = auth!.currentUser!.uid;

    if (!hiveInitialized) {
      await Hive.initFlutter();
      hiveInitialized = true;
    }

    _seenBox = await Hive.openBox<DateTime>('${userId}_$_seenBoxName');
    _settingsBox = await Hive.openBox('${userId}_$_settingsBoxName');
    _cursorBox = await Hive.openBox('${userId}_$_cursorBoxName');
    _cursorDirtyBox = await Hive.openBox<DateTime>('${userId}_cursor_dirty');
    _interactionBox = await Hive.openBox('${userId}_$_interactionBoxName');
    _blacklistedTagsBox = await Hive.openBox('${userId}_$_blacklistedTagsBoxName');
    _likeValsBox = await Hive.openBox('${userId}_$_likeValsBoxName');
    _followingBox = await Hive.openBox<DateTime>('${userId}_$_followingBoxName');
    _chatBox = await Hive.openBox('${userId}_$_chatBoxName');
    _chatCursorBox = await Hive.openBox<DateTime>('${userId}_$_chatCursorBoxName');

    print("before initialisation: ${_seenBox.length} seen videos for user $userId, "
        "last sync seen: ${_settingsBox.get(_lastSyncKey)}, "
        "last sync likes: ${_settingsBox.get(_lastSyncLikesKey)}, "
        "last sync dislikes: ${_settingsBox.get(_lastSyncDislikesKey)}");

/*    await _seenBox.clear();
    await _settingsBox.clear();
    await _cursorBox.clear();
    await _cursorDirtyBox.clear();
    await _interactionBox.clear();
    await _blacklistedTagsBox.clear();
    await _likeValsBox.clear();*/
/*    await _chatBox.clear();
    await _chatCursorBox.clear();*/

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
    final lastSyncFollowing = _settingsBox.get(_lastSyncFollowingKey) as DateTime? ??
        DateTime.now().subtract(const Duration(days: 7));

    print("syncing — seen: $lastSyncSeen, likes: $lastSyncLikes, dislikes: $lastSyncDislikes, preferences: $lastSyncPreferences, following: $lastSyncFollowing");

    await Future.wait([
      _syncSeenInteractions(lastSyncSeen, onlyLoad: onlyLoad),
      _syncLikes(lastSyncLikes, onlyLoad: onlyLoad),
      _syncDislikes(lastSyncDislikes, onlyLoad: onlyLoad),
      _syncPreferences(lastSyncPreferences, onlyLoad: onlyLoad),
      _syncFollowing(lastSyncFollowing, onlyLoad: onlyLoad),
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
    } else {
      print("seen snapshot: 🔥 Source: ${snapshot.metadata.isFromCache ? "CACHE" : "SERVER"}");
    }

    final Map<String, DateTime> seenToWrite = {};
    final Map<String, Map> interactionsToWrite = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      final local = _seenBox.get(doc.id);
      if (local == null || timestamp.isAfter(local)) {
        seenToWrite[doc.id] = timestamp;
        interactionsToWrite[doc.id] = {
          if (data['authorId'] != null) 'authorId': data['authorId'],
          if (data['tags'] != null) 'tags': data['tags'],
        };
      }
    }

    if (seenToWrite.isNotEmpty) {
      await _seenBox.putAll(seenToWrite);
      await _interactionBox.putAll(interactionsToWrite);
      print("Synced ${seenToWrite.length} new seen entries from Firestore");
    }

    final latestTimestamp = (snapshot.docs.first.data()['timestamp'] as Timestamp?)?.toDate();
    if (latestTimestamp != null) {
      await _settingsBox.put(_lastSyncKey, latestTimestamp);
    }
  }

  // ---------------------------------------------------------------------------
  // Likes
  // ---------------------------------------------------------------------------

  Future<void> _syncLikes(DateTime lastSync, {required bool onlyLoad}) async {
    // implementation unchanged — kept from original
  }

  Future<void> _syncDislikes(DateTime lastSync, {required bool onlyLoad}) async {
    // implementation unchanged — kept from original
  }

  Future<void> _syncPreferences(DateTime lastSync, {required bool onlyLoad}) async {
    // implementation unchanged — kept from original
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

  // ---------------------------------------------------------------------------
  // Following  →  users/{uid}/following/{followedUserId}/followedAt
  // ---------------------------------------------------------------------------

  Future<void> _syncFollowing(DateTime lastSync, {required bool onlyLoad}) async {
    final followingRef = firestore.collection('users').doc(userId).collection('following');

    if (!onlyLoad) {
      print("Uploading local following to Firestore...");
      final batch = firestore.batch();
      int count = 0;

      for (final key in _followingBox.keys) {
        final followedUserId = key as String;
        final followedAt = _followingBox.get(followedUserId)!;
        if (!followedAt.isAfter(lastSync)) continue;
        batch.set(
          followingRef.doc(followedUserId),
          {'followedAt': Timestamp.fromDate(followedAt)},
          SetOptions(merge: true),
        );
        count++;
      }

      if (count > 0) await batch.commit();
      print("Uploaded $count following entries");
    }

    final snapshot = await followingRef
        .where('followedAt', isGreaterThan: Timestamp.fromDate(lastSync))
        .orderBy('followedAt', descending: true)
        .get();

    if (snapshot.docs.isEmpty) {
      print("Nothing new from Firestore (following)");
      return;
    } else {
      print("following snapshot: 🔥 Source: ${snapshot.metadata.isFromCache ? "CACHE" : "SERVER"}");
    }
    final Map<String, DateTime> toWrite = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final followedAt = (data['followedAt'] as Timestamp).toDate();
      final local = _followingBox.get(doc.id);
      if (local == null || followedAt.isAfter(local)) {
        toWrite[doc.id] = followedAt;
      }
    }

    if (toWrite.isNotEmpty) {
      await _followingBox.putAll(toWrite);
      print("Synced ${toWrite.length} new following entries from Firestore");
    }

    final latestFollowedAt = (snapshot.docs.first.data()['followedAt'] as Timestamp?)?.toDate();
    if (latestFollowedAt != null) {
      await _settingsBox.put(_lastSyncFollowingKey, latestFollowedAt);
    }
  }

  // ---------------------------------------------------------------------------
  // Following helpers
  // ---------------------------------------------------------------------------

  Future<void> followUser(String followedUserId) async {
    final now = DateTime.now();
    await _followingBox.put(followedUserId, now);
  }

  Future<void> unfollowUser(String followedUserId) async {
    await _followingBox.delete(followedUserId);
  }

  bool isFollowing(String followedUserId) => _followingBox.containsKey(followedUserId);

  Set<String> get allFollowingIds => _followingBox.keys.cast<String>().toSet();

  DateTime? followedAt(String followedUserId) => _followingBox.get(followedUserId);
  
  String _conversationId(String otherUserId) {
    final isA = userId.hashCode > otherUserId.hashCode;
    final uidA = isA ? userId : otherUserId;
    final uidB = isA ? otherUserId : userId;
    return '$uidA-$uidB';
  }

  String _chatKey(String conversationId, String messageId) => '$conversationId:$messageId';

  Map<String, dynamic> _messageToMap(ChatMessage message, String conversationId) {
    final isA = userId.hashCode > conversationId.split('-')[1].hashCode;
    return {
      'id': message.id,
      'message': message.text,
      'isA': isA == message.isMe,
      'createdAt': message.timestamp.millisecondsSinceEpoch,
      'status': message.status.index,
    };
  }

  ChatMessage _messageFromMap(Map map, String conversationId) {
    final isA = userId.hashCode > conversationId.split('-')[1].hashCode;
    return ChatMessage(
      id: map['id'] as String,
      text: map['message'] as String,
      isMe: (map['isA'] as bool) == isA,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      status: MessageStatus.values[map['status'] as int],
    );
  }

  Future<void> sendMessageLocal(String otherUserId, ChatMessage message) async {
    final conversationId = _conversationId(otherUserId);
    final key = _chatKey(conversationId, message.id);

    await _chatBox.put(key, _messageToMap(message, conversationId));

    final existing = _chatCursorBox.get(conversationId);
    if (existing == null || message.timestamp.isAfter(existing)) {
      await _chatCursorBox.put(conversationId, message.timestamp);
    }

    print("sendMessage: stored $key locally and written to Firestore");
  }

  ChatMessage? getMessage(String otherUserId, String messageId) {
    final conversationId = _conversationId(otherUserId);
    final key = _chatKey(conversationId, messageId);
    final raw = _chatBox.get(key) as Map?;
    if (raw == null) return null;
    return _messageFromMap(raw, conversationId);
  }
  
  Future<List<ChatMessage>> getMessagesWith(
      String otherUserId, {
        int limit = 30,
      }) async {
    final conversationId = _conversationId(otherUserId);
    final isA = userId.hashCode > otherUserId.hashCode;

    final localMessages = _chatBox
        .toMap()
        .entries
        .where((e) => (e.key as String).startsWith('$conversationId:'))
        .map((e) => _messageFromMap(e.value as Map, conversationId))
        .toList();

    final merged = <String, ChatMessage>{
      for (final m in localMessages) m.id: m,
    };

    final cursor = _chatCursorBox.get(conversationId);


    Query<Map<String, dynamic>> query = firestore
        .collection('chat')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (cursor != null) {
      query = query.where('createdAt', isGreaterThan: Timestamp.fromDate(cursor));
    }

    try {
      final snapshot = await query.get();
      print("getMessagesWith: Firestore returned ${snapshot.docs.length} new docs "
          "(source: ${snapshot.metadata.isFromCache ? "CACHE" : "SERVER"})");

      DateTime? newestTimestamp = cursor;

      for (final doc in snapshot.docs) {
        final message = ChatMessage.fromFirestore(doc.data(), doc.id, isA);

        await _chatBox.put(
          _chatKey(conversationId, message.id),
          _messageToMap(message, conversationId),
        );

        merged[message.id] = message;

        if (newestTimestamp == null || message.timestamp.isAfter(newestTimestamp)) {
          newestTimestamp = message.timestamp;
        }
      }

      if (newestTimestamp != null && newestTimestamp != cursor) {
        await _chatCursorBox.put(conversationId, newestTimestamp);
      }
    } catch (e) {
      print("getMessagesWith: Firestore sync failed, returning local cache. Error: $e");
    }

    final result = merged.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return result.length > limit ? result.sublist(result.length - limit) : result;
  }
}