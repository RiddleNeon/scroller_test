
import 'package:wurp/logic/video/video_provider.dart';
import 'package:wurp/ui/video/video_controller.dart';

import '../video_container.dart';
import 'feed_view_model.dart';

class VideoFeedViewModel extends FeedViewModel {
  VideoProvider? _activeVideoSource;

  VideoFeedViewModel([super.videoSource]);

  final Map<int, VideoContainer> _containers = {};
  final Set<int> _loading = {};

  int _currentIndex = 0;
  int _switchRequestId = 0;

  @override
  int get currentIndex => _currentIndex;


  @override
  Future<VideoContainer> getVideoAt(int index, {VideoProvider? videoSource}) async {
    videoSource ??= this.videoSource;
    await _ensureActiveVideoSource(videoSource);

    if (_containers.containsKey(index)) {
      return _containers[index]!;
    }

    final container = await _loadContainer(index, videoSource: videoSource);
    print("Container loaded for index $index");
    return container;
  }

  @override
  Future<void> switchToVideoAt(int index, {VideoProvider? videoSource}) async {
    videoSource ??= this.videoSource;
    await _ensureActiveVideoSource(videoSource);
    final requestId = ++_switchRequestId;

    _currentIndex = index;

    // Stop audio/video from previously visible pages immediately.
    await _pauseAllExcept(index);
    if (requestId != _switchRequestId) return;

    final toDispose = _containers.keys
        .where((i) => (i - index).abs() > 3)
        .toList();

    for (final i in toDispose) {
      await _disposeIndex(i);
      if (requestId != _switchRequestId) return;
    }

    final current = await getVideoAt(index, videoSource: videoSource);
    if(current.video == null || current.video!.videoUrl.isEmpty) {
      // If video is null or has an empty URL, skip playing and return early
      return;
    }
    if (requestId != _switchRequestId) return;

    if (!current.controller!.isInitialized) {
      await current.loadController();
      if (requestId != _switchRequestId) return;
    }

    await current.controller?.play();
    if (requestId != _switchRequestId) {
      await current.controller?.pause();
      return;
    }

    if(current.controller is! YoutubeVideoController) {
      _preload(index + 1, videoSource);
      _preload(index - 1, videoSource);
    }
  }

  @override
  Future<void> ensureCurrentVideoPlays({VideoProvider? videoSource}) async {
    return switchToVideoAt(_currentIndex, videoSource: videoSource);
  }

  @override
  Future<void> dispose() async {
    await pauseAll();
    await _clearContainers();
    if (videoSource is RecommendationVideoProvider) {
      (videoSource as RecommendationVideoProvider).clearCache();
    }
    _loading.clear();
    _activeVideoSource = null;
  }

  @override
  Future<void> pauseAll() async {
    for (final container in _containers.values) {
      final controller = container.controller;
      if (controller == null) continue;
      if (!controller.isInitialized) continue;
      await controller.pause();
    }
  }


  Future<VideoContainer> _loadContainer(int index, {VideoProvider? videoSource}) async {
    if (_loading.contains(index)) {
      while (_loading.contains(index)) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return _containers[index]!;
    }

    _loading.add(index);

    try {
      final video = await videoSource!.getVideoByIndex(index);

      final container = VideoContainer(video: video);
      if(_currentIndex == index || container.controller is! YoutubeVideoController) {
        await container.loadController();
      }

      _containers[index] = container;
      return container;
    } finally {
      _loading.remove(index);
    }
  }

  void _preload(int index, VideoProvider? videoSource) {
    if (index < 0) return;
    if (_containers.containsKey(index)) return;
    if (_loading.contains(index)) return;

    _loadContainer(index, videoSource: videoSource);
  }

  Future<void> _disposeIndex(int index) async {
    final container = _containers.remove(index);
    await container?.controller?.dispose();
  }

  Future<void> _ensureActiveVideoSource(VideoProvider? source) async {
    if (source == null) return;
    if (identical(_activeVideoSource, source)) return;

    await _clearContainers();
    _loading.clear();
    _activeVideoSource = source;
    videoSource = source;
  }

  Future<void> _clearContainers() async {
    for (final container in _containers.values) {
      await container.controller?.dispose();
    }
    _containers.clear();
  }

  Future<void> _pauseAllExcept(int keepIndex) async {
    for (final entry in _containers.entries) {
      if (entry.key == keepIndex) continue;
      final controller = entry.value.controller;
      if (controller == null) continue;
      if (!controller.isInitialized) continue;
      await controller.pause();
      await controller.seekTo(Duration.zero);
    }
  }
}