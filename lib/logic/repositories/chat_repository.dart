import '../../base_logic.dart';
import '../../tools/supabase_tests/supabase_login_test.dart';
import '../chat/chat.dart';
import '../chat/chat_message.dart';
import '../local_storage/local_seen_service.dart';
import '../users/user_model.dart';

class ChatRepository {
  static const Duration _chatPageCacheTtl = Duration(seconds: 20);
  static const Duration _conversationSyncMinInterval = Duration(seconds: 4);
  final Map<String, _CachedChatsPage> _chatPageCache = {};
  final Map<String, Future<({int? newCurrent, List<Chat> result})>> _inFlightChatPages = {};
  final Map<String, _CachedConversationId> _conversationIdCache = {};
  Future<void>? _conversationSyncTask;
  DateTime? _lastConversationSyncAt;

  Future<void> sendNotification({required Chat chat, required ChatMessage message}) async {
    final receiverUid = chat.partnerId;
    final conversationId = await _getOrCreateDirectConversation(
      receiverUid,
      partnerName: chat.partnerName,
      partnerProfileImageUrl: chat.partnerProfileImageUrl,
    );
    chat.conversationId = conversationId;

    await supabaseClient
        .from('conversations')
        .update({'updated_at': DateTime.now().toUtc().toIso8601String(), 'last_message': "${currentUser.id}: ${message.text}"})
        .eq('id', conversationId);

    await supabaseClient
        .from('messages')
        .insert({
      'conversation_id': conversationId,
      'sender_id': currentUser.id,
      'content': message.text,
      'type': 'text',
      'created_at': message.timestamp.toUtc().toIso8601String(),
      'reply_to_message_id': null,
    });

    await localSeenService.sendMessageLocal(chat, message);
    chat.lastMessage = message.text;
    chat.lastMessageAt = message.timestamp;
    chat.lastMessageByMe = true;
    _invalidateChatPagesForUser(currentUser.id);
    print("updated timestamps");
  }

  /// Loads messages with [otherUserId].
  ///
  /// Strategy:
  /// 1. Load from local cache (fast, offline-capable).
  /// 2. Determine the newest local timestamp to use as sync anchor.
  /// 3. Fetch any server messages newer than that anchor (or all if cache
  ///    is empty) and merge them into the local cache.
  /// 4. Return the merged, sorted, limited result.
  Future<List<ChatMessage>> getMessagesWith(
      String otherUserId, {
        int limit = 30,
        DateTime? startOffset,
      }) async {
    // 1. Local messages first.
    final localMessages = await localSeenService.getMessagesWithLocal(
      otherUserId,
      limit: limit,
      startOffset: startOffset,
    );

    // 2. Find the conversation id so we can query the server.
    final conversationId = await _findDirectConversationId(otherUserId);
    if (conversationId == null) {
      // No conversation on server yet – return local only.
      final result = localMessages..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return result.length > limit ? result.sublist(result.length - limit) : result;
    }

    // 3. Determine the sync anchor:
    //    • If we have local messages, only fetch messages newer than the latest one.
    //    • If the cache is empty (or a startOffset is given), fetch from startOffset.
    DateTime? syncFrom;
    if (localMessages.isNotEmpty) {
      final latestLocal = localMessages.map((m) => m.timestamp).reduce((a, b) => a.isAfter(b) ? a : b);
      syncFrom = latestLocal;
    } else {
      syncFrom = startOffset;
    }

    // 4. Fetch server messages.
    final serverMessages = await _fetchMessagesFromServer(
      conversationId: conversationId,
      otherUserId: otherUserId,
      limit: limit,
      after: syncFrom,
      // When there is no anchor we also need messages *before* startOffset.
      before: localMessages.isEmpty ? startOffset : null,
    );

    if (serverMessages.isNotEmpty) {
      // 5. Persist new server messages locally so future calls are faster.
      await localSeenService.saveMessagesLocal(otherUserId, serverMessages);
    }

    // 6. Merge: local wins for duplicates (preserves any local-only metadata).
    final merged = <String, ChatMessage>{
      for (final m in serverMessages) m.id: m,
      for (final m in localMessages) m.id: m, // local overwrites server
    };

    final result = merged.values.toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result.length > limit ? result.sublist(result.length - limit) : result;
  }

