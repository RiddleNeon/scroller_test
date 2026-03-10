import '../../base_logic.dart';
import '../chat/chat.dart';
import '../chat/chat_message.dart';
import '../local_storage/local_seen_service.dart';
import '../models/user_model.dart';

class ChatRepository {
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
        .update({'updated_at': DateTime.now().toIso8601String()})
        .eq('id', conversationId);

    await localSeenService.sendMessageLocal(chat, message);
    chat.lastMessage = message.text;
    chat.lastMessageAt = message.timestamp;
    chat.lastMessageByMe = true;
  }

  Future<List<ChatMessage>> getMessagesWith(
    String otherUserId, {
    int limit = 30,
    DateTime? startOffset,
  }) async {
    final localMessages = await localSeenService.getMessagesWithLocal(
      otherUserId,
      limit: limit,
      startOffset: startOffset,
    );
    final merged = <String, ChatMessage>{for (final message in localMessages) message.id: message};

    final result = merged.values.toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result.length > limit ? result.sublist(result.length - limit) : result;
  }

  ChatMessage? getMessage(String otherUserId, String messageId) {
    return localSeenService.getMessage(otherUserId, messageId);
  }

  Future<({int? newCurrent, List<Chat> result})> getChats(
    String userId, {
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final membershipRows =
          await supabaseClient.from('conversation_members').select('conversation_id').eq('profile_id', userId);

      final membershipList = (membershipRows as List).map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row)).toList();
      final conversationIds = membershipList.map<int>((row) => row['conversation_id'] as int).toSet().toList();
      if (conversationIds.isEmpty) {
        final localChats = localSeenService.getChats();
        final page = localChats.skip(offset).take(limit).toList();
        return (
          result: page,
          newCurrent: localChats.length > offset + page.length ? offset + page.length : null,
        );
      }

      final conversationsResponse = await supabaseClient
          .from('conversations')
          .select('id, type, created_by, title, created_at, updated_at')
          .inFilter('id', conversationIds);

      final conversations = (conversationsResponse as List)
          .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
          .toList()
        ..sort((a, b) => _parseDateTime(b['updated_at']).compareTo(_parseDateTime(a['updated_at'])));

      final page = conversations.skip(offset).take(limit).toList();
      if (page.isEmpty) {
        final localChats = localSeenService.getChats();
        final localPage = localChats.skip(offset).take(limit).toList();
        return (
          result: localPage,
          newCurrent: localChats.length > offset + localPage.length ? offset + localPage.length : null,
        );
      }

      final pagedConversationIds = page.map<int>((row) => row['id'] as int).toList();
      final membersResponse = await supabaseClient
          .from('conversation_members')
          .select('conversation_id, profile_id, profiles!conversation_members_profile_id_fkey(id, username, display_name, avatar_url, bio, created_at)')
          .inFilter('conversation_id', pagedConversationIds);
      final membersByConversation = <int, List<Map<String, dynamic>>>{};
      for (final rawMember in membersResponse as List) {
        final member = Map<String, dynamic>.from(rawMember);
        final conversationId = member['conversation_id'] as int;
        membersByConversation.putIfAbsent(conversationId, () => []).add(member);
      }

      final chats = <Chat>[];
      for (final conversation in page) {
        final conversationId = conversation['id'] as int;
        final members = membersByConversation[conversationId] ?? const [];
        Map<String, dynamic>? partnerMember;
        for (final member in members) {
          if (member['profile_id'] != userId) {
            partnerMember = member;
            break;
          }
        }
        if (partnerMember == null) {
          continue;
        }

        final profileData = Map<String, dynamic>.from(
          (partnerMember['profiles'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
        );
        final partnerProfile = UserProfile.fromJson({
          'id': partnerMember['profile_id'],
          'username': profileData['display_name'] ?? profileData['username'] ?? partnerMember['profile_id'],
          ...profileData,
        });

        chats.add(
          Chat.fromSupabase(
            conversation: conversation,
            partner: partnerProfile,
            currentUserId: userId,
            lastMessage: null,
          ),
        );
      }

      await localSeenService.saveChatsLocal(chats);

      return (
        result: chats,
        newCurrent: conversations.length > offset + page.length ? offset + page.length : null,
      );
    } catch (e) {
      print('Error fetching chats from Supabase: $e');
      final localChats = localSeenService.getChats();
      final page = localChats.skip(offset).take(limit).toList();
      return (
        result: page,
        newCurrent: localChats.length > offset + page.length ? offset + page.length : null,
      );
    }
  }

  Future<int?> _findDirectConversationId(String receiverId) async {
    final cachedChat = localSeenService.getChatWith(receiverId);
    if (cachedChat?.conversationId != null) {
      return cachedChat!.conversationId;
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
      return null;
    }
    return directConversationList.first['id'] as int;
  }

  Future<int> _getOrCreateDirectConversation(
    String receiverId, {
    required String partnerName,
    required String partnerProfileImageUrl,
  }) async {
    final existingConversationId = await _findDirectConversationId(receiverId);
    if (existingConversationId != null) {
      return existingConversationId;
    }

    final conversationResponse = await supabaseClient
        .from('conversations')
        .insert({
          'type': 'direct',
          'created_by': currentUser.id,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select('id, created_at, updated_at')
        .single();

    final conversationId = conversationResponse['id'] as int;

    await supabaseClient.from('conversation_members').insert([
      {
        'conversation_id': conversationId,
        'profile_id': currentUser.id,
      },
      {
        'conversation_id': conversationId,
        'profile_id': receiverId,
      },
    ]);

    await localSeenService.saveChatsLocal([
      Chat(
        conversationId: conversationId,
        partnerId: receiverId,
        partnerProfileImageUrl: partnerProfileImageUrl,
        partnerName: partnerName,
        lastMessage: '',
        lastMessageAt: _parseDateTime(conversationResponse['updated_at']),
        lastMessageByMe: false,
        createdAt: _parseDateTime(conversationResponse['created_at']),
      ),
    ]);

    return conversationId;
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
