import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lumox/ui/theme/theme_ui_values.dart';

/// A simple overlay that briefly appears when playback enters paused state.
class PauseIndicator extends StatefulWidget {
  final bool isPaused;

  const PauseIndicator({super.key, required this.isPaused});

  @override
  State<PauseIndicator> createState() => PauseIndicatorState();
}

class PauseIndicatorState extends State<PauseIndicator> {
  bool visible = false;
  Timer? _hideTimer;


  @override
  void didUpdateWidget(covariant PauseIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPaused == widget.isPaused) return;

    if (widget.isPaused) {
      _showAndHideAfterDelay();
    } else {
      _hideTimer?.cancel();
      if (visible) {
        setState(() {
          visible = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _showAndHideAfterDelay() {
    _hideTimer?.cancel();
    setState(() {
      visible = true;
    });

    _hideTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        visible = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 0.08),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      child: AnimatedScale(
        scale: visible ? 1 : 0.0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        child: Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(context.uiRadiusXl),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.8)),
          ),
          child: Center(child: Icon(widget.isPaused ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill, color: cs.onSurface, size: 36)),
        ),
      ),
    );
  }
}