  /// Fetches messages from the `messages` table for [conversationId].
  ///
  /// Pass [after] to only load messages newer than that timestamp (sync mode).
  /// Pass [before] to only load messages older than that timestamp (pagination).
  /// When both are null all messages up to [limit] are returned.
  Future<List<ChatMessage>> _fetchMessagesFromServer({
    required int conversationId,
    required String otherUserId,
    int limit = 30,
    DateTime? after,
    DateTime? before,
  }) async {
    try {
      var query = supabaseClient
          .from('messages')
          .select('id, conversation_id, sender_id, content, type, reply_to_message_id, created_at, deleted_at')
          .eq('conversation_id', conversationId)
          .isFilter('deleted_at', null); // exclude soft-deleted messages


      if (after != null) {
        query = query.gt('created_at', after.toUtc().toIso8601String());
      }
      if (before != null) {
        query = query.lt('created_at', before.toUtc().toIso8601String());
      }

      final rows = (await (query.order('created_at', ascending: false)
          .limit(limit)) as List)
          .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
          .toList();

      return rows.map((row) => _rowToChatMessage(row, otherUserId)).toList();
    } catch (e) {
      print('Error fetching messages from server: $e');
      return [];
    }
  }

  /// Converts a raw Supabase `messages` row into a [ChatMessage].
  ChatMessage _rowToChatMessage(Map<String, dynamic> row, String otherUserId) {
    final senderId = row['sender_id'] as String? ?? '';
    final isMe = senderId == currentUser.id;
    return ChatMessage(
      id: (row['id'] as int).toString(),
      text: row['content'] as String? ?? '',
      timestamp: _parseDateTime(row['created_at']),
      isMe: isMe,
      replyToMessageId: (row['reply_to_message_id'] as int?)?.toString(),
      type: row['type'] as String? ?? 'text',
    );
  }

  ChatMessage? getMessage(String otherUserId, String messageId) {
    return localSeenService.getMessage(otherUserId, messageId);
  }

  Future<({int? newCurrent, List<Chat> result})> getChats(
      String userId, {
        int limit = 10,
        int offset = 0,
      }) async {
    final cacheKey = _getChatsCacheKey(userId: userId, limit: limit, offset: offset);
    final cachedPage = _chatPageCache[cacheKey];
    if (cachedPage != null && !cachedPage.isExpired) {
      return _cloneChatPage(cachedPage.value);
    }

    final inFlight = _inFlightChatPages[cacheKey];
    if (inFlight != null) {
      return _cloneChatPage(await inFlight);
    }

    final fetch = _getChatsFromLocalWithIncrementalSync(userId, limit: limit, offset: offset).then((value) {
      _chatPageCache[cacheKey] = _CachedChatsPage(value);
      return value;
    }).whenComplete(() {
      _inFlightChatPages.remove(cacheKey);
    });
    _inFlightChatPages[cacheKey] = fetch;
    return _cloneChatPage(await fetch);
  }

  Future<({int? newCurrent, List<Chat> result})> _getChatsFromLocalWithIncrementalSync(
    String userId, {
    int limit = 10,
    int offset = 0,
  }) async {
    await _syncConversationsIncrementalIfNeeded();
    final localChats = localSeenService.getChats()
      ..sort((a, b) => (b.lastMessageAt ?? b.createdAt).compareTo(a.lastMessageAt ?? a.createdAt));
    final page = localChats.skip(offset).take(limit).toList();
    return (
      result: page,
      newCurrent: localChats.length > offset + page.length ? offset + page.length : null,
    );
  }

  Future<void> _syncConversationsIncrementalIfNeeded() async {
    final now = DateTime.now();
    if (_lastConversationSyncAt != null && now.difference(_lastConversationSyncAt!) < _conversationSyncMinInterval) {
      return;
    }
    if (_conversationSyncTask != null) {
      return _conversationSyncTask;
    }
    _conversationSyncTask = localSeenService.syncConversationsIncremental().whenComplete(() {
      _lastConversationSyncAt = DateTime.now();
      _conversationSyncTask = null;
    });
    return _conversationSyncTask;
  }

