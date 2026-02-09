import 'package:flutter/material.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:wurp/ui/misc/video_playing_manager.dart';

class VideoPlayer extends StatefulWidget {
  final int videoIndex;
  final String videoUrl;
  final bool isActive;
  final bool autoPlay;

  const VideoPlayer({
    super.key,
    required this.videoIndex,
    required this.videoUrl,
    required this.isActive,
    this.autoPlay = true,
  });

  @override
  State<VideoPlayer> createState() => VideoPlayerState();
}

class VideoPlayerState extends State<VideoPlayer> {
  bool _isInitialized = false;
  bool _wasActive = false;

  @override
  void initState() {
    super.initState();
    _wasActive = widget.isActive;
    VideoManager().registerVideo(widget.videoIndex, widget.videoUrl);

    VideoManager().addListener(_onControllerChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialization();
      if (widget.isActive && widget.autoPlay) {
        _playIfReady();
      }
    });
  }

  void _onControllerChanged() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkInitialization();
      }
    });
  }

  void _checkInitialization() {
    final controller = VideoManager().getPlayerForIndex(widget.videoIndex);
    if (controller != null) {
      final isReady = controller.isVideoInitialized() ?? false;
      if (isReady != _isInitialized) {
        setState(() {
          _isInitialized = isReady;
        });
      }
    }
  }

  void _playIfReady() {
    final controller = VideoManager().getPlayerForIndex(widget.videoIndex);
    if (controller != null && (controller.isVideoInitialized() ?? false)) {
      controller.play();
    }
  }

  @override
  void didUpdateWidget(VideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.videoIndex != oldWidget.videoIndex) {
      VideoManager().registerVideo(widget.videoIndex, widget.videoUrl);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkInitialization();
        }
      });
    }

    if (widget.isActive != _wasActive) {
      _wasActive = widget.isActive;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final controller = VideoManager().getPlayerForIndex(widget.videoIndex);
        if (controller == null) return;

        if (widget.isActive && widget.autoPlay) {
          controller.play();
        } else if (!widget.isActive) {
          controller.pause();
        }
      });
    }
  }

  void _togglePlayPause() {
    final controller = VideoManager().getPlayerForIndex(widget.videoIndex);
    if (controller == null) return;

    if (controller.isPlaying() ?? false) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = VideoManager().getPlayerForIndex(widget.videoIndex);

    if (controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: BetterPlayer(controller: controller, key: ValueKey('better_player_${widget.videoIndex}')),
              ),
            ),
            if (!_isInitialized)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ValueListenableBuilder<bool>(
              valueListenable: VideoManager().getPlayingNotifier(widget.videoIndex),
              builder: (context, isPlaying, child) {
                return Center(
                  child: AnimatedOpacity(
                    opacity: isPlaying ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(
                      Icons.play_arrow,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void setActive(bool active) {
    final controller = VideoManager().getPlayerForIndex(widget.videoIndex);
    if (controller == null) return;

    if (active && widget.autoPlay) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  @override
  void dispose() {
    VideoManager().removeListener(_onControllerChanged);
    super.dispose();
  }
}