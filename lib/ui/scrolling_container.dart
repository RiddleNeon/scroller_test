import 'package:flutter/material.dart';
import 'package:tiktoklikescroller/tiktoklikescroller.dart';
import 'package:wurp/ui/misc/video_playing_manager.dart';
import 'misc/video_playing_widget.dart';

class ScrollingContainer extends StatefulWidget {
  const ScrollingContainer({super.key});

  @override
  State<ScrollingContainer> createState() => _ScrollingContainerState();
}

class _ScrollingContainerState extends State<ScrollingContainer> {
  late Controller _controller;
  int _focusedIndex = 0;
  final String _dummyUrl = "https://cdn.pixabay.com/video/2024/10/13/236256_large.mp4";

  @override
  void initState() {
    super.initState();
    _controller = Controller()..addListener(_onScroll);

    // Setup beim Start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VideoManager().initializeFirst(0, _dummyUrl);
      VideoManager().preloadNext(1, _dummyUrl);
    });
  }

  void _onScroll(ScrollEvent event) {
    if (event.pageNo == null) return;

    final newIndex = event.pageNo!;
    if (newIndex != _focusedIndex) {
      // Nur updaten, wenn der Index sich wirklich geändert hat
      setState(() {
        _focusedIndex = newIndex;
      });
      VideoManager().switchToIndex(newIndex, _dummyUrl, newIndex + 1, _dummyUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TikTokStyleFullPageScroller(
      contentSize: 1000,
      builder: (context, index) {
        return VideoPlayer(
          key: ValueKey('v_$index'), // Wichtig für Flutter's Element-Tree
          videoIndex: index,
          isActive: index == _focusedIndex,
        );
      },
      controller: _controller,
    );
  }

  @override
  void dispose() {
    _controller.disposeListeners();
    // VideoManager nicht hier disposen, wenn die App noch läuft, 
    // sondern nur wenn die gesamte View zerstört wird.
    super.dispose();
  }
}