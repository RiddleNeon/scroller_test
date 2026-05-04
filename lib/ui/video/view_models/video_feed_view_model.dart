
import 'package:lumox/logic/video/video.dart';
import 'package:lumox/ui/video/video_controller.dart';

import '../video_container.dart';
import 'feed_view_model.dart';

class VideoFeedViewModel extends FeedViewModel {
  VideoFeedViewModel();

  final Map<int, VideoContainer> _containers = {};
  final Set<int> _loading = {};

  int _currentIndex = 0;
  int _switchRequestId = 0;

  @override
  int get currentIndex => _currentIndex;


  @override
  Future<VideoContainer> getVideoContainerAt(int index, Video video) async {
    if (_containers.containsKey(index)) {
      return _containers[index]!;
    }

    final container = await _loadContainer(index, video);
    return container;
  }

  @override
  Future<void> switchToVideoContainerAt(int index, Video video, {Video? nextVideo, Video? lastVideo}) async {
    if(index == _currentIndex) return;
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

    final current = await getVideoContainerAt(index, video);
    if(current.video == null || current.video!.videoUrl.isEmpty) {
      // If video is null or has an empty URL, skip playing and return early
      return;
    }
    if (requestId != _switchRequestId) return;

    if (!current.controller!.isInitialized) {
      await current.loadController();
      print("Controller loaded for index $index, isInitialized: ${current.controller!.isInitialized}");
      if (requestId != _switchRequestId){
        print("Switch request ID mismatch after loading controller, expected $requestId but got $_switchRequestId. Pausing video at index $index.");
        return;
      }
    }
    
    if (requestId != _switchRequestId) {
      await current.controller!.pause();
      print("Switch request ID mismatch after play, expected $requestId but got $_switchRequestId. Pausing video at index $index.");
      return;
    } else {
      Future.delayed(const Duration(milliseconds: 150), () => current.controller!.play());
    }

    if(current.controller is! YoutubeVideoController) {
      if(nextVideo != null) _preload(index + 1, nextVideo);
      if(lastVideo != null) _preload(index - 1, lastVideo);
    }
  }

  @override
  Future<void> ensureCurrentVideoPlays(Video video) async {
    return switchToVideoContainerAt(_currentIndex, video);
  }

  @override
  Future<void> dispose() async {
    await pauseAll();
    await _clearContainers();
    _loading.clear();
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


  Future<VideoContainer> _loadContainer(int index, Video video) async {
    if (_loading.contains(index)) {
      while (_loading.contains(index)) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return _containers[index]!;
    }

    _loading.add(index);

    try {
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

  void _preload(int index, Video video) {
    if (index < 0) return;
    if (_containers.containsKey(index)) return;
    if (_loading.contains(index)) return;

    _loadContainer(index, video);
  }

  Future<void> _disposeIndex(int index) async {
    final container = _containers.remove(index);
    await container?.controller?.dispose();
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