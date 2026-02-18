import 'package:video_player/video_player.dart';
import 'package:wurp/logic/video/video.dart';

class VideoContainer {
  Video video;
  VideoPlayerController? controller;

  VideoContainer({required this.video});

  Future<void> loadController() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(video.videoUrl),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      ),
    );

    print("loading video ${video.videoUrl}");
    await controller.initialize();

    await controller.setLooping(true);

    this.controller = controller;
  }
}