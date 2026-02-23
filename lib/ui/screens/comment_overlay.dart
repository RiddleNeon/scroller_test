import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

import '../../logic/comments/comment.dart';


// ─────────────────────────────────────────────
//  Demo entry point
// ─────────────────────────────────────────────

void main() {
  runApp(const CommentsDemo());
}

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
  final List<Comment> _comments = [
    Comment(
      userId: '1',
      username: 'anna_k',
      userProfileImageUrl: 'https://api.dicebear.com/7.x/thumbs/png?seed=anna',
      message: 'Absolutely love this! 🔥',
      date: DateTime.now().subtract(const Duration(minutes: 12)),
    ),
    Comment(
      userId: '2',
      username: 'max_dev',
      userProfileImageUrl: 'https://api.dicebear.com/7.x/thumbs/png?seed=max',
      message: 'Clean design, great work 👌',
      date: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    Comment(
      userId: '3',
      username: 'sara.design',
      userProfileImageUrl: 'https://api.dicebear.com/7.x/thumbs/png?seed=sara',
      message: 'Could you share the source code? Would love to learn from this.',
      date: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  int _page = 1;

  Future<List<Comment>> _loadMore() async {
    // Simulate network request
    await Future.delayed(const Duration(seconds: 1));
    _page++;
    return List.generate(
      3,
          (i) => Comment(
        userId: 'user_$i',
        username: 'user_${_page}_$i',
        userProfileImageUrl:
        'https://api.dicebear.com/7.x/thumbs/png?seed=page${_page}_$i',
        message: 'Loaded comment #$i from page $_page 🗂️',
        date: DateTime.now().subtract(Duration(days: _page, hours: i)),
      ),
    );
  }

  void _openComments() {
    showCommentsOverlay(
      context: context,
      comments: _comments,
      currentUserId: 'me',
      currentUsername: 'you',
      currentUserProfileImageUrl: 'https://api.dicebear.com/7.x/thumbs/png?seed=you',
      onCommentAdded: (c) => setState(() => _comments.insert(0, c)),
      onLoadMore: _loadMore,
      totalCommentCount: 1000,
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
            const Text(
              'Comments Overlay Demo',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: const StadiumBorder(),
              ),
              onPressed: _openComments,
              icon: const Icon(Icons.comment_rounded),
              label: Text('${_comments.length} Comments'),
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
/// [onLoadMore] is called when the user scrolls to the bottom of the list.
/// Return a list of new comments to append, or an empty list if there are no
/// more comments. If null, pagination is disabled.
void showCommentsOverlay({
  required BuildContext context,
  required List<Comment> comments,
  required String currentUserId,
  required String currentUsername,
  required String currentUserProfileImageUrl,
  required void Function(Comment) onCommentAdded,
  Future<List<Comment>> Function()? onLoadMore,
  int? totalCommentCount,
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
      totalCommentCount: totalCommentCount,
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
  /// Should return newly loaded comments to append, or [] when exhausted.
  final Future<List<Comment>> Function()? onLoadMore;
  final int? totalCommentCount;

  const CommentsOverlay({
    super.key,
    required this.comments,
    required this.currentUserId,
    required this.currentUsername,
    required this.currentUserProfileImageUrl,
    required this.onCommentAdded,
    this.onLoadMore, 
    this.totalCommentCount,
  });

  @override
  State<CommentsOverlay> createState() => _CommentsOverlayState();
}

class _CommentsOverlayState extends State<CommentsOverlay>
    with SingleTickerProviderStateMixin {
  late final List<Comment> _comments;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int ownCommentCount = 0;

  // ── Colours & Style ──────────────────────────────────────────
  static const _bgColor = Color(0xFF141414);
  static const _surfaceColor = Color(0xFF1E1E1E);
  static const _accentColor = Color(0xFF1DB954);
  static const _subtleText = Color(0xFF888888);
  static const _dividerColor = Color(0xFF2A2A2A);

  @override
  void initState() {
    super.initState();
    _comments = List.from(widget.comments);
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

  // ─────────────────────────────────────────────────────────────
  //  Pagination
  // ─────────────────────────────────────────────────────────────

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // Trigger when within 120px of the bottom
    if (pos.pixels >= pos.maxScrollExtent - 120) {
      _loadMoreComments();
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore || !_hasMore || widget.onLoadMore == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final newComments = await widget.onLoadMore!();
      if (!mounted) return;
      setState(() {
        if (newComments.isEmpty) {
          _hasMore = false;
        } else {
          _comments.addAll(newComments);
        }
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Helpers
  // ─────────────────────────────────────────────────────────────

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.day}.${date.month}.${date.year}';
  }

  Future<void> _sendComment() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() => _isSending = true);

    // Simulate slight async delay (e.g. network call)
    await Future.delayed(const Duration(milliseconds: 200));

    final newComment = Comment(
      userId: widget.currentUserId,
      username: widget.currentUsername,
      userProfileImageUrl: widget.currentUserProfileImageUrl,
      message: text,
      date: DateTime.now(),
    );

    setState(() {
      _comments.insert(0, newComment);
      ownCommentCount++;
      _isSending = false;
    });

    _textController.clear();
    widget.onCommentAdded(newComment);

    // Scroll to top to reveal new comment
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
          height: MediaQuery.of(context).size.height * 0.75,
          color: _bgColor,
          child: Column(
            children: [
              _buildHeader(),
              const Divider(color: _dividerColor, height: 1),
              Expanded(child: _buildCommentList()),
              const Divider(color: _dividerColor, height: 1),
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
          // Drag handle
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
                  '${widget.totalCommentCount != null ? (widget.totalCommentCount! + ownCommentCount) : _comments.length} Comments',
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

  // ── List ──────────────────────────────────────────────────────

  Widget _buildCommentList() {
    if (_comments.isEmpty) {
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

    // +1 for the footer (loading spinner or "end" indicator)
    final hasFooter = widget.onLoadMore != null;
    final itemCount = _comments.length + (hasFooter ? 1 : 0);

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      separatorBuilder: (_, i) {
        if (i >= _comments.length - 1) return const SizedBox.shrink();
        return const Divider(color: _dividerColor, height: 1, indent: 68);
      },
      itemBuilder: (_, i) {
        // Footer
        if (i == _comments.length) {
          return _buildLoadMoreFooter();
        }
        return _CommentTile(
          comment: _comments[i],
          timeAgo: _timeAgo(_comments[i].date),
          isOwn: _comments[i].userId == widget.currentUserId,
        );
      },
    );
  }

  Widget _buildLoadMoreFooter() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _accentColor,
            ),
          ),
        ),
      );
    }
    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            '— no more comments —',
            style: TextStyle(color: _subtleText, fontSize: 12),
          ),
        ),
      );
    }
    return const SizedBox(height: 8);
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
                decoration: const InputDecoration(
                  hintText: 'Write a comment…',
                  hintStyle: TextStyle(color: _subtleText, fontSize: 15),
                  contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        strokeWidth: 2, color: Colors.black),
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
  final Comment comment;
  final String timeAgo;
  final bool isOwn;

  const _CommentTile({
    required this.comment,
    required this.timeAgo,
    required this.isOwn,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(url: comment.userProfileImageUrl, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.username,
                      style: TextStyle(
                        color: isOwn
                            ? const Color(0xFF1DB954)
                            : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    if (isOwn)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text('· you',
                            style: TextStyle(
                                color: Color(0xFF888888), fontSize: 12)),
                      ),
                    const Spacer(),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                          color: Color(0xFF888888), fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.message,
                  style: const TextStyle(
                      color: Color(0xFFE0E0E0),
                      fontSize: 14.5,
                      height: 1.45),
                ),
              ],
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

  /// Generates a consistent color from the URL string so every
  /// fallback avatar has a unique but stable tint.
  Color _colorFromUrl(String url) {
    final colors = [
      const Color(0xFF1DB954),
      const Color(0xFF3B82F6),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
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