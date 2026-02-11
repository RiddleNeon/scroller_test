import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoItem extends StatelessWidget {
  final int index;
  final ValueNotifier<int> focusedIndex;
  final VideoPlayerController controller;

  const VideoItem({super.key, required this.index, required this.focusedIndex, required this.controller});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: focusedIndex,
        builder: (_, focused, _) {
          final bool isActive = focused == index;
      
          if (isActive) {
            if (!controller.value.isPlaying && controller.value.isInitialized) {
              controller.play();
            }
          } else {
            if (controller.value.isPlaying) {
              controller.pause();
            }
          }
      
          return ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (_, value, _) {
              return Center(
                child: value.size.width == 0 || value.size.height == 0
                    ? const SizedBox()
                    : AspectRatio(aspectRatio: 9/16, child: VideoPlayer(controller)),
                );
              }
          );
        },
      ),
    );
  }
}
