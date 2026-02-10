/*
import 'package:flutter/material.dart';
import 'package:wurp/ui/misc/video_playing_manager.dart';
import 'package:video_player/video_player.dart';

class ShortVideoPlayer extends StatefulWidget {
  final int videoIndex;
  final bool isActive;

  const ShortVideoPlayer({
    super.key,
    required this.videoIndex,
    required this.isActive,
  });

  @override
  State<ShortVideoPlayer> createState() => _ShortVideoPlayerState();
}

class _ShortVideoPlayerState extends State<ShortVideoPlayer> {
  bool paused = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: ValueListenableBuilder<VideoPlayerController?>(
        valueListenable: VideoManager().getControllerNotifier(widget.videoIndex),
        builder: (context, controller, child) {
          if (controller == null) {
            return const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
          }
          
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            Future.doWhile(
              () async {
                await Future.delayed(const Duration(milliseconds: 1000));
                if (widget.isActive) {
                  controller.play();
                  print("Playing video ${widget.videoIndex}");
                  return false;
                } else {
                  controller.pause();
                }
                return true;
              },
            );
          });
          
          
          return 
            InkWell(
              onTap: () => setState(() {
                paused = !paused;
              }),
              child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: VideoPlayer(controller),
                      ),
                    ),
                    if(paused) _PlayPauseOverlay(index: widget.videoIndex),
                  ],
            )
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
        return IgnorePointer(
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
}*/