  Future<int?> _findDirectConversationId(String receiverId) async {
    final cached = _conversationIdCache[receiverId];
    if (cached != null && !cached.isExpired) {
      return cached.value;
    }

    final cachedChat = localSeenService.getChatWith(receiverId);
    if (cachedChat?.conversationId != null) {
      _conversationIdCache[receiverId] = _CachedConversationId(cachedChat!.conversationId);
      return cachedChat.conversationId;
    }

    final currentMembershipRows =
    await supabaseClient.from('conversation_members').select('conversation_id').eq('profile_id', currentUser.id);
    final currentConversationIds = (currentMembershipRows as List)
        .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
        .map<int>((row) => row['conversation_id'] as int)
        .toList();
    if (currentConversationIds.isEmpty) {
      return null;
    }

    final receiverMembershipRows = await supabaseClient
        .from('conversation_members')
        .select('conversation_id')
        .eq('profile_id', receiverId)
        .inFilter('conversation_id', currentConversationIds);
    final sharedConversationIds = (receiverMembershipRows as List)
        .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
        .map<int>((row) => row['conversation_id'] as int)
        .toList();
    if (sharedConversationIds.isEmpty) {
      return null;
    }

    final directConversations = await supabaseClient
        .from('conversations')
        .select('id')
        .eq('type', 'direct')
        .inFilter('id', sharedConversationIds)
        .limit(1);

    final directConversationList = (directConversations as List).map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row)).toList();
    if (directConversationList.isEmpty) {
      _conversationIdCache[receiverId] = _CachedConversationId(null);
      return null;
    }
    final conversationId = directConversationList.first['id'] as int;
    _conversationIdCache[receiverId] = _CachedConversationId(conversationId);
    return conversationId;
  }

  Future<int> _getOrCreateDirectConversation(
      String receiverId, {
        required String partnerName,
        required String partnerProfileImageUrl,
      }) async {
    final existingConversationId = await _findDirectConversationId(receiverId);
    if (existingConversationId != null) {
      _conversationIdCache[receiverId] = _CachedConversationId(existingConversationId);
      return existingConversationId;
    }

    print("No existing conversation found with $receiverId, creating a new one. currentUser: ${currentUser.id}");

    final conversationId = await supabaseClient.rpc(
      'create_conversation',
      params: {
        'p_receiver_id': receiverId,
        'p_title': null,
        'p_type': 'direct',
      },
    ) as int;

    final now = DateTime.now();

    await localSeenService.saveChatsLocal([
      Chat(
        conversationId: conversationId,
        partnerId: receiverId,
        partnerProfileImageUrl: partnerProfileImageUrl,
        partnerName: partnerName,
        lastMessage: '',
        lastMessageAt: now,
        lastMessageByMe: false,
        createdAt: now,
      ),
    ]);
    _conversationIdCache[receiverId] = _CachedConversationId(conversationId);
    _invalidateChatPagesForUser(currentUser.id);

    return conversationId;
  }

  void _invalidateChatPagesForUser(String userId) {
    final prefix = '$userId:';
    _chatPageCache.removeWhere((key, _) => key.startsWith(prefix));
  }

  String _getChatsCacheKey({
    required String userId,
    required int limit,
    required int offset,
  }) {
    return '$userId:$offset:$limit';
  }

  ({int? newCurrent, List<Chat> result}) _cloneChatPage(({int? newCurrent, List<Chat> result}) page) {
    return (
      newCurrent: page.newCurrent,
      result: page.result.map(_cloneChat).toList(),
    );
  }

  Chat _cloneChat(Chat chat) {
    return Chat.fromJson(chat.toJson(), customPartnerId: chat.partnerId);
  }
}

String getChatId({String? currentUserId, required String receiverId}) {
  final userId = currentUserId ?? currentUser.id;
  final ids = [userId, receiverId]..sort();
  return "${ids[0]}-${ids[1]}";
}

DateTime _parseDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  return DateTime.now();
}

class _CachedChatsPage {
  final ({int? newCurrent, List<Chat> result}) value;
  final DateTime cachedAt;

  _CachedChatsPage(this.value) : cachedAt = DateTime.now();

  bool get isExpired => DateTime.now().difference(cachedAt) > ChatRepository._chatPageCacheTtl;
}

class _CachedConversationId {
  static const Duration _ttl = Duration(minutes: 5);
  final int? value;
  final DateTime cachedAt;

  _CachedConversationId(this.value) : cachedAt = DateTime.now();

  bool get isExpired => DateTime.now().difference(cachedAt) > _ttl;
}
