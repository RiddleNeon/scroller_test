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
          final newOffset = (scrollController.offset + event.scrollDelta.dy * 1.8)
              .clamp(0.0, scrollController.position.maxScrollExtent);
          scrollController.animateTo(
            newOffset,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
          );
        }
      },
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          final newOffset = (scrollController.offset - details.delta.dy)
              .clamp(0.0, scrollController.position.maxScrollExtent);
          scrollController.jumpTo(newOffset);
        },
        onVerticalDragEnd: (details) {
          final velocity = -(details.primaryVelocity ?? 0.0);
          if (velocity.abs() < 50) return;
          final target = (scrollController.offset + velocity * 0.4)
              .clamp(0.0, scrollController.position.maxScrollExtent);
          scrollController.animateTo(
            target,
            duration: Duration(milliseconds: (velocity.abs() * 0.55).clamp(200, 700).toInt()),
            curve: Curves.decelerate,
          );
        },
        child: child,
      ),
    );
  }
}

class SmoothScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}