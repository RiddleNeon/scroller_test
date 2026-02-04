import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:scroller_test/ui/overlays.dart';
import 'package:tiktoklikescroller/tiktoklikescroller.dart';

class ScrollingContainer extends StatefulWidget {
  static const List<Color> colors = [Colors.green, Colors.blue, Colors.cyan, Colors.red, Colors.purple];

  const ScrollingContainer({super.key});

  @override
  State<ScrollingContainer> createState() => _ScrollingContainerState();
}

class _ScrollingContainerState extends State<ScrollingContainer> with TickerProviderStateMixin {
  late Controller _controller;
  bool _isResetting = false;

  int resets = 0;
  static const int refreshFrequency = 30;

  int get currentIndex => _controller.getScrollPosition() + resets * refreshFrequency;

  int translateIndex(int index) => index + resets * refreshFrequency;

  @override
  void initState() {
    super.initState();
    _controller = _buildController();
  }

  @override
  void dispose() {
    _controller.disposeListeners();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TikTokStyleFullPageScroller(
      contentSize: refreshFrequency + 5,
      builder: (context, modIndex) {
        int index = translateIndex(modIndex % (refreshFrequency + 1));
        return Center(
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: Container(
              color: Colors.accents[Random(index).nextInt(Colors.accents.length)],
              child: Stack(
                children: [
                  Center(
                    child: Text("Video $index", style: TextStyle(fontSize: 32, color: Colors.white)),
                  ),
                  PageOverlay(provider: this)
                ],
              ),
            ),
          ),
        );
      },
      controller: _controller,
    );
  }

  Controller _buildController() {
    return Controller(page: 0)..addListener(_onScroll);
  }

  void _onScroll(ScrollEvent event) {
    if (_isResetting) return;

    if ((event.pageNo ?? 0) >= refreshFrequency) {
      _isResetting = true;

      _controller.jumpToPosition(0);
      resets++;

      Future.delayed(Duration(milliseconds: 100), () {
        _isResetting = false;
      });
    }
  }
}
