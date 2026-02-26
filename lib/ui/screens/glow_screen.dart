import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class Glowscreen extends StatefulWidget{
  final Widget child;
  const Glowscreen({super.key, required this.child});

  @override
  State<Glowscreen> createState() => _GlowscreenState();
}

class _GlowscreenState extends State<Glowscreen> {
  Color? _dominantColor;
  
  @override
  Widget build(BuildContext context) {
    _dominantColor ??= Theme.of(context).colorScheme.surface;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _dominantColor!.withValues(alpha: 1),
                    _dominantColor!.withValues(alpha: 0.8),
                    _dominantColor!.withValues(alpha: 0.9),
                  ],
                  transform: const GradientRotation(0.7),
                  stops: const [0.7, 0.6, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          widget.child
        ],
      ),
    );
  }
}