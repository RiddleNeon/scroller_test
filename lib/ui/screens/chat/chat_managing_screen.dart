import 'package:flutter/material.dart';
import 'package:wurp/logic/chat/chat_message.dart';
import 'package:wurp/main.dart';
import 'package:wurp/ui/screens/chat/chat_screen.dart';
import '../../../logic/chat/chat.dart';

class ChatManagingScreen extends StatefulWidget {
  const ChatManagingScreen({super.key});

  @override
  State<ChatManagingScreen> createState() => _ChatManagingScreenState();
}

class _ChatManagingScreenState extends State<ChatManagingScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Align(alignment: AlignmentGeometry.center, child: Text("Chats", textAlign: TextAlign.center,)),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: _buildChatList(chatManager.chats),
      ),
    );
  }

  Widget _buildChatList(List<Chat> chats) {
    if (chats.isEmpty) {
      return const Center(
        child: Text("No Chats yet!"),
      );
    }

    return ListView.separated(
      itemCount: chats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildChatEntry(chats[index]);
      },
    );
  }

  Widget _buildChatEntry(Chat chat) {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openChat(chat),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _buildAvatar(chat.partnerProfileImageUrl, theme.colorScheme),
              const SizedBox(width: 16),
              Expanded(
                child: _buildChatLabel(chat.partnerName),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String profileImageUrl, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [cs.primary, cs.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: CircleAvatar(
        radius: 26,
        backgroundColor: cs.surfaceContainer,
        backgroundImage: NetworkImage(profileImageUrl)
      ),
    );
  }

  Widget _buildChatLabel(String name) {
    final theme = Theme.of(context);

    return Text(
      name,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  void _openChat(Chat chat) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => buildMessagingScreen(chat),
      ),
    );
  }
}
Chat? currentOpenChat;
GlobalObjectKey<MessagingScreenState>? currentOpenChatScreenKey;

Widget buildMessagingScreen(Chat chat) {
  currentOpenChatScreenKey = GlobalObjectKey('chat${currentUser.id}-${chat.partnerId}');
  currentOpenChat = chat;
  return FutureBuilder(
    future: localSeenService.getMessagesWith(chat.partnerId),
    builder: (context, asyncSnapshot) {
      if (asyncSnapshot.data == null) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      return MessagingScreen(
        key: currentOpenChatScreenKey,
        initialMessages: asyncSnapshot.data!,
        recipientName: chat.partnerName,
        recipientAvatarUrl: chat.partnerProfileImageUrl,
        onSend: (message) async {
          chatManager.addChat(chat, replaceExisting: false);
          await chatRepository.sendNotification(
            receiverUid: chat.partnerId,
            message: ChatMessage(
              id: "${chat.partnerId}-${DateTime.now().microsecondsSinceEpoch}",
              text: message,
              isMe: true,
              timestamp: DateTime.now(),
            ),
          );
        },
      );
    },
  );
}