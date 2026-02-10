import 'package:flutter/material.dart';
import 'package:tiktoklikescroller/tiktoklikescroller.dart';

import 'misc/video_controller_pool.dart';
import 'misc/video_widget.dart';

class ScrollingContainer extends StatefulWidget {
  const ScrollingContainer({super.key});

  @override
  State<ScrollingContainer> createState() => _ScrollingContainerState();
}
class _ScrollingContainerState extends State<ScrollingContainer> {
  late final Controller _scrollController;
  late final VideoControllerPool _videoPool;

  final _url =
      "https://cdn.pixabay.com/video/2024/10/13/236256_large.mp4";

  @override
  void initState() {
    super.initState();
    _scrollController = Controller()..addListener(_onScroll);
    _videoPool = VideoControllerPool(_url);
  }
  
  final ValueNotifier<int> focusedIndex = ValueNotifier(0);
  void _onScroll(ScrollEvent event) {
    if (event.pageNo == null) return;

    if (focusedIndex.value != event.pageNo) {
      focusedIndex.value = event.pageNo!;
      _videoPool.playOnly(event.pageNo!);
      _videoPool.keepOnly({
        event.pageNo! - 1,
        event.pageNo!,
        event.pageNo! + 1,
      });
    }
    if(event.pageNo! > 997) {
      setState(() {});
      focusedIndex.value = 0;
      _videoPool.playOnly(0);
      _videoPool.keepOnly({0, 1, 999});
    }
  }


  @override
  Widget build(BuildContext context) {
    return TikTokStyleFullPageScroller(
      controller: _scrollController,
      contentSize: 1000,
      builder: (context, index) {
        final controller = _videoPool.get(index);
        print("Building item $index");
        return VideoItem(
          index: index,
          focusedIndex: focusedIndex,
          controller: controller,
        );
      },
    );
  }

  @override
  void dispose() {
    focusedIndex.dispose();
    _videoPool.dispose();
    _scrollController.disposeListeners();
    super.dispose();
  }
}
