import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class InfiniteDotsBackground extends StatefulWidget {
  final TransformationController controller;

  const InfiniteDotsBackground({super.key, required this.controller});

  @override
  State<InfiniteDotsBackground> createState() => _InfiniteDotsBackgroundState();
}

class _InfiniteDotsBackgroundState extends State<InfiniteDotsBackground> {
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/dotted_background.frag');
      if (mounted) {
        setState(() => _shader = program.fragmentShader());
      }
    } catch (e) {
      debugPrint('dotted_background.frag failed to load – falling back to CPU painter: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final m = widget.controller.value;
        final offsetX = m.entry(0, 3);
        final offsetY = m.entry(1, 3);
        final scale = m.entry(0, 0);

        return CustomPaint(
          painter: _shader != null
              ? _ShaderDotsPainter(shader: _shader!, offsetX: offsetX, offsetY: offsetY, scale: scale)
              : _CpuDotsPainter(offsetX: offsetX, offsetY: offsetY, scale: scale),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _ShaderDotsPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double offsetX;
  final double offsetY;
  final double scale;

  const _ShaderDotsPainter({required this.shader, required this.offsetX, required this.offsetY, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, offsetX)
      ..setFloat(3, offsetY)
      ..setFloat(4, scale);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ShaderDotsPainter old) => old.offsetX != offsetX || old.offsetY != offsetY || old.scale != scale;
}

class _CpuDotsPainter extends CustomPainter {
  final double offsetX;
  final double offsetY;
  final double scale;

  const _CpuDotsPainter({required this.offsetX, required this.offsetY, required this.scale});

  static const double _baseSpacing = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final double spacing = _baseSpacing * scale;
    final double radius = (2.0 * scale).clamp(0.6, 4.0);
    final double ox = offsetX % spacing;
    final double oy = offsetY % spacing;

    final pts = <Offset>[];
    for (double x = ox - spacing; x < size.width + spacing; x += spacing) {
      for (double y = oy - spacing; y < size.height + spacing; y += spacing) {
        pts.add(Offset(x, y));
      }
    }

    canvas.drawPoints(
      ui.PointMode.points,
      pts,
      Paint()
        ..color = const Color(0xFF6C7A96).withValues(alpha: 0.38)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = radius * 2,
    );
  }

  @override
  bool shouldRepaint(_CpuDotsPainter old) => old.offsetX != offsetX || old.offsetY != offsetY || old.scale != scale;
}
