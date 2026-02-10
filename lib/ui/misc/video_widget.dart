import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoItem extends StatelessWidget {
  final int index;
  final ValueNotifier<int> focusedIndex;
  final VideoPlayerController controller;

  const VideoItem({
    super.key,
    required this.index,
    required this.focusedIndex,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: focusedIndex,
        builder: (context, focused, _) {
          if (focused != index && focused != index - 1) {
            return const SizedBox.expand();
          }

          return ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (_, value, _) {
              if (!value.isInitialized) {
                return const Center(child: CircularProgressIndicator());
              }
              return VideoPlayer(controller);
            },
          );
        },
      ),
    );
  }
}
