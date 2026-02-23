import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

import '../../logic/comments/comment.dart';

// ─────────────────────────────────────────────
//  Tree builder
//
//  Converts a flat list (as you'd get from a Firestore query) into a
//  tree by nesting each comment under its parent's replies list.
//  Top-level comments (parentId == null) are returned; all others are
//  attached as children of their parent.
// ─────────────────────────────────────────────

List<Comment> buildCommentTree(List<Comment> flat) {
  // Clear any stale replies from a previous build
  for (final c in flat) {
    c.replies = [];
  }
  final Map<String, Comment> byId = {for (final c in flat) c.id: c};
  final List<Comment> roots = [];

  for (final c in flat) {
    if (c.parentId == null) {
      roots.add(c);
    } else {
      byId[c.parentId]?.replies.add(c);
    }
  }
  return roots;
}

// ─────────────────────────────────────────────
//  View-Model (mutable UI state per comment)
// ─────────────────────────────────────────────

class _CommentVM {
  final Comment comment;
  bool likedByMe;
  int likeCount;
  bool showReplies;

  /// Child VMs – mirrors comment.replies but holds UI state.
  /// Built recursively by [_CommentsOverlayState._toVM].
  final List<_CommentVM> replies;

  _CommentVM({
    required this.comment,
    this.likedByMe = false,
    bool? showReplies,
    List<_CommentVM>? replies,
  })  : likeCount = comment.likeCount,
        showReplies = showReplies ?? false,
        replies = replies ?? [];
}

// ─────────────────────────────────────────────
//  Demo entry point
// ─────────────────────────────────────────────

void main() => runApp(const CommentsDemo());

class CommentsDemo extends StatelessWidget {
  const CommentsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const _DemoPage(),
    );
  }
}

class _DemoPage extends StatefulWidget {
  const _DemoPage();

