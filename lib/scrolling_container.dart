import 'dart:math';

import 'package:flutter/material.dart';
import 'package:tiktoklikescroller/tiktoklikescroller.dart';

class ScrollingContainer extends StatefulWidget {
  static const List<Color> colors = [Colors.green, Colors.blue, Colors.cyan, Colors.red, Colors.purple];

  const ScrollingContainer({super.key});

  @override
  State<ScrollingContainer> createState() => _ScrollingContainerState();
}

class _ScrollingContainerState extends State<ScrollingContainer> {

  late Controller _controller;
  bool _isResetting = false;
  
  int resets = 0;
  static const int refreshFrequency = 3;
  
  int get currentIndex => _controller.getScrollPosition() + resets * refreshFrequency;
  
  int translateIndex(int index) => index + resets*refreshFrequency;

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
      contentSize: refreshFrequency+5,
      builder: (context, modIndex) {
        int index = modIndex % (refreshFrequency+1);
        return Container(
          color: Colors.accents[Random(translateIndex(index)).nextInt(Colors.accents.length)], child: Text("${translateIndex(index)}"));
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