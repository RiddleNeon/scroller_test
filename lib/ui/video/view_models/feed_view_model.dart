import 'package:lumox/logic/video/video.dart';
import 'package:lumox/ui/video/video_container.dart';


abstract class FeedViewModel {
  FeedViewModel();

  int get currentIndex;


  Future<VideoContainer> getVideoContainerAt(int index, Video video);

  Future<void> switchToVideoContainerAt(int index, Video video);

  Future<void> ensureCurrentVideoPlays(Video video);

  Future<void> dispose();

  Future<void> pauseAll();
}
