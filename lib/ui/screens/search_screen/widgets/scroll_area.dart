import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ScrollArea extends StatelessWidget {
  const ScrollArea({super.key, required this.scrollController, required this.child});

  final ScrollController scrollController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final newOffset = (scrollController.offset + event.scrollDelta.dy * 1.8).clamp(0.0, scrollController.position.maxScrollExtent);
          scrollController.animateTo(newOffset, duration: const Duration(milliseconds: 180), curve: Curves.easeOutCubic);
        }
      },
      child: child,
    );
  }
}

class SmoothScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad, PointerDeviceKind.stylus};
}
