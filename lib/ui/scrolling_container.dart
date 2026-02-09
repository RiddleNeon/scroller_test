import 'package:flutter/material.dart';
import 'package:tiktoklikescroller/tiktoklikescroller.dart';
import 'package:wurp/logic/video/video.dart';

import '../logic/video/video_provider.dart';
import 'misc/video_playing_manager.dart';
import 'misc/video_playing_widget.dart';

class ScrollingContainer extends StatefulWidget {
  static const List<Color> colors = [Colors.green, Colors.blue, Colors.cyan, Colors.red, Colors.purple];
  final RecommendationVideoProvider videoProvider;

  const ScrollingContainer({super.key, required this.videoProvider});

  @override
  State<ScrollingContainer> createState() => _ScrollingContainerState();
}

const videoUrl = "https://cdn.pixabay.com/video/2024/10/13/236256_large.mp4";

class _ScrollingContainerState extends State<ScrollingContainer> with TickerProviderStateMixin {
  late Controller _controller;
  bool _isResetting = false;

  int resets = 0;
  static const int refreshFrequency = 30;
  int _currentActiveIndex = 0;

  int get currentIndex => _controller.getScrollPosition() + resets * refreshFrequency;

  int translateIndex(int index) => index + resets * refreshFrequency;

  @override
  void initState() {
    super.initState();
    _controller = _buildController();
    _preloadInitialVideos();
  }

  @override
  void dispose() {
    _controller.disposeListeners();
    VideoManager().dispose();
    super.dispose();
  }

  void _preloadInitialVideos() async {
    final firstVideo = await getVideoByIndex(0);
    if (firstVideo != null) {
      VideoManager().initializeFirst(0, videoUrl);

      final secondVideo = await getVideoByIndex(1);
      if (secondVideo != null) {
        VideoManager().preloadNext(1, videoUrl);
      }
    }
  }

  void _handleVideoChange(int newIndex) async {
    final nextVideo = await getVideoByIndex(newIndex + 1);
    final nextUrl = nextVideo != null ? videoUrl : videoUrl;

    VideoManager().switchToIndex(newIndex, videoUrl, newIndex + 1, nextUrl);
    
  }

  @override
  Widget build(BuildContext context) {
    return TikTokStyleFullPageScroller(
      contentSize: refreshFrequency + 5,
      builder: (context, modIndex) {
        int index = translateIndex(modIndex % (refreshFrequency + 1));

        return FutureBuilder(
          future: getVideoByIndex(index),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: Text('Video not available'));
            }

            final isActive = index == _currentActiveIndex;

            return Center(
              child: VideoPlayer(
                key: ValueKey('video_$index'),
                videoIndex: index,
                videoUrl: videoUrl,
                isActive: isActive,
              ),
            );
          },
        );
      },
      controller: _controller,
    );
  }

  Map<int, Future<Video?>> videoFutureCache = {};
  Future<Video?> getVideoByIndex(int index, {bool clearCache = true}) {
    videoFutureCache[index] ??= widget.videoProvider.getVideoByIndex(index);
    if (clearCache) videoFutureCache.remove(index - 10);
    return videoFutureCache[index]!;
  }

  Controller _buildController() {
    return Controller(page: 0)..addListener(_onScroll);
  }

  void _onScroll(ScrollEvent event) {
    if (_isResetting) return;

    final newActiveIndex = translateIndex(event.pageNo ?? 0);
    if (newActiveIndex != _currentActiveIndex) {
      final oldIndex = _currentActiveIndex;

      setState(() {
        _currentActiveIndex = newActiveIndex;
      });

      if ((newActiveIndex - oldIndex).abs() == 1) {
        _handleVideoChange(newActiveIndex);
      }
    }

    if ((event.pageNo ?? 0) >= refreshFrequency) {
      _isResetting = true;

      _controller.jumpToPosition(0);
      resets++;

      Future.delayed(const Duration(milliseconds: 100), () {
        _isResetting = false;
      });
    }
  }
}

enum VideoStateType {
  top,
  current,
  bottom,
  loading
}