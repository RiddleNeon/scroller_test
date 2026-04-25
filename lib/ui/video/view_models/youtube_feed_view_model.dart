import 'package:wurp/logic/video/video_provider.dart';

import 'package:wurp/ui/video/video_container.dart';

import 'feed_view_model.dart';

class YoutubeFeedViewModel extends FeedViewModel {
  VideoProvider? _activeVideoSource;
  final Map<int, VideoContainer> _containers = {};

  
  
  YoutubeFeedViewModel([super.videoSource]);


  @override
  int currentIndex = 0;

  @override
  Future<void> dispose() {
    for (final controller in _containers.values) {
      controller.controller?.dispose();
    }
    _containers.clear();
    return Future.value();
  }

  @override
  Future<void> ensureCurrentVideoPlays({VideoProvider? videoSource}) {
    if (_containers.containsKey(currentIndex)) {
      _containers[currentIndex]?.controller?.play();
    }
    return Future.value();
  }

  @override
  Future<VideoContainer> getVideoAt(int index, {VideoProvider? videoSource}) async {
    _containers[index] ??= VideoContainer(video: await videoSource!.getVideoByIndex(index)); //fixme
    return Future.value(_containers[index]!);
  }

  @override
  Future<void> pauseAll() {
    for (final container in _containers.values) {
      container.controller?.pause();
    }
    return Future.value();
  }

  @override
  Future<void> switchToVideoAt(int index, {VideoProvider? videoSource}) async {
    if (index == currentIndex) return;

    _containers[currentIndex]?.controller?.dispose();
    _containers.remove(currentIndex);

    _containers[index] ??= VideoContainer(video: await videoSource!.getVideoByIndex(index));
    await _containers[index]!.loadController();
    _containers[index]!.controller?.play();

    currentIndex = index;
  }
}