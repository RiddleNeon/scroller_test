import 'dart:async';

import 'package:lumox/logic/video/video.dart';
import 'package:lumox/ui/video/video_controller.dart';

class VideoContainer {
  Video? video;
  VideoController? controller;
  DateTime? loadedAt;

  VideoContainer({required this.video});

  Future<void> loadController() async {
    if (video == null || controller != null) return;
    
    controller = VideoController.fromVideoUrl(video!.videoUrl);
    controller?.addListener(_onLoadListener);
    
    await controller!.init();
    loadedAt = DateTime.now();
    
    await controller!.setLooping(true);
  }
  
  void _onLoadListener(bool playing) {
    bool readyToPlay = controller?.isInitialized == true && video != null && video!.videoUrl.isNotEmpty && (controller?.isLooping ?? false);
    if (readyToPlay) {
      if(!(controller?.isPlaying ?? true)) controller?.play();
      controller?.removeListener(_onLoadListener);
    }
  }
}
