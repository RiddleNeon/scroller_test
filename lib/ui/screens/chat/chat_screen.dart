import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:wurp/logic/repositories/user_repository.dart';
import 'package:wurp/logic/users/user_model.dart';
import 'package:wurp/logic/repositories/chat_repository.dart';
import 'package:wurp/logic/repositories/video_repository.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/ui/animations/slide_morph_transitions.dart';
import 'package:wurp/ui/feed_view_model.dart';
import 'package:wurp/ui/misc/avatar.dart';
import 'package:wurp/ui/screens/search_screen/search_screen.dart';

import '../../../base_logic.dart';
import '../../../logic/chat/chat_message.dart';
import '../../../logic/local_storage/local_seen_service.dart';
import '../profile_screen.dart';
import 'calling_screen.dart';
import 'chat_route_preview.dart';

class MessagingScreen extends StatefulWidget {
  final Future<void> Function(String message) onSend;
  final Future<ChatMessage> Function(ChatMessage message, String newText) onEditMessage;
  final Future<void> Function(ChatMessage message) onDeleteMessage;
  final Future<List<MessageVersion>> Function(ChatMessage message) onLoadMessageVersions;
  final Future<bool> Function() canViewMessageHistory;
  final void Function(ChatMessage message) onMessageUpdate;
  final Future<List<ChatMessage>> Function(int limit, DateTime? lastVisibleMessage) loadMoreMessages;

  String? get recipientName => user.username;

  String get recipientId => user.id;

  String? get recipientAvatarUrl => user.profileImageUrl;

  final UserProfile user;

  final bool isOnline;

  const MessagingScreen({
    super.key,
    required this.onSend,
    required this.onEditMessage,
    required this.onDeleteMessage,
    required this.onLoadMessageVersions,
    required this.canViewMessageHistory,
    this.isOnline = true,
    required this.loadMoreMessages,
    required this.onMessageUpdate,
    required this.user,
  });

  @override
  State<MessagingScreen> createState() => MessagingScreenState();
}

