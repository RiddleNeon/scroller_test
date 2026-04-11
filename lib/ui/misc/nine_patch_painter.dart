import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum NinePatchMode { stretch, tile }

class NinePatchBorder {
  const NinePatchBorder({required this.left, required this.top, required this.right, required this.bottom})
    : assert(left >= 0),
      assert(top >= 0),
      assert(right >= 0),
      assert(bottom >= 0);

  const NinePatchBorder.all(double value) : left = value, top = value, right = value, bottom = value;

  final double left;
  final double top;
  final double right;
  final double bottom;
}

class NinePatchPainter extends CustomPainter {
  NinePatchPainter({required this.image, required this.border, this.mode = NinePatchMode.stretch, this.fit = BoxFit.fill});

  final ui.Image image;

  final NinePatchBorder border;

  final NinePatchMode mode;

  final BoxFit fit;

  double get _iw => image.width.toDouble();

  double get _ih => image.height.toDouble();

  List<Rect> get _srcRects {
    final l = border.left;
    final t = border.top;
    final r = border.right;
    final b = border.bottom;
    final cx = l;
    final cy = t;
    final cw = _iw - l - r;
    final ch = _ih - t - b;

    return [
      Rect.fromLTWH(0, 0, l, t),
      Rect.fromLTWH(cx, 0, cw, t),
      Rect.fromLTWH(_iw - r, 0, r, t),
      Rect.fromLTWH(0, cy, l, ch),
      Rect.fromLTWH(cx, cy, cw, ch),
      Rect.fromLTWH(_iw - r, cy, r, ch),
      Rect.fromLTWH(0, _ih - b, l, b),
      Rect.fromLTWH(cx, _ih - b, cw, b),
      Rect.fromLTWH(_iw - r, _ih - b, r, b),
    ];
  }

  List<Rect> _dstRects(Size size) {
    final l = border.left;
    final t = border.top;
    final r = border.right;
    final b = border.bottom;
    final cx = l;
    final cy = t;
    final cw = size.width - l - r;
    final ch = size.height - t - b;

    return [
      Rect.fromLTWH(0, 0, l, t),
      Rect.fromLTWH(cx, 0, cw, t),
      Rect.fromLTWH(size.width - r, 0, r, t),
      Rect.fromLTWH(0, cy, l, ch),
      Rect.fromLTWH(cx, cy, cw, ch),
      Rect.fromLTWH(size.width - r, cy, r, ch),
      Rect.fromLTWH(0, size.height - b, l, b),
      Rect.fromLTWH(cx, size.height - b, cw, b),
      Rect.fromLTWH(size.width - r, size.height - b, r, b),
    ];
  }

  static const _flexible = {1, 3, 4, 5, 7};

  @override
  void paint(Canvas canvas, Size size) {
    final srcs = _srcRects;
    final dsts = _dstRects(size);
    final paint = Paint()..filterQuality = FilterQuality.medium;

    for (var i = 0; i < 9; i++) {
      final src = srcs[i];
      final dst = dsts[i];

      if (src.isEmpty || dst.isEmpty) continue;

      if (!_flexible.contains(i) || mode == NinePatchMode.stretch) {
        canvas.drawImageRect(image, src, dst, paint);
      } else {
        _drawTiled(canvas, src, dst, paint);
      }
    }
  }

  void _drawTiled(Canvas canvas, Rect src, Rect dst, Paint paint) {
    canvas.save();
    canvas.clipRect(dst);

    final tileW = src.width;
    final tileH = src.height;

    double y = dst.top;
    while (y < dst.bottom) {
      double x = dst.left;
      while (x < dst.right) {
        final tileDst = Rect.fromLTWH(x, y, tileW, tileH);
        canvas.drawImageRect(image, src, tileDst, paint);
        x += tileW;
      }
      y += tileH;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(NinePatchPainter oldDelegate) => oldDelegate.image != image || oldDelegate.border != border || oldDelegate.mode != mode;
}

class NinePatchBox extends StatelessWidget {
  const NinePatchBox({super.key, required this.image, required this.border, this.mode = NinePatchMode.stretch, this.width, this.height, this.child});

  final ui.Image image;
  final NinePatchBorder border;
  final NinePatchMode mode;
  final double? width;
  final double? height;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: NinePatchPainter(image: image, border: border, mode: mode),
      child: SizedBox(width: width, height: height, child: child),
    );
  }
}
