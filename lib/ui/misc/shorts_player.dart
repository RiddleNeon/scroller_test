import 'package:cached_network_image/cached_network_image.dart';
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

  final videos = [
    ShortVideo('YDDHUQYh1yw'),
    ShortVideo('dQw4w9WgXcQ'),
    ShortVideo('3JZ_D3ELwOQ'),
    ShortVideo('YDDHUQYh1yw'),
    ShortVideo('dQw4w9WgXcQ'),
    ShortVideo('3JZ_D3ELwOQ'),
    ShortVideo('YDDHUQYh1yw'),
    ShortVideo('dQw4w9WgXcQ'),
    ShortVideo('3JZ_D3ELwOQ'),
  ];

  final Map<int, YoutubePlayerController> _controllers = {};

  int _currentIndex = 0;

  YoutubePlayerController _createController(String videoId) {
    return YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        mute: false,
        loop: true,
        playsInline: true,
        pointerEvents: .none,
        enableCaption: false,
      ),
    )..loadVideoById(videoId: videoId);
  }

  void _onPageChanged(int index) {
    if (index == _currentIndex) return;

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
      physics: const PageScrollPhysics(),
      itemBuilder: (context, index) {
        _controllers[index] ??= _createController(videos[index].id);

        return ShortVideoPage(controller: _controllers[index]!, videoId: videos[index].id);
      },
    );
  }
}

class ShortVideoPage extends StatefulWidget {
  final YoutubePlayerController controller;
  final String videoId;

  const ShortVideoPage({super.key, required this.controller, required this.videoId});

  @override
  State<ShortVideoPage> createState() => _ShortVideoPageState();
}

class _ShortVideoPageState extends State<ShortVideoPage> {
  bool _startedPlaying = false;

  @override
  void initState() {
    super.initState();

    widget.controller.listen((event) {
      if (event.playerState == PlayerState.playing && !_startedPlaying) {
        setState(() {
          _startedPlaying = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Opacity(
            opacity: _startedPlaying ? 1.0 : 0.01,
            child: YoutubePlayer(gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{}, controller: widget.controller, aspectRatio: 9 / 16),
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: _startedPlaying ? 0.0 : 1.0,
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.center,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: CachedNetworkImage(
                    imageUrl: 'https://img.youtube.com/vi/${widget.videoId}/hqdefault.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
        Center(
          child: PointerInterceptor(child: const AspectRatio(aspectRatio: 9 / 16)),
        ),

        // tap overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: () async {
              final state = await widget.controller.playerState;
              if (state == PlayerState.playing) {
                widget.controller.pauseVideo();
              } else {
                widget.controller.playVideo();
              }
            },
          ),
        ),
      ],
    );
  }
}