class MessagingScreenState extends State<MessagingScreen> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool moreMessagesAvailable = true;
  DateTime? currentMessageCursor;

  late final List<ChatMessage> _messages = [];
  final List<AnimationController> _bubbleControllers = [];

  bool _isTyping = false;
  bool _showScrollDown = false;
  bool _partnerTyping = false;
  String? _editingMessageId;
  bool _canViewMessageHistory = false;
  final Map<String, Future<ChatRoutePreview?>> _previewFutureCache = {};
  List<String>? _sharedFeedVideoIds;
  Future<List<String>>? _sharedFeedVideoIdsTask;

  late AnimationController _typingDotController;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);

    _typingDotController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _loadHistoryPermission();

    for (var _ in _messages) {
      _createBubbleController(animate: true);
    }
    _preloadMore();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: Duration.zero, curve: Curves.linear);
    });
  }

  Future<ChatRoutePreview?> _previewFutureFor(ChatRouteReference ref) {
    return _previewFutureCache.putIfAbsent(ref.route, () => ChatRoutePreviewResolver.resolve(ref));
  }

  List<String> _collectSharedFeedVideoIds() {
    final seen = <String>{};
    final ids = <String>[];
    for (final message in _messages) {
      for (final ref in ChatRoutePreviewResolver.extract(message.text)) {
        if (!ref.uri.path.startsWith('/feed/')) continue;
        final pathId = ref.uri.pathSegments.length > 1 ? ref.uri.pathSegments[1] : '';
        if (pathId.isNotEmpty && seen.add(pathId)) {
          ids.add(pathId);
        }
      }
    }
    return ids;
  }

  Future<List<String>> _loadSharedFeedVideoIds() {
    final cached = _sharedFeedVideoIds;
    if (cached != null) return Future.value(cached);

    final inFlight = _sharedFeedVideoIdsTask;
    if (inFlight != null) return inFlight;

    final task = chatRepository
        .getSharedFeedVideoIdsWith(widget.recipientId)
        .then((ids) {
          final result = ids.isEmpty ? _collectSharedFeedVideoIds() : ids;
          _sharedFeedVideoIds = result;
          return result;
        })
        .catchError((_) {
          final fallback = _collectSharedFeedVideoIds();
          _sharedFeedVideoIds = fallback;
          return fallback;
        })
        .whenComplete(() {
          _sharedFeedVideoIdsTask = null;
        });

    _sharedFeedVideoIdsTask = task;
    return task;
  }

  Future<String> _withChatFeedContext(String route) async {
    final uri = Uri.tryParse(route);
    if (uri == null || !uri.path.startsWith('/feed/')) return route;
    final currentVideoId = uri.pathSegments.length > 1 ? uri.pathSegments[1] : '';
    if (currentVideoId.isEmpty) return route;

    final ids = <String>[currentVideoId, ...await _loadSharedFeedVideoIds()];
    final unique = <String>[];
    final seen = <String>{};
    for (final id in ids) {
      if (seen.add(id)) {
        unique.add(id);
      }
    }
    if (unique.length <= 1) return route;

    final query = Map<String, String>.from(uri.queryParameters);
    query['ids'] = unique.join(',');
    return uri.replace(queryParameters: query).toString();
  }

  Future<void> _openRouteFromMessage(String route) async {
    final targetRoute = await _withChatFeedContext(route);
    if (!mounted) return;

    final uri = Uri.tryParse(targetRoute);
    if (uri != null && uri.path.startsWith('/feed/')) {
      await _openFeedRouteInDialog(uri);
      return;
    }

    context.go(targetRoute);
  }

  Future<void> _openFeedRouteInDialog(Uri uri) async {
    final routeVideoId = uri.pathSegments.length > 1 ? uri.pathSegments[1] : '';
    if (routeVideoId.isEmpty) return;

    final queryIds = (uri.queryParameters['ids'] ?? '')
        .split(',')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    final orderedIds = <String>[routeVideoId, ...queryIds];

    final uniqueIds = <String>[];
    final seen = <String>{};
    for (final id in orderedIds) {
      if (seen.add(id)) {
        uniqueIds.add(id);
      }
    }

    List<Video> videos = [];
    if (uniqueIds.isNotEmpty) {
      final fetched = await videoRepo.fetchVideosByIds(uniqueIds);
      final byId = {for (final video in fetched) video.id: video};
      videos = [for (final id in uniqueIds) if (byId[id] != null) byId[id]!];
    }

    if (videos.isEmpty) {
      final single = await videoRepo.getVideoByIdSupabase(routeVideoId);
      if (single == null || !mounted) return;
      videos = [single];
    }

    if (!mounted) return;
    final index = videos.indexWhere((video) => video.id == routeVideoId);
    final dialogFeedModel = FeedViewModel();
    try {
      await openVideoPlayer(
        context: context,
        listedVideos: videos,
        videoIndex: index >= 0 ? index : 0,
        feedModel: dialogFeedModel,
        tickerProvider: this,
      );
    } finally {
      Future.delayed(const Duration(milliseconds: 350), () {
        dialogFeedModel.dispose();
      });
    }
  }

  bool preloading = false;

  Future<void> _loadHistoryPermission() async {
    try {
      final allowed = await widget.canViewMessageHistory();
      if (!mounted) return;
      setState(() => _canViewMessageHistory = allowed);
    } catch (_) {}
  }

  Future<void> _preloadMore({int limit = 30}) async {
    if (!moreMessagesAvailable || preloading) return;
    preloading = true;

    try {
      print("preloading!");
      final loadedMessages = await widget.loadMoreMessages(limit, currentMessageCursor);
      if (!mounted) return;

      if (loadedMessages.isEmpty) {
        moreMessagesAvailable = false;
        return;
      } else if (loadedMessages.length < limit) {
        moreMessagesAvailable = false;
      }

      loadedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _addMessages(loadedMessages, appendToEnd: false, isNewMessage: false);
      currentMessageCursor = loadedMessages.last.timestamp;
    } catch (e) {
      debugPrint('preload messages failed: $e');
    } finally {
      preloading = false;
    }
  }

  void onReceiveMessage(String text) {
    setState(() {
      _addMessage(text: text, isMe: false);
      if (_partnerTyping) {
        _partnerTyping = false;
      }
    });
  }

  void setPartnerTyping(bool typing) {
    setState(() => _partnerTyping = typing);
    if (typing) _scrollToBottom();
  }

  void _createBubbleController({bool animate = true}) {
    final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _bubbleControllers.add(ctrl);
    if (animate) {
      ctrl.forward();
    } else {
      ctrl.animateTo(1, duration: Duration.zero);
    }
  }

  void _addMessage({
    required String text,
    required bool isMe,
    Future<void>? sendingFuture,
    bool animated = true,
    bool appendToEnd = true,
    bool isNewMessage = true,
    DateTime? createdAt,
    String? id,
  }) {
    if (!mounted) return;
    if (isNewMessage) {
      widget.onMessageUpdate(
        ChatMessage(
          id: getChatId(receiverId: widget.recipientId),
          text: text,
          isMe: isMe,
          timestamp: createdAt ?? DateTime.now(),
        ),
      );
    }
    final msg = ChatMessage(
      id: id ?? (createdAt ?? DateTime.now()).millisecondsSinceEpoch.toString(),
      text: text,
      isMe: isMe,
      timestamp: createdAt ?? DateTime.now(),
      status: isMe ? MessageStatus.sending : MessageStatus.delivered,
    );
    setState(() {
      if (appendToEnd) {
        _messages.add(msg);
      } else {
        _messages.insert(0, msg);
      }
    });
    _sharedFeedVideoIds = null;
    _createBubbleController(animate: animated);
    _scrollToBottom();

    if (isMe) {
      if (sendingFuture == null) setState(() => msg.status = MessageStatus.sent);
      sendingFuture
          ?.then((val) {
            if (mounted) {
              setState(() => msg.status = MessageStatus.delivered);
            }
          })
          .catchError((e) {
            if (mounted) {
              setState(() => msg.status = MessageStatus.sent);
            }
            debugPrint('send message failed: $e');
          });
    }
  }

  void _addMessages(List<ChatMessage> messages, {bool appendToEnd = true, bool isNewMessage = true}) {
    if (!mounted) return;
    if (messages.isEmpty) return;

    final newMessages = messages
        .map(
          (element) => ChatMessage(
            id: element.id,
            text: element.text,
            isMe: element.isMe,
            timestamp: element.timestamp,
            status: element.isMe ? MessageStatus.sent : MessageStatus.delivered,
            editedAt: element.editedAt,
            deletedAt: element.deletedAt,
          ),
        )
        .toList();

    if (isNewMessage) {
      for (final m in newMessages) {
        widget.onMessageUpdate(m);
      }
    }

    setState(() {
      if (appendToEnd) {
        _messages.addAll(newMessages);
      } else {
        _messages.insertAll(0, newMessages);
      }
    });
    _sharedFeedVideoIds = null;

    for (var i = 0; i < newMessages.length; i++) {
      _createBubbleController(animate: false);
      
      print("added message ${newMessages[i].text} with timestamp ${newMessages[i].timestamp}");
      
    }

    if (appendToEnd) {
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (_editingMessageId != null) {
      final index = _messages.indexWhere((m) => m.id == _editingMessageId);
      if (index == -1) {
        setState(() => _editingMessageId = null);
        return;
      }
      final original = _messages[index];
      if (text == original.text) {
        setState(() {
          _editingMessageId = null;
          _textController.clear();
        });
        return;
      }
      try {
        final updated = await widget.onEditMessage(original, text);
        if (!mounted) return;
        setState(() {
          _messages[index] = ChatMessage(
            id: updated.id,
            text: updated.text,
            isMe: updated.isMe,
            timestamp: updated.timestamp,
            status: original.status,
            editedAt: updated.editedAt,
            deletedAt: updated.deletedAt,
          );
          _editingMessageId = null;
          _textController.clear();
        });
        widget.onMessageUpdate(updated);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to edit message: $e')));
      }
      return;
    }

    HapticFeedback.lightImpact();
    _textController.clear();
    Future<void> sendingFuture = widget.onSend(text);
    _addMessage(text: text, isMe: true, sendingFuture: sendingFuture, isNewMessage: true);
    return sendingFuture;
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    try {
      await widget.onDeleteMessage(message);
      if (!mounted) return;
      setState(() => _messages.removeWhere((m) => m.id == message.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete message: $e')));
    }
  }

  Future<void> _showMessageHistory(ChatMessage message) async {
    if (!_canViewMessageHistory) return;
    try {
      final versions = await widget.onLoadMessageVersions(message);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Message edit history', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: versions.isEmpty
                      ? const Center(child: Text('No versions found'))
                      : ListView.builder(
                          itemCount: versions.length,
                          itemBuilder: (context, i) {
                            final version = versions[i];
                            return ListTile(
                              title: Text(version.content),
                              subtitle: Text('v${version.versionNo} • ${version.changeType} • ${version.editedAt.toLocal()}'),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load history: $e')));
    }
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    if (!message.isMe && !_canViewMessageHistory) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (message.isMe)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit message'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _editingMessageId = message.id;
                    _textController.text = message.text;
                    _textController.selection = TextSelection.collapsed(offset: _textController.text.length);
                  });
                  _focusNode.requestFocus();
                },
              ),
            if (message.isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Delete message', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(message);
                },
              ),
            if (_canViewMessageHistory)
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('View edit history'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showMessageHistory(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _isTyping) setState(() => _isTyping = hasText);
  }

  void _onScroll() {
    final atBottom = _scrollController.offset >= _scrollController.position.maxScrollExtent - 80;
    if (!atBottom && !_showScrollDown) {
      setState(() => _showScrollDown = true);
    } else if (atBottom && _showScrollDown) {
      setState(() => _showScrollDown = false);
    }
    final atTop = _scrollController.offset <= 30;
    if (atTop) {
      _preloadMore();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingDotController.dispose();
    for (final c in _bubbleControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: _buildAppBar(theme, cs),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(child: _buildMessageList(theme, cs)),
              if (_partnerTyping) _buildTypingIndicator(cs),
              _buildInputBar(theme, cs),
            ],
          ),
          // Scroll-to-bottom FAB
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            bottom: _showScrollDown ? 80 : -60,
            right: 16,
            child: _ScrollDownButton(onTap: _scrollToBottom, colorScheme: cs),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, ColorScheme cs) {
    return AppBar(
      backgroundColor: cs.surfaceContainer,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadiusGeometry.only(bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18)),
      ),
      scrolledUnderElevation: 0,
      toolbarHeight: kToolbarHeight,
      systemOverlayStyle: SystemUiOverlayStyle(statusBarBrightness: theme.brightness == Brightness.dark ? Brightness.dark : Brightness.light),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: cs.onSurface),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) {
              return ProfileScreen(
                initialProfile: widget.user,
                ownProfile: widget.user.id == currentUser.id,
                hasBackButton: true,
                initialFollowed: localSeenService.isFollowing(widget.user.id),
                onFollowChange: (bool followed) {},
              );
            },
          ),
        ),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
          child: Row(
            children: [
              _AvatarWidget(name: widget.recipientName ?? '', imageUrl: widget.recipientAvatarUrl, isOnline: widget.isOnline, radius: 18, colorScheme: cs),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.recipientName ?? '',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 15, color: cs.onSurface),
                  ),
                  Text(
                    widget.isOnline ? 'Active now' : 'Offline',
                    style: TextStyle(fontSize: 11, color: widget.isOnline ? cs.tertiary : cs.outline, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        Center(
          child: IconButton(
            icon: Icon(Icons.videocam_rounded, color: cs.onSurface),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return CallingApp(
                      name: widget.recipientName ?? "Unknown User",
                      profileImageUrl: widget.recipientAvatarUrl ?? createUserProfileImageUrl(widget.recipientName ?? ""),
                    );
                  },
                ),
              );
            },
          ),
        ),
        /*        IconButton(
          icon: Icon(Icons.info_outline_rounded, color: cs.onSurface),
          onPressed: () {},
        ),*/
      ],
    );
  }

  Widget _buildMessageList(ThemeData theme, ColorScheme cs) {
    return GestureDetector(
      onTap: () => _focusNode.unfocus(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _messages.length,
        itemBuilder: (ctx, i) {
          final msg = _messages[i];
          final prevMsg = i > 0 ? _messages[i - 1] : null;
          final nextMsg = i < _messages.length - 1 ? _messages[i + 1] : null;

          final showAvatar = !msg.isMe && (nextMsg == null || nextMsg.isMe || _isNewGroup(msg, nextMsg));
          final showTimestamp = nextMsg == null || msg.timestamp.difference(nextMsg.timestamp).abs() > const Duration(minutes: 10);

          final ctrl = i < _bubbleControllers.length ? _bubbleControllers[i] : AnimationController(vsync: this, value: 1.0);

          return _MessageBubble(
            key: ValueKey(msg.id),
            message: msg,
            showAvatar: showAvatar,
            showTimestamp: showTimestamp,
            isFirst: prevMsg == null || prevMsg.isMe != msg.isMe,
            isLast: nextMsg == null || nextMsg.isMe != msg.isMe,
            animationController: ctrl,
            colorScheme: cs,
            theme: theme,
            recipientName: widget.recipientName ?? '',
            recipientAvatarUrl: widget.recipientAvatarUrl,
            onLongPress: () => _showMessageActions(msg),
            onRouteTap: _openRouteFromMessage,
            previewFutureFor: _previewFutureFor,
          );
        },
      ),
    );
  }

  bool _isNewGroup(ChatMessage a, ChatMessage b) {
    return b.timestamp.difference(a.timestamp).abs() > const Duration(minutes: 5);
  }

  Widget _buildTypingIndicator(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(left: 56, bottom: 4, right: 80),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _TypingBubble(controller: _typingDotController, colorScheme: cs),
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme, ColorScheme cs) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : max(MediaQuery.of(context).padding.bottom, 12),
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3), width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_editingMessageId != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.secondaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 16, color: cs.onSecondaryContainer),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Editing message', style: TextStyle(color: cs.onSecondaryContainer, fontWeight: FontWeight.w600))),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _editingMessageId = null;
                        _textController.clear();
                      });
                    },
                    child: Icon(Icons.close_rounded, size: 18, color: cs.onSecondaryContainer),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _InputIconButton(icon: Icons.add_circle_outline_rounded, color: cs.onSurfaceVariant, onTap: () {}),
              const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(_isTyping ? 22 : 24),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: _isTyping ? 0.7 : 0.4), width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Focus(
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent &&
                                event.logicalKey == LogicalKeyboardKey.enter &&
                                !HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) &&
                                !HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight)) {
                              _sendMessage();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                            controller: _textController,
                            onSubmitted: (value) => _sendMessage(),
                            focusNode: _focusNode,
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: TextInputAction.newline,
                            style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.4),
                            decoration: InputDecoration(
                              hintText: _editingMessageId == null ? 'Message…' : 'Edit message…',
                              hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 15),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: _isTyping
                    ? _SendButton(key: const ValueKey('send'), onTap: _sendMessage, colorScheme: cs)
                    : _InputIconButton(key: const ValueKey('mic'), icon: Icons.mic_none_rounded, color: cs.onSurfaceVariant, onTap: () {}),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showAvatar;
  final bool showTimestamp;
  final bool isFirst;
  final bool isLast;
  final AnimationController animationController;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final String recipientName;
  final String? recipientAvatarUrl;
  final VoidCallback? onLongPress;
  final void Function(String route) onRouteTap;
  final Future<ChatRoutePreview?> Function(ChatRouteReference ref) previewFutureFor;

  const _MessageBubble({
    super.key,
    required this.message,
    required this.showAvatar,
    required this.showTimestamp,
    required this.isFirst,
    required this.isLast,
    required this.animationController,
    required this.colorScheme,
    required this.theme,
    required this.recipientName,
    this.recipientAvatarUrl,
    this.onLongPress,
    required this.onRouteTap,
    required this.previewFutureFor,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final cs = colorScheme;

    final slide = Tween<Offset>(
      begin: Offset(isMe ? 0.3 : -0.3, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animationController, curve: Curves.easeOutCubic));
    return SlideMorphTransitions.build(
      animationController,
      SlideTransition(
        position: slide,
        child: Padding(
          padding: EdgeInsets.only(top: isFirst ? 8 : 2, bottom: isLast ? 6 : 2),
          child: Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                SizedBox(
                  width: 32,
                  child: showAvatar
                      ? _AvatarWidget(name: recipientName, imageUrl: recipientAvatarUrl, isOnline: false, radius: 14, colorScheme: cs)
                      : const SizedBox(),
                ),
                const SizedBox(width: 6),
              ],

              Flexible(
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    _BubbleBody(
                      message: message,
                      isMe: isMe,
                      isFirst: isFirst,
                      isLast: isLast,
                      colorScheme: cs,
                      onLongPress: onLongPress,
                      onRouteTap: onRouteTap,
                      previewFutureFor: previewFutureFor,
                    ),
                    if (showTimestamp || (isMe && isLast))
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4, right: 4, bottom: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_formatTime(message.timestamp), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
                            if (isMe) ...[const SizedBox(width: 3), _StatusIcon(status: message.status, colorScheme: cs)],
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              if (isMe) const SizedBox(width: 4),
            ],
          ),
        ),
      ),
      beginOffset: Offset(isMe ? 0.08 : -0.08, 0.06),
      beginScale: 0.97,
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _BubbleBody extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isFirst;
  final bool isLast;
  final ColorScheme colorScheme;
  final VoidCallback? onLongPress;
  final void Function(String route) onRouteTap;
  final Future<ChatRoutePreview?> Function(ChatRouteReference ref) previewFutureFor;

  const _BubbleBody({
    required this.message,
    required this.isMe,
    required this.isFirst,
    required this.isLast,
    required this.colorScheme,
    this.onLongPress,
    required this.onRouteTap,
    required this.previewFutureFor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;

    const r = Radius.circular(18);
    const rSmall = Radius.circular(4);

    BorderRadius borderRadius;
    if (isMe) {
      borderRadius = BorderRadius.only(topLeft: r, topRight: isFirst ? r : rSmall, bottomLeft: r, bottomRight: isLast ? const Radius.circular(4) : rSmall);
    } else {
      borderRadius = BorderRadius.only(topLeft: isFirst ? r : rSmall, topRight: r, bottomLeft: isLast ? const Radius.circular(4) : rSmall, bottomRight: r);
    }

    final hasText = ChatRoutePreviewResolver.hasVisibleText(message.text) || message.isEdited;

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onLongPress?.call();
      },
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (hasText)
            Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? cs.primary : cs.secondary,
                borderRadius: borderRadius,
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LinkedSelectableText(
                    text: message.text,
                    textColor: isMe ? cs.onPrimary : cs.onSecondary,
                    linkColor: isMe ? cs.onPrimary.withValues(alpha: 0.9) : cs.primary,
                    onRouteTap: onRouteTap,
                  ),
                  if (message.isEdited)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'edited',
                        style: TextStyle(
                          color: (isMe ? cs.onPrimary : cs.onSecondary).withValues(alpha: 0.7),
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          _RoutePreviewList(messageText: message.text, onRouteTap: onRouteTap, previewFutureFor: previewFutureFor),
        ],
      ),
    );
  }
}

