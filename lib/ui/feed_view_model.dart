import 'package:wurp/ui/video_container.dart';

import '../logic/video/video_provider.dart';

class FeedViewModel {
  VideoProvider? videoSource;

  FeedViewModel([this.videoSource]);

  final Map<int, VideoContainer> _containers = {};
  final Set<int> _loading = {};

  int _currentIndex = 0;
  int _switchRequestId = 0;

  int get currentIndex => _currentIndex;


  Future<VideoContainer> getVideoAt(int index, {VideoProvider? videoSource}) async {
    videoSource ??= this.videoSource;

    if (_containers.containsKey(index)) {
      return _containers[index]!;
    }

    return await _loadContainer(index, videoSource: videoSource);
  }

  Future<void> switchToVideoAt(int index, {VideoProvider? videoSource}) async {
    videoSource ??= this.videoSource;
    final requestId = ++_switchRequestId;

    final previous = _currentIndex;
    _currentIndex = index;

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

    if (!current.controller!.value.isInitialized) {
      await current.loadController();
      if (requestId != _switchRequestId) return;
    }

    await current.controller?.play();
    if (requestId != _switchRequestId) {
      await current.controller?.pause();
      return;
    }

    if (previous != index && _containers.containsKey(previous)) {
      final prev = _containers[previous];
      await prev?.controller?.pause();
      await prev?.controller?.seekTo(Duration.zero);
      if (requestId != _switchRequestId) return;
    }

    _preload(index + 1, videoSource);
    _preload(index - 1, videoSource);
  }

  Future<void> ensureCurrentVideoPlays({VideoProvider? videoSource}) async {
    return switchToVideoAt(_currentIndex, videoSource: videoSource);
  }

  Future<void> dispose() async {
    for (final container in _containers.values) {
      await container.controller?.dispose();
    }
    _containers.clear();
    _loading.clear();
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
      await container.loadController();

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
}