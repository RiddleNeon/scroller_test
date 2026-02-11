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
        builder: (_, focused, __) {
          final bool isActive = focused == index;

          if (isActive) {
            if (!controller.value.isPlaying &&
                controller.value.isInitialized) {
              controller.play();
            }
          } else {
            if (controller.value.isPlaying) {
              controller.pause();
            }
          }

          return IgnorePointer(
            ignoring: !isActive,
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (_, value, __) {
                if (!value.isInitialized) {
                  return const SizedBox.expand(
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                return SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: value.size.width,
                      height: value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
