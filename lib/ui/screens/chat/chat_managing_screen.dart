import 'package:flutter/material.dart';
import 'package:wurp/logic/chat/chat_message.dart';
import 'package:wurp/ui/misc/avatar.dart';
import 'package:wurp/ui/screens/chat/chat_screen.dart';

import '../../../base_logic.dart';
import '../../../logic/chat/chat.dart';
import '../../../util/misc/time_formatting.dart';

GlobalKey<ChatManagingScreenState> chatManagingScreenKey = GlobalKey();

class ChatManagingScreen extends StatefulWidget {
  final Future<({List<Chat> result, int? newCurrent})> Function(int? current) preloadMoreChats;

  const ChatManagingScreen({super.key, required this.preloadMoreChats});

  @override
  State<ChatManagingScreen> createState() => ChatManagingScreenState();
}

class ChatManagingScreenState extends State<ChatManagingScreen> {
  late final ScrollController _scrollController;
  final List<Chat> chats = [];

  int? currentLastIndex;

  @override
  void initState() {
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) => _preload());
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
    if (loading) return;
    loading = true;

    try {
      final preloadedChatsResult = await widget.preloadMoreChats(currentLastIndex);
      currentLastIndex = preloadedChatsResult.newCurrent;
      final preloadedChats = preloadedChatsResult.result;
      chats.addAll(preloadedChats);
      reSortChats();
      if (mounted) {
        setState(() {});
      }
      if (preloadedChats.isEmpty || currentLastIndex == null) {
        noMoreChats = true;
      }
    } finally {
      loading = false;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text("Chats", textAlign: TextAlign.center,),
        backgroundColor: theme.colorScheme.surfaceContainerLow,
        centerTitle: true,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadiusGeometry.only(bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18)),
        ),
      ),
      body: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: _buildChatList(chats)),
    );
  }

  void onMessageUpdate(Chat chat, ChatMessage message) {
    if(message.timestamp.isBefore(chat.lastMessageAt ?? chat.createdAt)) {
      return;
    }

    
    setState(() {
      final manageableChat = chats.firstWhere((c) => c.partnerId == chat.partnerId, orElse: () => chat);
      manageableChat.lastMessage = message.text;
      manageableChat.lastMessageAt = message.timestamp;
      manageableChat.lastMessageByMe = message.isMe;
    });
  }

  Widget _buildChatList(List<Chat> chats) {
    if (loading && chats.isEmpty) {
      return const SizedBox.shrink();
    }

    if (chats.isEmpty) {
      return const Center(child: Text("No Chats yet!"));
    }

    return ListView.separated(
      itemCount: chats.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildChatEntry(chats[index], (message) => onMessageUpdate(chats[index], message));
      },
      controller: _scrollController,
    );
  }

  Widget _buildChatEntry(Chat chat, void Function(ChatMessage) onMessageUpdate) {
    final theme = Theme.of(context);

    final lastMessageTime = chat.lastMessageAt ?? chat.createdAt;
    final timeString = formatTime(lastMessageTime);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surfaceContainer,
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
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
                    Text(timeString, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.secondary)),
                    const SizedBox(height: 6),

                    if (!chat.lastMessageByMe)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: theme.colorScheme.tertiary, shape: BoxShape.circle),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void reSortChats() {
    chats.sort((a, b) {
      final aTime = (a.lastMessageAt ?? a.createdAt).toLocal();
      final bTime = (b.lastMessageAt ?? b.createdAt).toLocal();
      return bTime.compareTo(aTime);
    });
  }

  void _openChat(Chat chat, void Function(ChatMessage) onMessageUpdate) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) => buildMessagingScreen(chat, onMessageUpdate),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
          return ClipRect(
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );

    setState(() {
      reSortChats();
    });
  }
}

Chat? currentOpenChat;
GlobalObjectKey<MessagingScreenState>? currentOpenChatScreenKey;

Widget buildMessagingScreen(Chat chat, void Function(ChatMessage) onMessageUpdate) {
  currentOpenChatScreenKey = GlobalObjectKey('chat${currentUser.id}-${chat.partnerId}-${DateTime.now().millisecondsSinceEpoch}');
  currentOpenChat = chat;
  return FutureBuilder(
    future: userRepository.getUser(chat.partnerId),
    builder: (context, asyncSnapshot) {
      if (!asyncSnapshot.hasData) return const SizedBox.shrink();

      return MessagingScreen(
        key: currentOpenChatScreenKey,
        user: asyncSnapshot.data!,
        onMessageUpdate: onMessageUpdate,
        onSend: (message) async {
          chatManager.addChat(chat, replaceExisting: false);
          await chatRepository.sendNotification(
            chat: chat,
            message: ChatMessage(id: "${chat.partnerId}-${DateTime.now().microsecondsSinceEpoch}", text: message, isMe: true, timestamp: DateTime.now()),
          );
        },
        loadMoreMessages: (int limit, DateTime? lastVisibleMessage) async {
          print("Loading more messages for chat ${chat.partnerId} with offset $lastVisibleMessage and limit $limit");
          return chatRepository.getMessagesWith(chat.partnerId, startOffset: lastVisibleMessage, limit: limit);
        },
      );
    },
  );
}
