import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class ShortVideo {
  final String id;

  ShortVideo(this.id);
}

class ShortsFeed extends StatefulWidget {
  const ShortsFeed({super.key});

  @override
  State<ShortsFeed> createState() => _ShortsFeedState();
}

class _ShortsFeedState extends State<ShortsFeed> {
  final PageController _pageController = PageController();

  final videos = [ShortVideo('YDDHUQYh1yw'), ShortVideo('dQw4w9WgXcQ'), ShortVideo('3JZ_D3ELwOQ')];

  final Map<int, YoutubePlayerController> _controllers = {};

  int _currentIndex = 0;

  YoutubePlayerController _createController(String videoId) {
    return YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(showControls: false, showFullscreenButton: false, mute: false, loop: true, playsInline: true, pointerEvents: .none, enableCaption: false),
    )..loadVideoById(videoId: videoId);
  }

  void _onPageChanged(int index) {
    _controllers[_currentIndex]?.close();
    _controllers.remove(_currentIndex);

    _controllers[index] ??= _createController(videos[index].id);
    _controllers[index]!.playVideo();

    _currentIndex = index;
  }

  @override
  void initState() {
    super.initState();

    // preload first video
    _controllers[0] = _createController(videos[0].id);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: videos.length,
      itemBuilder: (context, index) {
        _controllers[index] ??= _createController(videos[index].id);

        return ShortVideoPage(controller: _controllers[index]!);
      },
    );
  }
}

class ShortVideoPage extends StatelessWidget {
  final YoutubePlayerController controller;

  const ShortVideoPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(child: YoutubePlayer(gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{}, controller: controller, aspectRatio: 9 / 16)),
        Center(child: PointerInterceptor(child: const AspectRatio(aspectRatio: 9 / 16))),

        // tap overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: () async {
              print("tapped video, checking state...");
              final state = await controller.playerState;
              if (state == PlayerState.playing) {
                controller.pauseVideo();
              } else {
                controller.playVideo();
              }
            },
          ),
        ),
      ],
    );
  }
}
