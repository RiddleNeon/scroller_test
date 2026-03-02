import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wurp/logic/chat/chat_message.dart';
import 'package:wurp/main.dart';
import 'package:wurp/ui/misc/avatar.dart';
import 'package:wurp/ui/screens/chat/chat_screen.dart';

import '../../../logic/chat/chat.dart';

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
    if(mounted){
      setState(() {});
    }
    if(preloadedChats.isEmpty || currentLastIndex == null) {
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

  Widget _buildChatList(List<Chat> chats) {
    if (chats.isEmpty) {
      return const Center(child: Text("No Chats yet!"));
    }

    return ListView.separated(
      itemCount: chats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildChatEntry(chats[index]);
      },
      controller: _scrollController,
    );
  }

  Widget _buildChatEntry(Chat chat) {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openChat(chat),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Avatar(imageUrl: chat.partnerProfileImageUrl, name: chat.partnerName, colorScheme: theme.colorScheme),
              const SizedBox(width: 16),
              Expanded(child: _buildChatLabel(chat.partnerName)),
              Icon(Icons.arrow_forward_ios_rounded, size: 18, color: theme.colorScheme.primary),
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

  void _openChat(Chat chat) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => buildMessagingScreen(chat)));
  }
}

Chat? currentOpenChat;
GlobalObjectKey<MessagingScreenState>? currentOpenChatScreenKey;

Widget buildMessagingScreen(Chat chat) {
  currentOpenChatScreenKey = GlobalObjectKey('chat${currentUser.id}-${chat.partnerId}');
  currentOpenChat = chat;
  return MessagingScreen(
    key: currentOpenChatScreenKey,
    recipientName: chat.partnerName,
    recipientAvatarUrl: chat.partnerProfileImageUrl,
    onSend: (message) async {
      chatManager.addChat(chat, replaceExisting: false);
      print("message sent");
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
