import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/logic/video/video_provider.dart';
import 'package:wurp/ui/misc/video_widget.dart';

import '../../main.dart';

class OuterVideoWidget extends StatefulWidget {
  const OuterVideoWidget({
    super.key,
    required this.index,
    required TickerProvider tickerProvider,
    required this.focusedIndex,
    required RecommendationVideoProvider videoProvider,
  }) : _videoProvider = videoProvider,
       _tickerProvider = tickerProvider;
  final int index;
  final TickerProvider _tickerProvider;
  final ValueNotifier<int> focusedIndex;
  final RecommendationVideoProvider _videoProvider;

  @override
  State<OuterVideoWidget> createState() => _OuterVideoWidgetState();
}

class _OuterVideoWidgetState extends State<OuterVideoWidget> {
  bool playing = false;
  late VideoPlayerController controller;
  late Video video;

  @override
  void initState() {
    Future.microtask(() async {
      video = await widget._videoProvider.getVideoByIndex(widget.index);
      controller = VideoPlayerController.networkUrl(
        Uri.parse(video.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true, allowBackgroundPlayback: false),
      );
      await controller.initialize();
      controller.setLooping(true);
      setState(() => playing = true);
      controller.play();
    });
    super.initState();
  }
  
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return playing
        ? VideoItem(
            index: widget.index,
            videoProvider: widget._videoProvider,
            focusedIndex: widget.focusedIndex,
            controller: controller,
            video: video,
            userId: auth!.currentUser!.uid,
            provider: widget._tickerProvider,
          )
        : Center(child: CircularProgressIndicator());
  }
}