  @override
  State<_DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<_DemoPage> {
  // Flat list – exactly as you'd store/load from Firestore.
  // buildCommentTree() wires up the .replies on first open.
  final List<Comment> _flat = [
    Comment(
      id: 'c1',
      userId: '1',
      username: 'anna_k',
      userProfileImageUrl: 'https://api.dicebear.com/7.x/thumbs/png?seed=anna',
      message: 'Absolutely love this! 🔥',
      date: DateTime.now().subtract(const Duration(minutes: 12)),
      likeCount: 5,
      parentId: null,
      depth: 0,
    ),
    Comment(
      id: 'c2',
      userId: '2',
      username: 'max_dev',
      userProfileImageUrl: 'https://api.dicebear.com/7.x/thumbs/png?seed=max',
      message: 'Totally agree! 👍',
      date: DateTime.now().subtract(const Duration(minutes: 8)),
      likeCount: 2,
      parentId: 'c1',
      depth: 1,
    ),
    Comment(
      id: 'c3',
      userId: '3',
      username: 'sara.design',
      userProfileImageUrl: 'https://api.dicebear.com/7.x/thumbs/png?seed=sara',
      message: 'Me too, deeply nested reply here!',
      date: DateTime.now().subtract(const Duration(minutes: 4)),
      likeCount: 0,
      parentId: 'c2',
      depth: 2,
    ),
    Comment(
      id: 'c4',
      userId: '2',
      username: 'max_dev',
      userProfileImageUrl: 'https://api.dicebear.com/7.x/thumbs/png?seed=max',
      message: 'Clean design, great work 👌',
      date: DateTime.now().subtract(const Duration(hours: 1)),
      likeCount: 3,
      parentId: null,
      depth: 0,
    ),
    Comment(
      id: 'c5',
      userId: '3',
      username: 'sara.design',
      userProfileImageUrl: 'https://api.dicebear.com/7.x/thumbs/png?seed=sara',
      message: 'Could you share the source code? Would love to learn from this.',
      date: DateTime.now().subtract(const Duration(hours: 3)),
      likeCount: 1,
      parentId: null,
      depth: 0,
    ),
  ];

  int _page = 1;

  Future<List<Comment>> _loadMore() async {
    await Future.delayed(const Duration(seconds: 1));
    _page++;
    if (_page > 4) return [];
    return List.generate(
      3,
          (i) => Comment(
        id: 'page${_page}_$i',
        userId: 'user_p${_page}_$i',
        username: 'user_${_page}_$i',
        userProfileImageUrl:
        'https://api.dicebear.com/7.x/thumbs/png?seed=page${_page}_$i',
        message: 'Comment #$i from page $_page 🗂️',
        date: DateTime.now().subtract(Duration(days: _page, hours: i)),
        likeCount: 0,
        parentId: null,
        depth: 0,
      ),
    );
  }

  void _openComments() {
    showCommentsOverlay(
      context: context,
      // Pass the flat list – the overlay calls buildCommentTree internally.
      comments: _flat,
      currentUserId: 'me',
      currentUsername: 'you',
      currentUserProfileImageUrl:
      'https://api.dicebear.com/7.x/thumbs/png?seed=you',
      // Called for every new comment (top-level AND replies).
      // Add it to the flat list so the tree stays in sync.
      onCommentAdded: (c) => setState(() => _flat.add(c)),
      onLoadMore: _loadMore,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Comments Overlay Demo',
                style: TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.black,
                padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: const StadiumBorder(),
              ),
              onPressed: _openComments,
              icon: const Icon(Icons.comment_rounded),
              label: Text('${_flat.where((c) => c.parentId == null).length} Comments'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Public API
// ─────────────────────────────────────────────

/// Shows the comments overlay as a modal bottom sheet.
///
/// [comments]       – flat list of all comments for this post (top-level +
///                    replies). Pass the raw Firestore result; the overlay
///                    calls [buildCommentTree] internally.
/// [onCommentAdded] – fired for every new comment or reply the user submits.
///                    The [Comment] already has [id], [parentId] and [depth]
///                    set – write it straight to Firestore and add it to your
///                    local flat list.
/// [onLoadMore]     – called when scrolled near the end; return [] when exhausted.
void showCommentsOverlay({
  required BuildContext context,
  required List<Comment> comments,
  required String currentUserId,
  required String currentUsername,
  required String currentUserProfileImageUrl,
  required void Function(Comment) onCommentAdded,
  Future<List<Comment>> Function()? onLoadMore,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (_) => CommentsOverlay(
      comments: comments,
      currentUserId: currentUserId,
      currentUsername: currentUsername,
      currentUserProfileImageUrl: currentUserProfileImageUrl,
      onCommentAdded: onCommentAdded,
      onLoadMore: onLoadMore,
    ),
  );
}

// ─────────────────────────────────────────────
//  Overlay Widget
// ─────────────────────────────────────────────

class CommentsOverlay extends StatefulWidget {
  final List<Comment> comments;
  final String currentUserId;
  final String currentUsername;
  final String currentUserProfileImageUrl;
  final void Function(Comment) onCommentAdded;

  /// Called when the user scrolls near the end of the list.
  /// Return [] to signal no more comments.
  final Future<List<Comment>> Function()? onLoadMore;

  const CommentsOverlay({
    super.key,
    required this.comments,
    required this.currentUserId,
    required this.currentUsername,
    required this.currentUserProfileImageUrl,
    required this.onCommentAdded,
    this.onLoadMore,
  });

  @override
  State<CommentsOverlay> createState() => _CommentsOverlayState();
}

class _CommentsOverlayState extends State<CommentsOverlay> {
  late final List<_CommentVM> _vms;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isSending = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  /// When non-null the input bar is in "reply" mode for this VM.
  _CommentVM? _replyTarget;

  // ── Palette ──────────────────────────────────────────────────
  static const _bgColor = Color(0xFF141414);
  static const _surfaceColor = Color(0xFF1E1E1E);
  static const _accentColor = Color(0xFF1DB954);
  static const _subtleText = Color(0xFF888888);
  static const _dividerColor = Color(0xFF2A2A2A);
  static const _likedColor = Color(0xFFFF4D6D);

  // Maximum visual indent levels – deeper replies share the last indent level
  static const int _maxIndentDepth = 5;
  static const double _indentPerDepth = 20.0;

  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Build the tree from the flat list, then wrap each root in a VM.
    _vms = buildCommentTree(widget.comments).map(_toVM).toList();
    if (widget.onLoadMore != null) {
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Recursively converts a [Comment] (with its .replies already wired up
  /// by [buildCommentTree]) into a [_CommentVM].
  _CommentVM _toVM(Comment c) => _CommentVM(
    comment: c,
    replies: c.replies.map(_toVM).toList(),
  );

  // ── Pagination ────────────────────────────────────────────────

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 120) _loadMoreComments();
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore || !_hasMore || widget.onLoadMore == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final next = await widget.onLoadMore!();
      if (!mounted) return;
      setState(() {
        if (next.isEmpty) {
          _hasMore = false;
        } else {
          // Paginated results are always top-level comments
          _vms.addAll(next.map(_toVM));
        }
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // ── Sending ───────────────────────────────────────────────────

  Future<void> _sendComment() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() => _isSending = true);
    await Future.delayed(const Duration(milliseconds: 180));

    final target = _replyTarget;

    // Generate a simple unique ID. In production replace with:
    //   FirebaseFirestore.instance.collection('...').doc().id
    final newId =
        '${DateTime.now().millisecondsSinceEpoch}_${text.hashCode.abs()}';

    final newComment = Comment(
      id: newId,
      userId: widget.currentUserId,
      username: widget.currentUsername,
      userProfileImageUrl: widget.currentUserProfileImageUrl,
      message: text,
      date: DateTime.now(),
      likeCount: 0,
      parentId: target?.comment.id,
      depth: target != null ? target.comment.depth + 1 : 0,
    );

    final newVm = _toVM(newComment);

    setState(() {
      if (target != null) {
        // Attach to the VM tree so it renders immediately
        target.replies.insert(0, newVm);
        // Also keep the Comment model in sync (client-side tree)
        target.comment.replies.insert(0, newComment);
        target.showReplies = true;
      } else {
        _vms.insert(0, newVm);
      }
      // Single callback for both top-level and replies –
      // caller adds it to the flat list and writes to Firestore.
      widget.onCommentAdded(newComment);
      _replyTarget = null;
      _isSending = false;
    });

    _textController.clear();
    _focusNode.unfocus();

    if (target == null && _scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _startReply(_CommentVM vm) {
    setState(() => _replyTarget = vm);
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyTarget = null);
    _focusNode.unfocus();
  }

  void _toggleLike(_CommentVM vm) {
    HapticFeedback.selectionClick();
    setState(() {
      if (vm.likedByMe) {
        vm.likedByMe = false;
        vm.likeCount--;
      } else {
        vm.likedByMe = true;
        vm.likeCount++;
      }
    });
  }

  // ── Helpers ───────────────────────────────────────────────────

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.day}.${date.month}.${date.year}';
  }

  // ─────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.80,
          color: _bgColor,
          child: Column(
            children: [
              _buildHeader(),
              const Divider(color: _dividerColor, height: 1),
              Expanded(child: _buildList()),
              const Divider(color: _dividerColor, height: 1),
              if (_replyTarget != null) _buildReplyBanner(),
              _buildInputBar(bottomPadding),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  '${_vms.length} Comments',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: _subtleText),
          ),
        ],
      ),
    );
  }