class _LinkedSelectableText extends StatefulWidget {
  final String text;
  final Color textColor;
  final Color linkColor;
  final void Function(String route) onRouteTap;

  const _LinkedSelectableText({
    required this.text,
    required this.textColor,
    required this.linkColor,
    required this.onRouteTap,
  });

  @override
  State<_LinkedSelectableText> createState() => _LinkedSelectableTextState();
}

class _LinkedSelectableTextState extends State<_LinkedSelectableText> {
  final List<TapGestureRecognizer> _recognizers = [];
  List<InlineSpan> _spans = const [];
  static final RegExp _routeRegex = RegExp(r'(?<!\S)(\/[^\s]+)');

  @override
  void initState() {
    super.initState();
    _rebuildSpans();
  }

  @override
  void didUpdateWidget(covariant _LinkedSelectableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.textColor != widget.textColor || oldWidget.linkColor != widget.linkColor) {
      _rebuildSpans();
    }
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  void _rebuildSpans() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final spans = <InlineSpan>[];
    final text = widget.text;
    int cursor = 0;
    for (final match in _routeRegex.allMatches(text)) {
      final start = match.start;
      final end = match.end;
      final route = match.group(1) ?? '';
      if (cursor < start) {
        spans.add(TextSpan(text: text.substring(cursor, start), style: TextStyle(color: widget.textColor, fontSize: 15, height: 1.4)));
      }
      if (ChatRoutePreviewResolver.isRoutableToken(route)) {
        // Skip it. We don't render routable tokens as text anymore.
      } else {
        spans.add(TextSpan(text: route, style: TextStyle(color: widget.textColor, fontSize: 15, height: 1.4)));
      }
      cursor = end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: TextStyle(color: widget.textColor, fontSize: 15, height: 1.4)));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: TextStyle(color: widget.textColor, fontSize: 15, height: 1.4)));
    }

    setState(() {
      _spans = spans;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(TextSpan(children: _spans), selectionColor: Theme.of(context).colorScheme.tertiary);
  }
}

