import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wurp/logic/chat/chat_message.dart';
import 'package:wurp/ui/misc/avatar.dart';
import 'package:wurp/ui/screens/chat/chat_screen.dart';

import '../../../base_logic.dart';
import '../../../logic/chat/chat.dart';
import '../../../logic/local_storage/local_seen_service.dart';
import '../../../util/misc/time_formatting.dart';

class ChatManagingScreen extends StatefulWidget {
  final Future<({List<Chat> result, DocumentSnapshot? newCurrent})> Function(DocumentSnapshot? current) preloadMoreChats;

  const ChatManagingScreen({super.key, required this.preloadMoreChats});

  @override
  State<ChatManagingScreen> createState() => _ChatManagingScreenState();
}

class _ChatManagingScreenState extends State<ChatManagingScreen> {
  late final ScrollController _scrollController;
  final List<Chat> chats = [];

  DocumentSnapshot? currentLastIndex;

  @override
  void initState() {
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    Future.delayed(const Duration(milliseconds: 50), _preload);
    super.initState();
  }

  bool noMoreChats = false;
  bool loading = false;

  void _onScroll() async {
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 60 && !loading && !noMoreChats) {
      _preload();
    }
  }

  void _preload() async {
    print("preloading more chats!");
    loading = true;

    final preloadedChatsResult = await widget.preloadMoreChats(currentLastIndex);
    currentLastIndex = preloadedChatsResult.newCurrent;
    final preloadedChats = preloadedChatsResult.result;
    chats.addAll(preloadedChats);
    chats.sort((a, b) => b.lastMessageAt?.compareTo(a.lastMessageAt ?? DateTime.now()) ?? -1);
    if (mounted) {
      setState(() {});
    }
    if (preloadedChats.isEmpty || currentLastIndex == null) {
      print("no more chats!");
      noMoreChats = true;
    }
    loading = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Align(
          alignment: AlignmentGeometry.center,
          child: Text("Chats", textAlign: TextAlign.center),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: _buildChatList(chats)),
    );
  }

  void onMessageUpdate(Chat chat, ChatMessage message) {
    setState(() {
      chat.lastMessage = message.text;
      chat.lastMessageAt = message.timestamp;
      chat.lastMessageByMe = message.isMe;
      chats.sort((a, b) => b.lastMessageAt?.compareTo(a.lastMessageAt ?? DateTime.now()) ?? -1);
    });
  }

  Widget _buildChatList(List<Chat> chats) {
    if (chats.isEmpty) {
      return const Center(child: Text("No Chats yet!"));
    }

    return ListView.separated(
      itemCount: chats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildChatEntry(chats[index], (message) => onMessageUpdate(chats[index], message));
      },
      controller: _scrollController,
    );
  }

  Widget _buildChatEntry(Chat chat, void Function(ChatMessage onMessage) onMessageUpdate) {
    final theme = Theme.of(context);

    final lastMessageTime = chat.lastMessageAt ?? chat.createdAt;
    final timeString = formatTime(lastMessageTime);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openChat(chat, onMessageUpdate),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Avatar(imageUrl: chat.partnerProfileImageUrl, name: chat.partnerName, colorScheme: theme.colorScheme),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat.partnerName,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    Text(
                      "${chat.lastMessageByMe ? "You: " : ""}${chat.lastMessage}",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: chat.lastMessageByMe ? FontWeight.w400 : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(timeString, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                  const SizedBox(height: 6),

                  if (!chat.lastMessageByMe)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatLabel(String name) {
    final theme = Theme.of(context);

    return Text(
      name,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
      overflow: TextOverflow.ellipsis,
    );
  }

  void _openChat(Chat chat, void Function(ChatMessage) onMessageUpdate) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => buildMessagingScreen(chat, onMessageUpdate)));
  }
}

Chat? currentOpenChat;
GlobalObjectKey<MessagingScreenState>? currentOpenChatScreenKey;

Widget buildMessagingScreen(Chat chat, void Function(ChatMessage) onMessageUpdate) {
  currentOpenChatScreenKey = GlobalObjectKey('chat${currentUser.id}-${chat.partnerId}');
  currentOpenChat = chat;
  return MessagingScreen(
    key: currentOpenChatScreenKey,
    recipientName: chat.partnerName,
    recipientAvatarUrl: chat.partnerProfileImageUrl,
    recipientId: chat.partnerId,
    onMessageUpdate: onMessageUpdate,
    onSend: (message) async {
      chatManager.addChat(chat, replaceExisting: false);
      await chatRepository.sendNotification(
        chat: chat,
        message: ChatMessage(id: "${chat.partnerId}-${DateTime.now().microsecondsSinceEpoch}", text: message, isMe: true, timestamp: DateTime.now()),
      );
    },
    loadMoreMessages: (int limit, DateTime? lastVisibleMessage) async {
      return localSeenService.getMessagesWith(chat.partnerId, startOffset: lastVisibleMessage, limit: limit);
    },
  );
}
