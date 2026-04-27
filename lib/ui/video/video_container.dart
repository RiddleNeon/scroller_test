import 'dart:async';

import 'package:wurp/logic/video/video.dart';
import 'package:wurp/ui/video/video_controller.dart';

class VideoContainer {
  Video? video;
  VideoController? controller;
  DateTime? loadedAt;

  VideoContainer({required this.video});

  Future<void> loadController() async {
    if (video == null || controller != null) return;
    
    print("Loading video controller for video ID: ${video!.id}, URL: ${video!.videoUrl}");

    controller = VideoController.fromVideoUrl(video!.videoUrl);
    await controller!.init();
    print("Video controller initialized for video ID: ${video!.id}, setting looping... is initialized: ${controller!.isInitialized}");
    loadedAt = DateTime.now();
    await controller!.setLooping(true);
    
    print("Video controller loaded for video ID: ${video!.id}");
  }
}
