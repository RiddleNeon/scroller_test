import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class BasicMemePlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final MemeVid vid;

  BasicMemePlayer({super.key, required this.vid}) : controller = VideoPlayerController.networkUrl(Uri.parse(vid.url));

  @override
  State<BasicMemePlayer> createState() => _BasicMemePlayerState();
}

class _BasicMemePlayerState extends State<BasicMemePlayer> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: widget.controller.initialize().then((value) async {
        widget.controller.play();
        return 'done';
      }),
      builder: (context, asyncSnapshot) {
        print("playing ${widget.controller.dataSource}");
        if (asyncSnapshot.hasError || !asyncSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator(value: 0.5));
        }

        return AspectRatio(aspectRatio: widget.controller.value.aspectRatio, child: VideoPlayer(widget.controller));
      },
    );
  }

  @override
  void dispose() {
    widget.controller.pause();
    widget.controller.dispose();
    super.dispose();
  }
}

enum MemeVid {
  rick(String.fromEnvironment("RICK_URL")),
  hamster(String.fromEnvironment("HAMSTER_URL"));

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
          child: IntrinsicHeight(child: BasicMemePlayer(vid: MemeVid.rick)),
        ),
      );
    },
  );
}
