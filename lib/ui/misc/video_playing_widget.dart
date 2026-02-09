import 'package:flutter/material.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:wurp/ui/misc/video_playing_manager.dart';

class VideoPlayer extends StatelessWidget {
  final int videoIndex;
  final bool isActive;

  const VideoPlayer({
    super.key,
    required this.videoIndex,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      // Dieser Builder hört NUR auf den Controller für DIESEN Index
      child: ValueListenableBuilder<BetterPlayerController?>(
        valueListenable: VideoManager().getControllerNotifier(videoIndex),
        builder: (context, controller, child) {
          if (controller == null) {
            return const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
          }

          // Nur abspielen, wenn das Widget wirklich aktiv im Viewport ist
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            if (isActive) {
              controller.play();
            } else {
              controller.pause();
            }
          });


          return Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: BetterPlayer(controller: controller),
                ),
              ),
              _PlayPauseOverlay(index: videoIndex),
            ],
          );
        },
      ),
    );
  }
}

class _PlayPauseOverlay extends StatelessWidget {
  final int index;
  const _PlayPauseOverlay({required this.index});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: VideoManager().getPlayingNotifier(index),
      builder: (context, isPlaying, _) {
        return IgnorePointer( // Damit das Icon Klicks nicht abfängt
          child: AnimatedOpacity(
            opacity: isPlaying ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: const Center(
              child: Icon(Icons.play_arrow, size: 80, color: Colors.white54),
            ),
          ),
        );
      },
    );
  }
}