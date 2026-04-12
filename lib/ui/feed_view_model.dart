import 'package:wurp/ui/video_container.dart';

import '../logic/video/video_provider.dart';

class FeedViewModel {
  VideoProvider? videoSource;

  FeedViewModel([this.videoSource]);

  final Map<int, VideoContainer> _containers = {};
  final Set<int> _loading = {};

  int _currentIndex = 0;


  Future<VideoContainer> getVideoAt(int index, {VideoProvider? videoSource}) async {
    videoSource ??= this.videoSource;

    if (_containers.containsKey(index)) {
      return _containers[index]!;
    }

    return await _loadContainer(index, videoSource: videoSource);
  }

  Future<void> switchToVideoAt(int index, {VideoProvider? videoSource}) async {
    videoSource ??= this.videoSource;
    final previous = _currentIndex;
    _currentIndex = index;

    final toDispose = _containers.keys
        .where((i) => (i - index).abs() > 3)
        .toList();

    for (final i in toDispose) {
      await _disposeIndex(i);
    }

    final current = await getVideoAt(index, videoSource: videoSource);

    if (!current.controller!.value.isInitialized) {
      await current.loadController();
    }

    await current.controller?.play();

    if (previous != index && _containers.containsKey(previous)) {
      final prev = _containers[previous];
      await prev?.controller?.pause();
      await prev?.controller?.seekTo(Duration.zero);
    }

    _preload(index + 1, videoSource);
    _preload(index - 1, videoSource);
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