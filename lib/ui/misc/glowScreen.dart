import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Glowscreen extends StatefulWidget{
  final Widget child;
  const Glowscreen({super.key, required this.child});

  @override
  State<Glowscreen> createState() => _GlowscreenState();
}

class _GlowscreenState extends State<Glowscreen> {

  Color _dominantColor = Colors.grey;

  void _updateGlowColor(Color color) {
    setState(() {
      _dominantColor = color;
    });
  }
  
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  _dominantColor.withOpacity(0.4),
                  _dominantColor.withOpacity(0.2),
                  _dominantColor.withOpacity(0.1),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.3, 0.6, 1.0],
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