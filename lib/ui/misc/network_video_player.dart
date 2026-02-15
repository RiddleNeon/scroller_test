import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class NetworkVideoPlayer extends StatefulWidget {
  final String url;
  final bool isActive;

  const NetworkVideoPlayer({
    super.key,
    required this.url,
    required this.isActive,
  });

  @override
  State<NetworkVideoPlayer> createState() => _NetworkVideoPlayerState();
}

class _NetworkVideoPlayerState extends State<NetworkVideoPlayer> {
  VideoPlayerController? _controller;
  Future<void>? _initFuture;

  @override
  void didUpdateWidget(covariant NetworkVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive && _controller == null) {
      _init();
    } else if (!widget.isActive && _controller != null) {
      _disposeController();
    }
  }

  void _init() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initFuture = _controller!.initialize().then((_) {
      _controller!
        ..setLooping(true)
        ..play();
      setState(() {});
    });
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _initFuture = null;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || _initFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder(
      future: _initFuture,
      builder: (_, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return VideoPlayer(_controller!);
      },
    );
  }
}
