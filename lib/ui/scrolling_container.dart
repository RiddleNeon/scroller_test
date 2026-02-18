/*
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:preload_page_view/preload_page_view.dart' hide PageScrollPhysics;



import 'misc/video_controller_pool.dart';

class ScrollingContainer extends StatefulWidget {
  const ScrollingContainer({super.key});

  @override
  State<ScrollingContainer> createState() => _ScrollingContainerState();
}

class _ScrollingContainerState extends State<ScrollingContainer> with TickerProviderStateMixin {
  late final PreloadPageController _scrollController;
  late final VideoControllerPool _videoPool;

  @override
  void initState() {
    super.initState();
    _scrollController = PreloadPageController();
  }

  final ValueNotifier<int> focusedIndex = ValueNotifier(0);
  final ValueNotifier<ScrollEventType> focusedScrollType = ValueNotifier(ScrollEventType.stay);

  void _onScroll(int pageNo) {
    if (focusedIndex.value != pageNo) {
      focusedIndex.value = pageNo;
      print("Focused index changed to $pageNo");
    }
  }

  ScrollEventType getScrollTypeOfViewportFraction(double fraction) {
    if (fraction == 0) return ScrollEventType.stay;
    if (fraction > 0) return ScrollEventType.scrollDown;
    return ScrollEventType.scrollUp;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!_scrollController.hasClients) return;

    final isScrollDown = event.scrollDelta.dy > 0;

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      isScrollDown
          ? _scrollController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut)
          : _scrollController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: NoWheelScrollBehavior(),
      child: Listener(
        onPointerSignal: _handlePointerSignal,
        child: PreloadPageView.builder(
          preloadPagesCount: 1,
          controller: _scrollController,
          scrollDirection: Axis.vertical,
          physics: const PageScrollPhysics(),
          itemCount: 2000,
          itemBuilder: (context, index) {
            print("building index $index");
            return ShortVideoPlayer();
          },
          onPageChanged: _onScroll,
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
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad};

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const PageScrollPhysics();
  }
}
*/
