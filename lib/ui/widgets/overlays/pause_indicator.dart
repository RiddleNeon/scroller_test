import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A simple overlay widget that shows a pause icon when the video is paused.
class PauseIndicator extends StatefulWidget {
  final void Function(bool val)? onToggle;

  const PauseIndicator({super.key, this.onToggle});

  @override
  State<PauseIndicator> createState() => PauseIndicatorState();
}

class PauseIndicatorState extends State<PauseIndicator> {
  bool visible = false;

  void toggleVisibility() {
    setState(() {
      visible = !visible;
      widget.onToggle?.call(visible);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      child: AnimatedScale(
        scale: visible ? 1 : 0.9,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        child: Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(41),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.8)),
          ),
          child: Center(child: Icon(visible ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill, color: cs.onSurface, size: 36)),
        ),
      ),
    );
  }
}
