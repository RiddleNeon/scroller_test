import 'package:hive_flutter/hive_flutter.dart';
import 'package:wurp/logic/chat/chat.dart';
import 'package:wurp/logic/chat/chat_message.dart';
import 'package:wurp/logic/feed_recommendation/user_interaction.dart';
import 'package:wurp/logic/models/user_model.dart';
import 'package:wurp/logic/video/video.dart';

import '../../base_logic.dart';
import '../../tools/supabase_tests/supabase_login_test.dart';


LocalSeenService get localSeenService {
  if (_localSeenService == null) throw StateError("Local Seen Service isn't initialized yet!");
  return _localSeenService!;
}
LocalSeenService? _localSeenService;
Future<void> initLocalSeenService() async{
  _localSeenService = LocalSeenService();
  await _localSeenService!.init();
}
Future<void> disposeLocalSeenService() async {
  return await _localSeenService?.dispose();
}

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
  static const String _conversationBoxName = 'conversations';
  static const String _authorBoxName = 'authors';
  static const double maxLocalStorage = 5e5; //500k

  // Settings keys
  static const String _lastSyncSeenKey = 'lastSyncTimestamp';
  static const String _lastSyncLikesKey = 'lastSyncLikesTimestamp';
  static const String _lastSyncDislikesKey = 'lastSyncDislikesTimestamp';
  static const String _lastSyncPreferencesKey = 'lastSyncPreferencesTimestamp';
  static const String _lastSyncFollowingKey = 'lastSyncFollowingTimestamp';
  static const String _lastSyncConversationKey = 'lastSyncConversationTimestamp';
  static const String _lastUpdateAuthorsKey = 'lastUpdateAuthorsTimestamp';

  late Box<DateTime> _seenBox;
  late Box _settingsBox;
  late Box _cursorBox;
  late Box<DateTime> _cursorDirtyBox; // tracks when each cursor was last modified locally
  late Box _interactionBox;
  late Box<DateTime> _blacklistedTagsBox;
  late Box<bool> _likeValsBox; //bool: true -> like, false -> dislike, not in box: nothing
  late Box<DateTime> _followingBox; // key: userId, value: followedAt

  late Box<Map<String, dynamic>> _authorBox; // key: userId, value: followedAt

  late Box _chatBox;
  late Box<DateTime> _chatCursorBox;
  late Box _conversationBox;

  late final String userId;

  static bool hiveInitialized = false;

  Future<void> init() async {
    userId = currentAuthUserId();

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
    _conversationBox = await Hive.openBox('${userId}_$_conversationBoxName');
    _authorBox = await Hive.openBox('${userId}_$_authorBoxName');
  await _seenBox.clear();
    await _settingsBox.clear();
    await _cursorBox.clear();
    await _cursorDirtyBox.clear();
    await _interactionBox.clear();
    await _blacklistedTagsBox.clear();
    await _followingBox.clear();
    await _authorBox.clear();
    
    await _likeValsBox.clear();
    await _chatBox.clear();
    await _chatCursorBox.clear();
    await _conversationBox.clear();

    DateTime? lastAuthorUpdate = (_settingsBox.get(_lastUpdateAuthorsKey) as DateTime?);

    if (lastAuthorUpdate == null || lastAuthorUpdate.difference(DateTime.now()) > const Duration(days: 2)) {
      await _authorBox.clear();
      _settingsBox.put(_lastUpdateAuthorsKey, DateTime.now());
    }

    await syncWithSupabase();
    await cleanUpOldEntries();
    print(
      "initialized LocalSeenService with ${_seenBox.length} seen videos for user $userId, "
      "last sync seen: ${_settingsBox.get(_lastSyncSeenKey)}, "
      "last sync likes: ${_settingsBox.get(_lastSyncLikesKey)}, "
      "last sync dislikes: ${_settingsBox.get(_lastSyncDislikesKey)}"
      "last sync chats: ${_settingsBox.get(_lastSyncConversationKey)}",
    );
  }

  Future<void> dispose() {
    return Hive.close();
  }

  void markAsSeen(Video video) {
    _seenBox.put(video.id, DateTime.now());
    _interactionBox.put(video.id, {'authorId': video.authorId, 'tags': video.tags});
  }

  bool hasSeen(String videoId) => false; /*_seenBox.containsKey(videoId);*/

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
        watchTime: 0, //dummy values bc those are not stored
        videoDuration: 1, //same here
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

  Future<void> syncWithSupabase({bool onlyLoad = true}) async {
    final lastSyncSeen = _settingsBox.get(_lastSyncSeenKey) as DateTime? ?? DateTime.now().subtract(const Duration(days: 7));
    final lastSyncLikes = _settingsBox.get(_lastSyncLikesKey) as DateTime? ?? DateTime.now().subtract(const Duration(days: 7));
    final lastSyncDislikes = _settingsBox.get(_lastSyncDislikesKey) as DateTime? ?? DateTime.now().subtract(const Duration(days: 7));
    final lastSyncPreferences = _settingsBox.get(_lastSyncPreferencesKey) as DateTime? ?? DateTime.now().subtract(const Duration(days: 7));
    final lastSyncFollowing = _settingsBox.get(_lastSyncFollowingKey) as DateTime? ?? DateTime.now().subtract(const Duration(days: 7));
    final lastSyncConversation = _settingsBox.get(_lastSyncConversationKey) as DateTime? ?? DateTime.now().subtract(const Duration(days: 7));

    await Future.wait([
      _syncSeenInteractions(lastSyncSeen, onlyLoad: onlyLoad),
      _syncLikes(lastSyncLikes, onlyLoad: onlyLoad),
      _syncDislikes(lastSyncDislikes, onlyLoad: onlyLoad),
      _syncPreferences(lastSyncPreferences, onlyLoad: onlyLoad),
      _syncFollowing(lastSyncFollowing, onlyLoad: onlyLoad),
      _syncConversations(lastSyncConversation),
    ]);
  }

  // ---------------------------------------------------------------------------
  // seen / interactions
  // ---------------------------------------------------------------------------

  Future<void> _syncSeenInteractions(DateTime lastSync, {required bool onlyLoad}) async {
    if (!onlyLoad) {
      print('Skipping remote seen sync because the provided Supabase schema has no recent_interactions table.');
    }
    await _settingsBox.put(_lastSyncSeenKey, DateTime.now());
  }

  // ---------------------------------------------------------------------------
  // likes  →  users/{uid}/liked_videos/{videoId}
  // ---------------------------------------------------------------------------

  Future<void> _syncLikes(DateTime lastSync, {required bool onlyLoad}) async {
    if (!onlyLoad) {
      final payload = <Map<String, dynamic>>[];
      for (final key in _likeValsBox.keys) {
        final videoId = key as String;
        if (_likeValsBox.get(videoId) != true) continue;
        final parsedVideoId = int.tryParse(videoId);
        if (parsedVideoId == null) continue;
        payload.add({'user_id': userId, 'video_id': parsedVideoId});
      }
      if (payload.isNotEmpty) {
        await _upsertInChunks('likes', payload, onConflict: 'user_id, video_id');
      }
    }

    final snapshot = await supabaseClient
        .from('likes')
        .select('video_id, created_at')
        .eq('user_id', userId)
        .gt('created_at', lastSync.toIso8601String())
        .order('created_at', ascending: false);

    if (snapshot.isEmpty) {
      return;
    }

    await _likeValsBox.putAll({for (final row in snapshot) row['video_id'].toString(): true});

    await _settingsBox.put(_lastSyncLikesKey, DateTime.parse(snapshot.first['created_at'] as String).toLocal());
  }

  Future<void> _syncDislikes(DateTime lastSync, {required bool onlyLoad}) async {
    if (!onlyLoad) {
      final payload = <Map<String, dynamic>>[];
      for (final key in _likeValsBox.keys) {
        final videoId = key as String;
        if (_likeValsBox.get(videoId) != false) continue;
        final parsedVideoId = int.tryParse(videoId);
        if (parsedVideoId == null) continue;
        payload.add({'user_id': userId, 'video_id': parsedVideoId});
      }
      if (payload.isNotEmpty) {
        await _upsertInChunks('dislikes', payload, onConflict: 'user_id, video_id');
      }
    }

    final snapshot = await supabaseClient
        .from('dislikes')
        .select('video_id, created_at')
        .eq('user_id', userId)
        .gt('created_at', lastSync.toIso8601String())
        .order('created_at', ascending: false);

    if (snapshot.isEmpty) {
      return;
    }

    await _likeValsBox.putAll({for (final row in snapshot) row['video_id'].toString(): false});

    await _settingsBox.put(_lastSyncDislikesKey, DateTime.parse(snapshot.first['created_at'] as String).toLocal());
  }

  Future<void> _syncPreferences(DateTime lastSync, {required bool onlyLoad}) async {
    if (!onlyLoad) {
      print('Skipping remote preference sync because the provided Supabase schema has no user_preferences table.');
    }
    await _settingsBox.put(_lastSyncPreferencesKey, DateTime.now());
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
    await _likeValsBox.put(videoId, true);
  }

  Future<void> removeLike(String videoId) async {
    await _likeValsBox.delete(videoId);
  }

  Future<void> saveDislike(String videoId) async {
    await _likeValsBox.put(videoId, false);
  }

  Future<void> removeDislike(String videoId) async {
    await _likeValsBox.delete(videoId);
  }

  bool isLiked(String videoId) => _likeValsBox.get(videoId) == true;

  bool isDisliked(String videoId) => _likeValsBox.get(videoId) == false;

  // ---------------------------------------------------------------------------
  // Following  →  users/{uid}/following/{followedUserId}/followedAt
  // ---------------------------------------------------------------------------

  Future<void> _syncFollowing(DateTime lastSync, {required bool onlyLoad}) async {
    if (!onlyLoad) {
      final payload = <Map<String, dynamic>>[];
      for (final key in _followingBox.keys) {
        final followedUserId = key as String;
        final followedAt = _followingBox.get(followedUserId)!;
        if (!followedAt.isAfter(lastSync)) continue;
        payload.add({
          'follower_id': userId,
          'following_id': followedUserId,
          'created_at': followedAt.toIso8601String(),
        });
      }
      if (payload.isNotEmpty) {
        await _upsertInChunks('follows', payload, onConflict: 'follower_id, following_id');
      }
    }

    final snapshot = await supabaseClient
        .from('follows')
        .select('following_id, created_at')
        .eq('follower_id', userId)
        .gt('created_at', lastSync.toIso8601String())
        .order('created_at', ascending: false);

    if (snapshot.isEmpty) {
      return;
    }
    final Map<String, DateTime> toWrite = {};
    for (final row in snapshot) {
      final followedAt = DateTime.parse(row['created_at'] as String).toLocal();
      final followedUserId = row['following_id'] as String;
      final local = _followingBox.get(followedUserId);
      if (local == null || followedAt.isAfter(local)) {
        toWrite[followedUserId] = followedAt;
      }
    }

    if (toWrite.isNotEmpty) {
      await _followingBox.putAll(toWrite);
    }

    await _settingsBox.put(_lastSyncFollowingKey, DateTime.parse(snapshot.first['created_at'] as String).toLocal());
  }

  Future<void> _syncConversations(DateTime lastSync) async {
    final memberships = await supabaseClient.from('conversation_members').select('conversation_id').eq('profile_id', userId);
    final conversationIds = memberships.map((row) => row['conversation_id'] as int).toList();
    if (conversationIds.isEmpty) {
      await _settingsBox.put(_lastSyncConversationKey, DateTime.now());
      return;
    }

    final conversations = await supabaseClient
        .from('conversations')
        .select('id, created_at, updated_at')
        .inFilter('id', conversationIds)
        .gt('updated_at', lastSync.toIso8601String())
        .order('updated_at', ascending: false);

    if (conversations.isEmpty) {
      await _settingsBox.put(_lastSyncConversationKey, DateTime.now());
      return;
    }

    final Map<String, Map<String, dynamic>> toWrite = {};

    final memberRows = await supabaseClient
        .from('conversation_members')
        .select('conversation_id, profile_id, profiles!conversation_members_profile_id_fkey(id, username, display_name, avatar_url, bio, created_at)')
        .inFilter('conversation_id', conversations.map((e) => e['id']).toList());

    for (final conversation in conversations) {
      final conversationId = conversation['id'] as int;
      Map<String, dynamic>? partner;
      for (final rawRow in memberRows) {
        final row = Map<String, dynamic>.from(rawRow);
        if (row['conversation_id'] == conversationId && row['profile_id'] != userId) {
          partner = row;
          break;
        }
      }
      if (partner == null) continue;
      final partnerId = partner['profile_id'] as String;
      final existingLocal = _conversationBox.get(partnerId) as Map?;
      final lastMessageAt = DateTime.parse(conversation['updated_at'] as String).toLocal();
      final localLastMessageAt = existingLocal != null ? (existingLocal['lastMessageAt']) : null;

      if (localLastMessageAt == null || lastMessageAt.isAfter(localLastMessageAt)) {
        final partnerProfile = Map<String, dynamic>.from((partner['profiles'] as Map?)?.cast<String, dynamic>() ?? {});
        toWrite[partnerId] = {
          'conversationId': conversationId,
          'partnerId': partnerId,
          'lastMessageAt': lastMessageAt,
          'lastMessage': existingLocal?['lastMessage'] ?? '',
          'createdAt': DateTime.parse(conversation['created_at'] as String).toLocal(),
          'currentUserId': userId,
          'partnerName': partnerProfile['display_name'] ?? partnerProfile['username'] ?? partnerId,
          'partnerProfileImageUrl': partnerProfile['avatar_url'] ?? '',
          'lastMessageByMe': existingLocal?['lastMessageByMe'] ?? false,
        };

        final cursor = _chatCursorBox.get(_conversationId(partnerId));
        if (cursor == null || lastMessageAt.isAfter(cursor)) {
          await _chatCursorBox.put(_conversationId(partnerId), lastMessageAt);
        }
      }
    }

    if (toWrite.isNotEmpty) {
      await _conversationBox.putAll(toWrite);
    }

    final latestConversation = DateTime.parse(conversations.first['updated_at'] as String).toLocal();
    await _settingsBox.put(_lastSyncConversationKey, latestConversation);
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
    final ids = [userId, otherUserId]..sort();
    return '${ids[0]}-${ids[1]}';
  }

  String _chatKey(String conversationId, String messageId) => '$conversationId:$messageId';

  Map<String, dynamic> _messageToMap(ChatMessage message, String conversationId) {
    final isA = currentUser.id.compareTo(conversationId.split('-')[1]) > 0;
    return {'id': message.id, 'message': message.text, 'isA': isA == message.isMe, 'createdAt': message.timestamp, 'status': message.status.index};
  }

  ChatMessage _messageFromMap(Map map, String conversationId) {
    final isA = currentUser.id.compareTo(conversationId.split('-')[1]) > 0;
    return ChatMessage(
      id: map['id'] as String,
      text: map['message'] as String,
      isMe: (map['isA'] as bool) == isA,
      timestamp: map['createdAt'],
      status: MessageStatus.values[map['status'] as int],
    );
  }

  bool hasChatWith(String otherUserId) {
    final conversationId = _conversationId(otherUserId);
    return _chatCursorBox.containsKey(conversationId);
  }

  List<Chat> getChats() {
    List<Chat> chats = _conversationBox.toMap().values.map((e) {
      return Chat.fromJson(e);
    }).toList();
    return chats;
  }

  Chat? getChatWith(String userId) {
    if (!_conversationBox.containsKey(userId)) return null;
    Chat chat = Chat.fromJson(_conversationBox.get(userId));
    return chat;
  }

  Future<void> sendMessageLocal(Chat chat, ChatMessage message) async {
    final conversationId = _conversationId(chat.partnerId);
    final key = _chatKey(conversationId, message.id);

    await _chatBox.put(key, _messageToMap(message, conversationId));

    final existing = _chatCursorBox.get(conversationId);
    if (existing == null || message.timestamp.isAfter(existing)) {
      await _chatCursorBox.put(conversationId, message.timestamp);
    }

    chat.lastMessage = message.text;
    chat.lastMessageAt = message.timestamp;
    chat.lastMessageByMe = message.isMe;
    await _conversationBox.put(chat.partnerId, chat.toJson());
  }

  ChatMessage? getMessage(String otherUserId, String messageId) {
    final conversationId = _conversationId(otherUserId);
    final key = _chatKey(conversationId, messageId);
    final raw = _chatBox.get(key) as Map?;
    if (raw == null) return null;
    return _messageFromMap(raw, conversationId);
  }

  Future<List<ChatMessage>> getMessagesWithLocal(String otherUserId, {int limit = 30, DateTime? startOffset}) async {
    final conversationId = _conversationId(otherUserId);

    final localMessages =
        _chatBox
            .toMap()
            .entries
            .where((e) => (e.key as String).startsWith('$conversationId:'))
            .where((element) {
              return ((element.value['createdAt'] ?? DateTime(0)) as DateTime).isBefore(startOffset ?? DateTime.now());
        })
            .map((e) => _messageFromMap(e.value as Map, conversationId))
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return localMessages.length > limit ? localMessages.sublist(localMessages.length - limit) : localMessages;
  }

  Future<void> saveMessagesLocal(String otherUserId, Iterable<ChatMessage> messages) async {
    final conversationId = _conversationId(otherUserId);
    DateTime? latestTimestamp;

    for (final message in messages) {
      await _chatBox.put(_chatKey(conversationId, message.id), _messageToMap(message, conversationId));
      if (latestTimestamp == null || message.timestamp.isAfter(latestTimestamp)) {
        latestTimestamp = message.timestamp;
      }
    }

    if (latestTimestamp != null) {
      final existing = _chatCursorBox.get(conversationId);
      if (existing == null || latestTimestamp.isAfter(existing)) {
        await _chatCursorBox.put(conversationId, latestTimestamp);
      }
    }
  }

  Future<void> saveChatsLocal(Iterable<Chat> chats) async {
    for (final chat in chats) {
      final existingRaw = _conversationBox.get(chat.partnerId) as Map?;
      final existing = existingRaw == null ? null : Chat.fromJson(Map<String, dynamic>.from(existingRaw));
      final existingTimestamp = existing?.lastMessageAt ?? existing?.createdAt;
      final incomingTimestamp = chat.lastMessageAt ?? chat.createdAt;

      if (existingTimestamp == null || incomingTimestamp.isAfter(existingTimestamp)) {
        await _conversationBox.put(chat.partnerId, chat.toJson());
      }

      final conversationId = _conversationId(chat.partnerId);
      final currentCursor = _chatCursorBox.get(conversationId);
      if (currentCursor == null || incomingTimestamp.isAfter(currentCursor)) {
        await _chatCursorBox.put(conversationId, incomingTimestamp);
      }
    }
  }

  Future<List<ChatMessage>> getMessagesWith(String otherUserId, {int limit = 30, DateTime? startOffset}) async {
    return getMessagesWithLocal(otherUserId, limit: limit, startOffset: startOffset);
  }

  Map<String, String> cachedFcmTokens = {};

  Future<String?> getFcmToken(String userId) async {
    if (cachedFcmTokens.containsKey(userId)) return cachedFcmTokens[userId]!;
    final token = await userRepository.getFcmTokenSupabase(userId);
    if (token == null) return null;
    cachedFcmTokens[userId] = token;

    return token;
  }

  Future<void> saveAuthor(UserProfile user) async {
    await _authorBox.put(user.id, user.toJson());
  }

  UserProfile? getAuthorFromCache(String id) {
    Map<String, dynamic>? json = _authorBox.get(id);
    if (json == null) return null;
    return UserProfile.fromJson(json);
  }

  Future<void> _upsertInChunks(String table, List<Map<String, dynamic>> payload, {required String onConflict, int chunkSize = 200}) async {
    for (int i = 0; i < payload.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(i, payload.length);
      await supabaseClient.from(table).upsert(payload.sublist(i, end), onConflict: onConflict);
    }
  }
}

DateTime olderDate(DateTime? d1, DateTime? d2) {
  assert(!(d1 == null && d2 == null));
  if (d1 == null) return d2!;
  if (d2 == null) return d1;
  return d1.isBefore(d2) ? d1 : d2;
}
