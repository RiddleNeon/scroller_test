import 'package:cached_network_image/cached_network_image.dart';
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

        return ShortVideoPage(controller: _controllers[index]!);
      },
    );
  }
}

class ShortVideoPage extends StatefulWidget {
  final YoutubePlayerController controller;
  final String? thumbnailUrl;

  const ShortVideoPage({
    super.key,
    required this.controller,
    this.thumbnailUrl,
  });

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
    return Center(
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _startedPlaying ? 1.0 : 0.01,
                  child: YoutubePlayer(
                    controller: widget.controller,
                    aspectRatio: 9 / 16,
                  ),
                ),

                AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _startedPlaying ? 0.0 : 1.0,
                  child: CachedNetworkImage(
                    imageUrl: widget.thumbnailUrl ?? 'https://img.youtube.com/vi/${widget.controller.metadata.videoId}/hqdefault.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
                
                PointerInterceptor(child: const AspectRatio(aspectRatio: 9 / 16)),
              ],
            ),
          ),
        ),
    );
  }
}