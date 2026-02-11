import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'misc/video_controller_pool.dart';

class ScrollingContainer extends StatefulWidget {
  const ScrollingContainer({super.key});

  @override
  State<ScrollingContainer> createState() => _ScrollingContainerState();
}

class _ScrollingContainerState extends State<ScrollingContainer> {
  late final PageController _scrollController;
  late final VideoControllerPool _videoPool;

  final _url = "https://cdn.pixabay.com/video/2024/10/13/236256_large.mp4";

  @override
  void initState() {
    super.initState();
    _scrollController = PageController();
    _videoPool = VideoControllerPool(_url);
  }

  final ValueNotifier<int> focusedIndex = ValueNotifier(0);
  final ValueNotifier<ScrollEventType> focusedScrollType = ValueNotifier(ScrollEventType.stay);

  void _onScroll(int index) {
    final double page = _scrollController.page ?? 0;
    final int pageNo = page.floor();
    final double fraction = _scrollController.page! - pageNo;
    focusedScrollType.value = getScrollTypeOfViewportFraction(fraction);
    if (focusedIndex.value != pageNo) {
      focusedIndex.value = pageNo;
      _videoPool.playOnly(pageNo);
      _videoPool.keepOnly({pageNo - 1, pageNo, pageNo + 1});
    }
  }

  ScrollEventType getScrollTypeOfViewportFraction(double fraction) {
    if (fraction == 0) return ScrollEventType.stay;
    if (fraction > 0) return ScrollEventType.scrollDown;
    return ScrollEventType.scrollUp;
  }
  
  bool _isAnimating = false;
  
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!_scrollController.hasClients) return;
    if (_isAnimating) return;

    _isAnimating = true;

    final isScrollDown = event.scrollDelta.dy > 0;

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final future = isScrollDown
          ? _scrollController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      )
          : _scrollController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

      future.whenComplete(() {
        _isAnimating = false;
      });
    });
    
    
  }


  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: NoWheelScrollBehavior(),
      child: Listener(
        onPointerSignal: _handlePointerSignal,
        child: PageView.builder(
          controller: _scrollController,
          scrollDirection: Axis.vertical,
          physics: const PageScrollPhysics(),
          itemCount: 20,
          itemBuilder: (context, index) {
            return Container(
              color: Colors.primaries[index % Colors.primaries.length],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    focusedIndex.dispose();
    _videoPool.dispose();
    super.dispose();
  }
}

enum ScrollEventType { stay, scrollDown, scrollUp }

class NoWheelScrollBehavior extends MaterialScrollBehavior {
  @override
  Widget buildScrollbar(
      BuildContext context,
      Widget child,
      ScrollableDetails details) {
    return child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const PageScrollPhysics();
  }
}
