import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Matrix4;

class RollingDigitCounter extends StatelessWidget {
  final int value;
  final TextStyle style;
  final int visibleNumbers;

  const RollingDigitCounter({super.key, required this.value, required this.style, this.visibleNumbers = 1});

  @override
  Widget build(BuildContext context) {
    final String digits = value.toString();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: digits.split('').map((digit) {
        return _DigitWheel(digit: int.parse(digit), style: style, visibleNumbers: visibleNumbers);
      }).toList(),
    );
  }
}

class _DigitWheel extends StatelessWidget {
  final int digit;
  final TextStyle style;
  final int visibleNumbers;

  const _DigitWheel({required this.digit, required this.style, required this.visibleNumbers});

  @override
  Widget build(BuildContext context) {
    final double fontSize = style.fontSize ?? 20;
    final double digitHeight = fontSize * 1.2;

    final double viewPortHeight = digitHeight * visibleNumbers;

    return SizedBox(
      height: viewPortHeight,
      width: fontSize * 0.7,
      child: ClipRect(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: digit.toDouble(), end: digit.toDouble()),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutBack,
          builder: (context, value, child) {
            return Stack(alignment: Alignment.center, children: [for (int i = 0; i <= 9; i++) _buildAnimatedDigit(i, value, digitHeight)]);
          },
        ),
      ),
    );
  }

  Widget _buildAnimatedDigit(int index, double scrollValue, double digitHeight) {
    final double relativeOffset = index - scrollValue;

    final double rotationAngle = relativeOffset * (math.pi / 4);
    final double opacity = (1.0 - (relativeOffset.abs() * 0.5)).clamp(0.0, 1.0);

    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.002)
        ..translateByVector3(Vector3(0.0, relativeOffset * digitHeight, 0.0))
        ..rotateX(rotationAngle),
      alignment: Alignment.center,
      child: Opacity(
        opacity: opacity,
        child: Text('$index', style: style.copyWith(height: 1.0), textAlign: TextAlign.center),
      ),
    );
  }
}
