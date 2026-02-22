import 'dart:async';

import 'package:video_player/video_player.dart';
import 'package:wurp/logic/video/video.dart';

class VideoContainer {
  Video video;
  VideoPlayerController? controller;

  VideoContainer({required this.video});

  Future<void> loadController() async {
    controller = VideoPlayerController.networkUrl(
      Uri.parse(video.videoUrl),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
      ),
    );

    await controller!.initialize();

    return controller!.setLooping(true);
  }
}
