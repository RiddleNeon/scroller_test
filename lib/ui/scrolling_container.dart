import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:wurp/logic/video/video_provider.dart';
import 'package:wurp/main.dart';
import 'package:wurp/ui/misc/video_widget.dart';

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
    _videoPool = VideoControllerPool(RecommendationVideoProvider(userId: auth!.currentUser!.uid));
  }

  final ValueNotifier<int> focusedIndex = ValueNotifier(0);
  final ValueNotifier<ScrollEventType> focusedScrollType = ValueNotifier(ScrollEventType.stay);

  void _onScroll(int pageNo) {
    if (focusedIndex.value != pageNo) {
      focusedIndex.value = pageNo;

      final double fraction = _scrollController.page! - pageNo;
      focusedScrollType.value = getScrollTypeOfViewportFraction(fraction);

      _videoPool.playOnly(pageNo);
      _videoPool.reset(pageNo);
      _videoPool.keepOnly({pageNo - 1, pageNo, pageNo + 1});
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
        child: PageView.builder(
          controller: _scrollController,
          scrollDirection: Axis.vertical,
          physics: const PageScrollPhysics(),
          itemCount: 2000,
          itemBuilder: (context, index) {
            return FutureBuilder(
              future: _videoPool.get(index),
              builder: (context, snapshot) => snapshot.data == null
                  ? Center(child: CircularProgressIndicator())
                  : VideoItem(index: index, focusedIndex: focusedIndex, controller: snapshot.data!),
            );
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
