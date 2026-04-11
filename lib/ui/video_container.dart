import 'dart:async';

import 'package:video_player/video_player.dart';
import 'package:wurp/logic/video/video.dart';

class VideoContainer {
  Video? video;
  VideoPlayerController? controller;
  DateTime? loadedAt;

  VideoContainer({required this.video});

  Future<void> loadController() async {
    if (video == null) return;

    controller = VideoPlayerController.networkUrl(Uri.parse(video!.videoUrl), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));

    await controller!.initialize();

    loadedAt = DateTime.now();
    return controller!.setLooping(true);
  }
}
