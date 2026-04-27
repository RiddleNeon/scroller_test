import 'package:wurp/logic/video/video.dart';

import 'package:wurp/ui/video/video_container.dart';

import 'feed_view_model.dart';

class YoutubeFeedViewModel extends FeedViewModel {
  final Map<int, VideoContainer> _containers = {};
  
  YoutubeFeedViewModel();


  @override
  int currentIndex = 0;

  @override
  Future<void> dispose() async {
    for (final controller in _containers.values) {
      await controller.controller?.dispose();
    }
    _containers.clear();
  }

  @override
  Future<void> ensureCurrentVideoPlays(Video? video) async {
    if (_containers.containsKey(currentIndex)) {
      await _containers[currentIndex]?.controller?.play();
    }
  }

  @override
  Future<VideoContainer> getVideoContainerAt(int index, Video video) async {
    if(index != currentIndex) {
      print("Warning: getVideoContainerAt called for index $index, but currentIndex is $currentIndex. This may lead to unexpected behavior.");
    }
    print("getting video at index $index");
    _containers[index] ??= VideoContainer(video: video); //fixme
    if (_containers[index]!.controller == null) {
      await _containers[index]!.loadController();
      print("Controller loaded for video at index $index");
    }
    return Future.value(_containers[index]!);
  }

  @override
  Future<void> pauseAll() async {
    for (final container in _containers.values) {
      await container.controller?.pause();
    }
  }

  @override
  Future<void> switchToVideoContainerAt(int index, Video video) async {
    if (index == currentIndex) return;

    await _containers[currentIndex]?.controller?.dispose();
    _containers.remove(currentIndex);

    _containers[index] ??= VideoContainer(video: video);
    await _containers[index]!.loadController();
    await _containers[index]!.controller?.play();

    currentIndex = index;
  }
}