class _RoutePreviewList extends StatelessWidget {
  final String messageText;
  final void Function(String route) onRouteTap;
  final Future<ChatRoutePreview?> Function(ChatRouteReference ref) previewFutureFor;

  const _RoutePreviewList({required this.messageText, required this.onRouteTap, required this.previewFutureFor});

  @override
  Widget build(BuildContext context) {
    final refs = ChatRoutePreviewResolver.extract(messageText);
    if (refs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          children: refs
              .map(
                (ref) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: FutureBuilder<ChatRoutePreview?>(
                    future: previewFutureFor(ref),
                    builder: (context, snapshot) {
                      final preview = snapshot.data;
                      if (snapshot.connectionState != ConnectionState.done) {
                        return Container(
                          height: 64,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        );
                      }
                      if (preview == null) return const SizedBox.shrink();
                      return _RoutePreviewCard(preview: preview, onTap: () => onRouteTap(preview.route));
                    },
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _RoutePreviewCard extends StatelessWidget {
  final ChatRoutePreview preview;
  final VoidCallback onTap;

  const _RoutePreviewCard({required this.preview, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = switch (preview.type) {
      ChatRoutePreviewType.feed => Icons.play_circle_fill_rounded,
      ChatRoutePreviewType.quests => Icons.map_outlined,
      ChatRoutePreviewType.chat => Icons.chat_bubble_outline_rounded,
      ChatRoutePreviewType.search => Icons.search_rounded,
      ChatRoutePreviewType.themes => Icons.palette_outlined,
    };

    if (preview.type == ChatRoutePreviewType.feed && preview.thumbnailUrl != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                    child: CachedNetworkImage(
                      imageUrl: preview.thumbnailUrl!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(width: double.infinity, height: 200, color: cs.surfaceContainerHighest, child: Icon(icon, color: cs.onSurfaceVariant)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    if (preview.avatarUrl != null && preview.avatarUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: CircleAvatar(radius: 16, backgroundImage: CachedNetworkImageProvider(preview.avatarUrl!)),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(preview.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
                          const SizedBox(height: 2),
                          Text(preview.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            if (preview.thumbnailUrl != null && preview.thumbnailUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                child: CachedNetworkImage(
                  // Stable cached image prevents flashing while list items recycle.
                  imageUrl: preview.thumbnailUrl!,
                  width: 72,
                  height: 64,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(width: 72, height: 64, color: cs.surfaceContainerHighest, child: Icon(icon, color: cs.onSurfaceVariant)),
                ),
              )
            else
              Container(
                width: 56,
                height: 64,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                ),
                child: Icon(icon, color: cs.onSurfaceVariant),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(preview.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(preview.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            if (preview.avatarUrl != null && preview.avatarUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: CircleAvatar(radius: 12, backgroundImage: CachedNetworkImageProvider(preview.avatarUrl!)),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final MessageStatus status;
  final ColorScheme colorScheme;

  const _StatusIcon({required this.status, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)));
      case MessageStatus.sent:
        return Icon(Icons.check_rounded, size: 12, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5));
      case MessageStatus.delivered:
        return Icon(Icons.done_all_rounded, size: 12, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5));
      case MessageStatus.read:
        return Icon(Icons.done_all_rounded, size: 12, color: colorScheme.tertiary);
    }
  }
}

class _TypingBubble extends StatelessWidget {
  final AnimationController controller;
  final ColorScheme colorScheme;

  const _TypingBubble({required this.controller, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: controller,
            builder: (_, _) {
              final phase = (controller.value - i * 0.15).clamp(0.0, 1.0);
              final offset = sin(phase * 2 * pi) * 3.0;
              return Transform.translate(
                offset: Offset(0, -offset.abs()),
                child: Container(
                  width: 7,
                  height: 7,
                  margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                  decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.5), shape: BoxShape.circle),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class _AvatarWidget extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final bool isOnline;
  final double radius;
  final ColorScheme colorScheme;

  const _AvatarWidget({required this.name, required this.isOnline, required this.radius, required this.colorScheme, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Stack(
      children: [
        Avatar(imageUrl: imageUrl, name: name, colorScheme: colorScheme),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.55,
              height: radius * 0.55,
              decoration: BoxDecoration(
                color: cs.tertiary,
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _SendButton extends StatefulWidget {
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _SendButton({super.key, required this.onTap, required this.colorScheme});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120), lowerBound: 0.0, upperBound: 1.0);
    _scaleAnim = Tween(begin: 1.0, end: 0.88).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: cs.primary,
            shape: BoxShape.circle,
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
          ),
          child: Icon(Icons.send_rounded, color: cs.onPrimary, size: 20),
        ),
      ),
    );
  }
}

class _ScrollDownButton extends StatelessWidget {
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _ScrollDownButton({required this.onTap, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          shape: BoxShape.circle,
          border: Border.all(color: cs.outlineVariant, width: 1),
        ),
        child: Icon(Icons.keyboard_arrow_down_rounded, color: cs.onSurface, size: 20),
      ),
    );
  }
}

class _InputIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _InputIconButton({super.key, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(width: 36, height: 36, child: Icon(icon, color: color, size: 24)),
    );
  }
}
