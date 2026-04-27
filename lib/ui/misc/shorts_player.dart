import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/logic/video/video_provider.dart';
import 'package:wurp/ui/widgets/overlays/overlays.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../router/router.dart';

class YoutubeVideoContainer {
  final YoutubePlayerController controller;
  final Video video;
  YoutubeVideoContainer({required this.controller, required this.video});
}

class ShortsFeed extends StatefulWidget {
  const ShortsFeed({super.key, required this.videoProvider});

  final VideoProvider videoProvider;

  @override
  State<ShortsFeed> createState() => _ShortsFeedState();
}

class _ShortsFeedState extends State<ShortsFeed> {
  final PageController _pageController = PageController();

  final Map<int, YoutubeVideoContainer> _controllers = {};

  int _currentIndex = 0;

  YoutubePlayerController _createController(String videoId) {
    print("Creating YoutubePlayerController for video ID: $videoId");
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
        enableKeyboard: false,
        strictRelatedVideos: true,
      ),
    )..loadVideoById(videoId: videoId);
  }

  void _onPageChanged(int index) async {
    if (index == _currentIndex) return;

    _controllers[_currentIndex]?.controller.close();
    _controllers.remove(_currentIndex);

    await getControllerAt(index);
    _controllers[index]!.controller.playVideo();

    _currentIndex = index;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.controller.close();
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
      itemCount: 5000,
      physics: const PageScrollPhysics(),
      itemBuilder: (context, index) {
        return FutureBuilder(
          future: getControllerAt(index),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.error != null && snapshot.error is VideoNotFoundException) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.video_library_outlined, size: 80, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(height: 20),
                      Text('No More Videos', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(
                        'You have seen all available videos! check again tomorrow!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(onPressed: () => routerConfig.go('/search'), child: const Text('Explore videos')),
                    ],
                  ),
                ),
              );
            } else if(snapshot.error != null) {
              print("Error loading video at index $index: ${snapshot.error}, stack trace: ${snapshot.stackTrace}");
              return Center(child: Text('Error loading video: ${snapshot.error}'));
            }
            print("Building ShortVideoPage for index $index with video ID: ${snapshot.data?.metadata.videoId}");
            return ShortVideoPage(controller: _controllers[index]!.controller, video: _controllers[index]!.video, index: index,);
          },
        );
      },
    );
  }

  Future<YoutubePlayerController> getControllerAt(int index) async {
    if (_controllers.containsKey(index)) {
      return _controllers[index]!.controller;
    } else {
      final video = await widget.videoProvider.getVideoByIndex(index, useYoutubeVideos: true);

      if (video == null) {
        throw VideoNotFoundException(index);
      }
      
      print("Fetched video for index $index: ${video.videoUrl}");

      final controller = _createController(YoutubePlayerController.convertUrlToId(video.videoUrl)!);
      _controllers[index] = YoutubeVideoContainer(controller: controller, video: video);
      return controller;
    }
  }
}

class ShortVideoPage extends StatefulWidget {
  final YoutubePlayerController controller;
  final String? thumbnailUrl;
  final Video video;
  final int index;

  const ShortVideoPage({super.key, required this.controller, this.thumbnailUrl, required this.video, required this.index});

  @override
  State<ShortVideoPage> createState() => _ShortVideoPageState();
}

class _ShortVideoPageState extends State<ShortVideoPage> with SingleTickerProviderStateMixin {
  bool _startedPlaying = false;

  @override
  void initState() {
    super.initState();

    widget.controller.listen((event) {
      if (event.playerState == PlayerState.playing && !_startedPlaying && mounted) {
        setState(() {
          _startedPlaying = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget out = Center(
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _startedPlaying ? 1.0 : 0.1,
                child: YoutubePlayer(controller: widget.controller, aspectRatio: 9 / 16),
              ),

              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _startedPlaying ? 0 : 0.99,
                child: CachedNetworkImage(imageUrl: widget.video.thumbnailUrl ?? 'https://img.youtube.com/vi/${YoutubePlayerController.convertUrlToId(widget.video.videoUrl)}/hqdefault.jpg', fit: BoxFit.cover),
              ),

              PointerInterceptor(child: const AspectRatio(aspectRatio: 9 / 16)),
              PageOverlay(
                provider: this,
                video: widget.video,
                index: widget.index,
                initiallyLiked: false,
                initiallyDisliked: false,
                onTogglePause: () {
                  if (widget.controller.value.playerState == PlayerState.playing) {
                    widget.controller.pauseVideo();
                  } else {
                    widget.controller.playVideo();
                  }
                },
                isPaused: widget.controller.value.playerState != PlayerState.playing,
              ),
            ],
          ),
        ),
      ),
    );
    print("Built ShortVideoPage for video ID: ${widget.controller.metadata.videoId}, startedPlaying: $_startedPlaying");
    return out;
  }
}

class VideoNotFoundException implements Exception {
  final int index;

  VideoNotFoundException(this.index);

  @override
  String toString() => "Video at index $index not found";
}
