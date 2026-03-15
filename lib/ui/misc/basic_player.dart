import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class BasicMemePlayer extends StatelessWidget {
  final VideoPlayerController controller;
  final MemeVid vid;

  BasicMemePlayer({super.key, required this.vid})
    : controller = VideoPlayerController.networkUrl(Uri.parse(vid.url));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: controller.initialize().then((value) async {
        controller.play();
        return 'done';
      }),
      builder: (context, asyncSnapshot) {
        print("playing ${controller.dataSource}");
        if (asyncSnapshot.hasError || !asyncSnapshot.hasData) {
          return const SizedBox.shrink();
        }

        return AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        );
      },
    );
  }
}

enum MemeVid {
  rick(String.fromEnvironment("RICK_URL")), hamster(String.fromEnvironment("HAMSTER_URL"));
  final String url;
  const MemeVid(this.url);
}

Future<void> showRickDialog(BuildContext context) {
  return showDialog(
    fullscreenDialog: false,
    barrierDismissible: true,
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SizedBox(
          width: double.infinity,
          child: IntrinsicHeight(
            child: BasicMemePlayer(vid: MemeVid.rick),
          ),
        ),
      );
    },
  );
}