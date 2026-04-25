import 'package:wurp/ui/video/video_container.dart';

import '../../../logic/video/video_provider.dart';


abstract class FeedViewModel {
  VideoProvider? videoSource;

  FeedViewModel([this.videoSource]);

  int get currentIndex;


  Future<VideoContainer> getVideoAt(int index, {VideoProvider? videoSource});

  Future<void> switchToVideoAt(int index, {VideoProvider? videoSource});

  Future<void> ensureCurrentVideoPlays({VideoProvider? videoSource});

  Future<void> dispose();

  Future<void> pauseAll();
}
