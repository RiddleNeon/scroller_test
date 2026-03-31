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
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(40)),
        child: Center(child: Icon(visible ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill, color: Colors.white, size: 40)),
      ),
    );
  }
}