  // ── Comment list ──────────────────────────────────────────────

  Widget _buildList() {
    if (_vms.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                color: _subtleText, size: 48),
            SizedBox(height: 12),
            Text(
              'No comments yet.\nBe the first!',
              textAlign: TextAlign.center,
              style: TextStyle(color: _subtleText, fontSize: 15, height: 1.5),
            ),
          ],
        ),
      );
    }

    final hasFooter = widget.onLoadMore != null;
    final count = _vms.length + (hasFooter ? 1 : 0);

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      itemCount: count,
      separatorBuilder: (_, i) {
        if (i >= _vms.length - 1) return const SizedBox.shrink();
        return const Divider(color: _dividerColor, height: 1, indent: 68);
      },
      itemBuilder: (_, i) {
        if (i == _vms.length) return _buildFooter();
        return _buildCommentBlock(_vms[i], depth: 0);
      },
    );
  }

  // ── Recursive comment block ────────────────────────────────────

  Widget _buildCommentBlock(_CommentVM vm, {required int depth}) {
    // Only indent for the first _maxIndentDepth levels; beyond that no extra indent.
    // Using a delta (not cumulative) so each recursive Padding adds exactly
    // _indentPerDepth px relative to its parent – and nothing beyond depth 5.
    final double deltaIndent =
    depth > 0 && depth <= _maxIndentDepth ? _indentPerDepth : 0.0;
    final bool isReply = depth > 0;

    return Padding(
      padding: EdgeInsets.only(left: deltaIndent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentTile(
            vm: vm,
            timeAgo: _timeAgo(vm.comment.date),
            isOwn: vm.comment.userId == widget.currentUserId,
            accentColor: _accentColor,
            likedColor: _likedColor,
            subtleText: _subtleText,
            isReply: isReply,
            depth: depth,
            onLike: () => _toggleLike(vm),
            onReply: () => _startReply(vm),
          ),
          // ── Replies toggle ──────────────────────────────────────
          if (vm.replies.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 52, bottom: 4),
              child: GestureDetector(
                onTap: () => setState(() => vm.showReplies = !vm.showReplies),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 1,
                      color: _subtleText,
                      margin: const EdgeInsets.only(right: 8),
                    ),
                    Text(
                      vm.showReplies
                          ? 'Hide replies'
                          : 'View ${vm.replies.length} repl${vm.replies.length == 1 ? 'y' : 'ies'}',
                      style: const TextStyle(
                        color: _subtleText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Recursive children ──────────────────────────────
            if (vm.showReplies)
              Column(
                children: vm.replies.map((reply) {
                  return Column(
                    children: [
                      const Divider(
                          color: _dividerColor, height: 1, indent: 16),
                      _buildCommentBlock(reply, depth: depth + 1),
                    ],
                  );
                }).toList(),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: _accentColor),
          ),
        ),
      );
    }
    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text('— no more comments —',
              style: TextStyle(color: _subtleText, fontSize: 12)),
        ),
      );
    }
    return const SizedBox(height: 8);
  }

  // ── Reply banner ──────────────────────────────────────────────

  Widget _buildReplyBanner() {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, size: 15, color: _accentColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Replying to @${_replyTarget!.comment.username}',
              style: const TextStyle(
                  color: _accentColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: _cancelReply,
            child:
            const Icon(Icons.close_rounded, size: 16, color: _subtleText),
          ),
        ],
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────

  Widget _buildInputBar(double bottomPadding) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomPadding),
      child: Row(
        children: [
          _Avatar(url: widget.currentUserProfileImageUrl, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendComment(),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: _replyTarget != null
                      ? 'Reply to @${_replyTarget!.comment.username}…'
                      : 'Write a comment…',
                  hintStyle:
                  const TextStyle(color: _subtleText, fontSize: 15),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedBuilder(
            animation: _textController,
            builder: (_, __) {
              final hasText = _textController.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: hasText && !_isSending ? _sendComment : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasText ? _accentColor : _surfaceColor,
                  ),
                  child: _isSending
                      ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                      : Icon(
                    Icons.arrow_upward_rounded,
                    color: hasText ? Colors.black : _subtleText,
                    size: 20,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Comment Tile
// ─────────────────────────────────────────────

class _CommentTile extends StatelessWidget {
  final _CommentVM vm;
  final String timeAgo;
  final bool isOwn;
  final bool isReply;
  final int depth;
  final Color accentColor;
  final Color likedColor;
  final Color subtleText;
  final VoidCallback onLike;
  final VoidCallback onReply;

  const _CommentTile({
    required this.vm,
    required this.timeAgo,
    required this.isOwn,
    required this.accentColor,
    required this.likedColor,
    required this.subtleText,
    required this.onLike,
    required this.onReply,
    this.isReply = false,
    this.depth = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Slightly shrink avatar and font the deeper the nesting
    final double avatarRadius = isReply ? (depth > 1 ? 13.0 : 16.0) : 20.0;
    final double fontSize = isReply ? (depth > 1 ? 12.5 : 13.5) : 14.5;
    final double nameFontSize = isReply ? (depth > 1 ? 11.5 : 12.5) : 13.5;

    return Padding(
      padding:
      EdgeInsets.fromLTRB(16, isReply ? 8 : 12, 16, isReply ? 8 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(url: vm.comment.userProfileImageUrl, radius: avatarRadius),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      vm.comment.username,
                      style: TextStyle(
                        color: isOwn ? accentColor : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: nameFontSize,
                      ),
                    ),
                    if (isOwn)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text('· you',
                            style:
                            TextStyle(color: subtleText, fontSize: 11)),
                      ),
                    const Spacer(),
                    Text(timeAgo,
                        style: TextStyle(color: subtleText, fontSize: 11.5)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  vm.comment.message,
                  style: TextStyle(
                    color: const Color(0xFFE0E0E0),
                    fontSize: fontSize,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                // Like + Reply row
                Row(
                  children: [
                    _LikeButton(
                      count: vm.likeCount,
                      liked: vm.likedByMe,
                      likedColor: likedColor,
                      subtleText: subtleText,
                      onTap: onLike,
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: onReply,
                      child: Row(
                        children: [
                          Icon(Icons.reply_rounded,
                              size: 15, color: subtleText),
                          const SizedBox(width: 4),
                          Text('Reply',
                              style: TextStyle(
                                  color: subtleText, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LikeButton extends StatefulWidget {
  final int count;
  final bool liked;
  final Color likedColor;
  final Color subtleText;
  final VoidCallback onTap;

  const _LikeButton({
    required this.count,
    required this.liked,
    required this.likedColor,
    required this.subtleText,
    required this.onTap,
  });

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    _ctrl.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.liked ? widget.likedColor : widget.subtleText;
    return GestureDetector(
      onTap: _handleTap,
      child: Row(
        children: [
          ScaleTransition(
            scale: _scale,
            child: Icon(
              widget.liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 15,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Text(
              widget.count > 0 ? '${widget.count}' : 'Like',
              key: ValueKey(widget.count),
              style: TextStyle(color: color, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Avatar helper
// ─────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String url;
  final double radius;

  const _Avatar({required this.url, required this.radius});

  Color _colorFromUrl(String url) {
    const colors = [
      Color(0xFF1DB954),
      Color(0xFF3B82F6),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
    ];
    return colors[url.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _colorFromUrl(url),
      child: ClipOval(
        child: Image.network(
          url,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.person_rounded,
            size: radius,
            color: Colors.white.withOpacity(0.9),
          ),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: radius * 0.8,
                height: radius * 0.8,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                      progress.expectedTotalBytes!
                      : null,
                  color: Colors.white54,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}