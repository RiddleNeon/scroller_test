/*
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';

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
    _controller = 
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
        return BetterPlayer(controller: _controller!);
      },
    );
  }
}
*/
