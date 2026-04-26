import 'package:wurp/logic/video/video.dart';

import 'package:wurp/ui/video/video_container.dart';

import 'feed_view_model.dart';

class YoutubeFeedViewModel extends FeedViewModel {
  final Map<int, VideoContainer> _containers = {};
  
  YoutubeFeedViewModel();


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
  Future<void> ensureCurrentVideoPlays(Video? video) {
    if (_containers.containsKey(currentIndex)) {
      _containers[currentIndex]?.controller?.play();
    }
    return Future.value();
  }

  @override
  Future<VideoContainer> getVideoContainerAt(int index, Video video) async {
    print("getting video at index $index");
    _containers[index] ??= VideoContainer(video: video); //fixme
    if (_containers[index]!.controller == null) {
      await _containers[index]!.loadController();
      print("Controller loaded for video at index $index");
    }
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
  Future<void> switchToVideoContainerAt(int index, Video video) async {
    if (index == currentIndex) return;

    _containers[currentIndex]?.controller?.dispose();
    _containers.remove(currentIndex);

    _containers[index] ??= VideoContainer(video: video);
    await _containers[index]!.loadController();
    _containers[index]!.controller?.play();

    currentIndex = index;
  }
}