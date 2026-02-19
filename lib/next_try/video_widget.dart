import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wurp/next_try/video_feed_state.dart';
import 'package:wurp/next_try/video_info_overlay.dart';
import '../logic/video/video.dart';
import 'action_sidebar.dart';

class VideoPage extends StatefulWidget {
  final int index;
  const VideoPage({super.key, required this.index});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  // Cached locally – never read from Provider again after first load.
  // This breaks the Consumer rebuild chain entirely.
  VideoWithAuthor? _videoWithAuthor;
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;

  bool _showPlayIcon = false;
  bool _isPlaying = true;
  VideoFeedState? _feedState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenToSlot());
  }

  void _listenToSlot() {
    _feedState = context.read<VideoFeedState>();
    _syncFromState(_feedState!);
    _feedState!.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (!mounted) return;
    if (_videoWithAuthor != null && _controller != null) {
      _feedState?.removeListener(_onStateChanged);
      return;
    }
    _syncFromState(_feedState!);
  }

  void _syncFromState(VideoFeedState state) {
    final vwa = state.videoWithAuthorAt(widget.index);
    final ctrl = state.controllerAt(widget.index);
    final loading = state.isLoading(widget.index);
    final error = state.errorMessage(widget.index);

    if (vwa != null && ctrl != null) {
      if (mounted) {
        setState(() {
          _videoWithAuthor = vwa;
          _controller = ctrl;
          _loading = false;
          _error = null;
        });
      }
      // Stop listening – we have everything we need
      state.removeListener(_onStateChanged);
    } else if (!loading && error != null) {
      if (mounted) setState(() { _loading = false; _error = error; });
      state.removeListener(_onStateChanged);
    } else {
      if (mounted && !_loading) setState(() => _loading = true);
    }
    state.removeListener(_onStateChanged);
  }

  @override
  void dispose() {
    _feedState?.removeListener(_onStateChanged);
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    if (_isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() {
      _isPlaying = !_isPlaying;
      _showPlayIcon = true;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showPlayIcon = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _LoadingPlaceholder();
    if (_error != null) return _ErrorPlaceholder(message: _error!);

    final vwa = _videoWithAuthor!;
    final controller = _controller!;

    // No Consumer, no Provider.of – zero connection to VideoFeedState
    // from this point on. This widget only rebuilds on its own setState().
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Player – StatelessWidget with a stable controller reference,
          // BetterPlayer's internal notifyListeners stays fully contained.
          SizedBox.expand(
            child: _PlayerLayer(controller: controller),
          ),

          // Play/pause icon – only visible for 700ms after tap
          if (_showPlayIcon)
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.play_arrow : Icons.pause,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),

          // Info overlay – pure StatelessWidget, no animations here
          Positioned(
            left: 0,
            right: 80,
            bottom: 0,
            child: VideoInfoOverlay(videoWithAuthor: vwa),
          ),

          // Action sidebar – like/follow use callbacks into state,
          // but toggling only rebuilds VideoPage itself (setState on like/follow
          // should go through a local flag, not Provider, to avoid full rebuilds)
          Positioned(
            right: 8,
            bottom: 80,
            child: _LocalActionSidebar(
              videoWithAuthor: vwa,
              index: widget.index,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Player layer ─────────────────────────────────────────────────────────────
// Separate StatelessWidget so Flutter's element reconciliation never
// reconstructs the BetterPlayer surface on parent setState() calls.
class _PlayerLayer extends StatelessWidget {
  final VideoPlayerController controller;
  const _PlayerLayer({required this.controller});

  @override
  Widget build(BuildContext context) => VideoPlayer(controller);
}

// ─── Action sidebar with local like/follow state ──────────────────────────────
// Keeps its own isLiked/isFollowed booleans so toggling never bubbles up
// to VideoPage or any Provider – zero rebuild propagation.
class _LocalActionSidebar extends StatefulWidget {
  final VideoWithAuthor videoWithAuthor;
  final int index;

  const _LocalActionSidebar({
    required this.videoWithAuthor,
    required this.index,
  });

  @override
  State<_LocalActionSidebar> createState() => _LocalActionSidebarState();
}

class _LocalActionSidebarState extends State<_LocalActionSidebar> {
  late bool _isLiked;
  late bool _isFollowed;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.videoWithAuthor.isLiked;
    _isFollowed = widget.videoWithAuthor.isAuthorFollowed;
  }

  @override
  Widget build(BuildContext context) {
    return ActionSidebar(
      videoWithAuthor: VideoWithAuthor(
        video: widget.videoWithAuthor.video,
        author: widget.videoWithAuthor.author,
        isLiked: _isLiked,
        isAuthorFollowed: _isFollowed,
      ),
      onLike: () {
        setState(() => _isLiked = !_isLiked);
        context.read<VideoFeedState>().toggleLike(widget.index);
      },
      onFollow: () {
        setState(() => _isFollowed = !_isFollowed);
        context.read<VideoFeedState>().toggleFollow(widget.index);
      },
      onShare: () => context.read<VideoFeedState>().trackInteraction(
        index: widget.index,
        watchTime: 0,
        videoDuration: 0,
        shared: true,
      ),
    );
  }
}

// ─── Placeholders ─────────────────────────────────────────────────────────────
class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Colors.black,
    child: Center(
      child: CircularProgressIndicator(
        color: Color(0xFFFF0050),
        strokeWidth: 2,
      ),
    ),
  );
}

class _ErrorPlaceholder extends StatelessWidget {
  final String message;
  const _ErrorPlaceholder({required this.message});
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white54, size: 48),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}