import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:wurp/logic/quests/quest_system.dart';
import 'quest_bubble.dart';

class QuestLineConnectionPainter extends CustomPainter {
  int? currentDraggedQuestId;
  Offset? currentDraggedQuestPos;

  int? connectionSourceId;
  Offset? connectionPreviewEnd;

  final QuestSystem questSystem;
  final Animation<double> animation;

  Rect? viewportRect;
  double scale;

  final double arrowHideScale;
  final double pixelSpacing;
  final double lineWidth;
  final double borderWidth;
  final Color borderColor;
  final double arrowSize;

  static const int _kLutSamples = 64;
  static const int _kMaxCacheEntries = 256;
  static final Map<String, _ArcLut> _lutCache = {};

  QuestLineConnectionPainter({
    required this.questSystem,
    required this.animation,
    this.viewportRect,
    this.scale = 1.0,
    this.arrowHideScale = 0.2,
    this.pixelSpacing = 50.0,
    this.lineWidth = 3.5,
    this.borderWidth = 2.2,
    this.borderColor = const Color(0xFF0A0A0A),
    this.arrowSize = 9.0,
  }) : super(repaint: animation);
  
  @override
  void paint(Canvas canvas, Size size) {
    final pixelOffset = animation.value * pixelSpacing;
    final showArrows = scale >= arrowHideScale;
    final cullRect = viewportRect?.inflate(_cullPadding());

    for (final quest in questSystem.quests) {
      if (questSystem.prerequisitesOf(quest.id).isEmpty) continue;

      final endCenter = _centerOf(quest.id);
      if (endCenter == null) continue;
      final questColor = glowColorOfQuest(quest.id);

      for (final prereq in questSystem.prerequisitesOf(quest.id)) {
        final prereqColor = glowColorOfQuest(prereq.id);

        final startQuest = questSystem.maybeGetQuestById(prereq.id);

        if (startQuest == null) continue;

        final startCenter = _centerOf(startQuest.id)!;
        final endCenter = _centerOf(quest.id)!;

        final anchorStart = _getBestAnchor(startQuest.id, endCenter);
        final anchorEnd = _getBestAnchor(quest.id, startCenter);
        
        final cps = _cubicControlPointsOffsetting(
            anchorStart.pos, anchorStart.sideDir,
            anchorEnd.pos, anchorEnd.sideDir,
            startQuest.id, quest.id
        );

        final p0 = anchorStart.pos;
        final cp1 = cps[0];
        final cp2 = cps[1];
        final p3 = anchorEnd.pos;

        if (cullRect != null && !_aabbIntersects(cullRect, startCenter, cp1, cp2, endCenter)) {
          continue;
        }

        final lut = _getLut(p0, cp1, cp2, p3);
        _drawBorderLine(canvas, p0, cp1, cp2, p3);
        _drawBaseLine(canvas, p0, cp1, cp2, p3, prereqColor, questColor);
        
        if (showArrows) {
          _drawMarchingArrows(
            canvas, p0, cp1, cp2, p3,
            lut, pixelOffset, prereqColor, questColor, cullRect,
          );
        }
      }
    }

    if (connectionSourceId != null && connectionPreviewEnd != null) {
      final start = _centerOf(connectionSourceId!);
      if (start != null) {
        _drawConnectionPreview(canvas, start, connectionPreviewEnd!, glowColorOfQuest(connectionSourceId!), connectionSourceId!);
      }
    }
  }

  List<Offset> _cubicControlPointsOffsetting(
      Offset pStart, Offset dirStart,
      Offset pEnd, Offset dirEnd,
      int sourceId, int targetId
      ) {
    final delta = pEnd - pStart;
    final dist = delta.distance;
    final tension = (dist * 0.4).clamp(30.0, 200.0);

    Offset cp1 = pStart + dirStart * tension;
    Offset cp2 = pEnd + dirEnd * tension;
    
    final int lowId = sourceId < targetId ? sourceId : targetId;
    final int highId = sourceId < targetId ? targetId : sourceId;

    final pLow = _centerOf(lowId)!;
    final pHigh = _centerOf(highId)!;
    final refDelta = pHigh - pLow;
    final refDist = refDelta.distance;

    if (refDist > 1.0) {
      final perp = Offset(-refDelta.dy, refDelta.dx) / refDist;
      
      final double side = (sourceId == lowId) ? 1.0 : -1.0;

      double pushAmount = (dist * 0.2).clamp(10.0, 60.0);

      bool hasReverse = questSystem.isConnected(sourceId, targetId) && questSystem.isConnected(targetId, sourceId);
      if (!hasReverse) {
        pushAmount = 0;
      }

      cp1 += perp * (pushAmount * side);
      cp2 += perp * (pushAmount * side);
    }

    return [cp1, cp2];
  }

  List<Offset> _cubicControlPoints(Offset pStart, Offset dirStart, Offset pEnd, Offset dirEnd) {
    final dist = (pEnd - pStart).distance;
    final tension = (dist * 0.4).clamp(30.0, 200.0);

    return [
      pStart + dirStart * tension,
      pEnd + dirEnd * tension,
    ];
  }
  

  _Anchor _getBestAnchor(int id, Offset targetCenter) {
    final quest = questSystem.maybeGetQuestById(id);
    if (quest == null) return _Anchor(Offset.zero, Offset.zero);

    final pos = (id == currentDraggedQuestId && currentDraggedQuestPos != null)
        ? currentDraggedQuestPos!
        : quest.position;

    final double w = quest.sizeX;
    final double h = quest.sizeY;
    final Offset center = pos + Offset(w / 2, h / 2);

    final dx = targetCenter.dx - center.dx;
    final dy = targetCenter.dy - center.dy;


    if ((dx / w).abs() > (dy / h).abs()) {
      if (dx > 0) {
        return _Anchor(Offset(pos.dx + w, center.dy), const Offset(1, 0));
      } else {
        return _Anchor(Offset(pos.dx, center.dy), const Offset(-1, 0));
      }
    } else {
      if (dy > 0) {
        return _Anchor(Offset(center.dx, pos.dy + h), const Offset(0, 1));
      } else {
        return _Anchor(Offset(center.dx, pos.dy), const Offset(0, -1));
      }
    }
  }

  double _cullPadding() => (arrowSize * 2.0) / scale.clamp(0.01, double.infinity);

  bool _aabbIntersects(Rect r, Offset p0, Offset p1, Offset p2, Offset p3) {
    final minX = [p0.dx, p1.dx, p2.dx, p3.dx].reduce((a, b) => a < b ? a : b);
    final minY = [p0.dy, p1.dy, p2.dy, p3.dy].reduce((a, b) => a < b ? a : b);
    final maxX = [p0.dx, p1.dx, p2.dx, p3.dx].reduce((a, b) => a > b ? a : b);
    final maxY = [p0.dy, p1.dy, p2.dy, p3.dy].reduce((a, b) => a > b ? a : b);
    return !(maxX < r.left || minX > r.right || maxY < r.top || minY > r.bottom);
  }

  void _drawBorderLine(Canvas canvas, Offset p0, Offset p1, Offset p2, Offset p3) {
    final path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);

    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor.withValues(alpha: 0.8)
        ..strokeWidth = lineWidth + borderWidth * 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawBaseLine(Canvas canvas, Offset p0, Offset p1, Offset p2, Offset p3, Color c0, Color c1) {
    final path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);

    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(p0, p3, [
          c0.withValues(alpha: 0.45),
          c1.withValues(alpha: 0.45),
        ])
        ..strokeWidth = lineWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawMarchingArrows(
      Canvas canvas,
      Offset p0, Offset p1, Offset p2, Offset p3,
      _ArcLut lut,
      double pixelOffset,
      Color startColor, Color endColor,
      Rect? cullRect,
      ) {
    final totalLen = lut.totalLength;
    if (totalLen < 1) return;

    final arrowWorldSize = arrowSize / scale.clamp(0.01, double.infinity);
    final arrowCullRect = cullRect?.inflate(arrowWorldSize);

    double arcPos = pixelOffset;
    while (arcPos < totalLen) {
      final progress = arcPos / totalLen;
      final t = lut.tForArcLen(arcPos);
      final pos = _bezierPoint(p0, p1, p2, p3, t);

      if (arrowCullRect != null && !arrowCullRect.contains(pos)) {
        arcPos += pixelSpacing;
        continue;
      }

      final fadeAlpha = _edgeFade(progress);
      final tangent = _bezierTangent(p0, p1, p2, p3, t);

      if (tangent.distance > 0.001) {
        final dir = tangent / tangent.distance;
        final color = Color.lerp(startColor, endColor, progress)!;
        _drawArrowHead(canvas, pos, dir, color, fadeAlpha);
      }

      arcPos += pixelSpacing;
    }
  }

  double _edgeFade(double progress) {
    const fadeZone = 0.07;
    if (progress < fadeZone) return progress / fadeZone;
    if (progress > 1.0 - fadeZone) return (1.0 - progress) / fadeZone;
    return 1.0;
  }

  void _drawArrowHead(Canvas canvas, Offset tip, Offset dir, Color color, double alpha) {
    final perp = Offset(-dir.dy, dir.dx);
    final base = tip - dir * arrowSize;
    final left = base + perp * (arrowSize * 0.48);
    final right = base - perp * (arrowSize * 0.48);

    final arrowPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = borderColor.withValues(alpha: alpha * 0.60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth * 1.2
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = color.withValues(alpha: alpha * 0.92)
        ..style = PaintingStyle.fill,
    );
  }

  Offset _bezierPoint(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final mt = 1.0 - t;
    return p0 * (mt * mt * mt) +
        p1 * (3 * mt * mt * t) +
        p2 * (3 * mt * t * t) +
        p3 * (t * t * t);
  }

  Offset _bezierTangent(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final mt = 1.0 - t;
    return (p1 - p0) * (3 * mt * mt) +
        (p2 - p1) * (6 * mt * t) +
        (p3 - p2) * (3 * t * t);
  }

  _ArcLut _getLut(Offset p0, Offset p1, Offset p2, Offset p3) {
    final key = '${p0.dx.round()},${p0.dy.round()},'
        '${p1.dx.round()},${p1.dy.round()},'
        '${p2.dx.round()},${p2.dy.round()},'
        '${p3.dx.round()},${p3.dy.round()}';

    var lut = _lutCache[key];
    if (lut != null) return lut;

    if (_lutCache.length >= _kMaxCacheEntries) _lutCache.clear();

    lut = _ArcLut.build(p0, p1, p2, p3, _kLutSamples, _bezierPoint);
    _lutCache[key] = lut;
    return lut;
  }

  void _drawConnectionPreview(Canvas canvas, Offset start, Offset end, Color color, int connectionId) {

    final pixelOffset = animation.value * pixelSpacing;
    final showArrows = scale >= arrowHideScale;
    final cullRect = viewportRect?.inflate(_cullPadding());
    
    final anchorStart = _getBestAnchor(connectionId, end);
    final anchorEnd = _Anchor(end, ui.Offset.zero);

    final cps = _cubicControlPoints(
        anchorStart.pos, anchorStart.sideDir,
        anchorEnd.pos, anchorEnd.sideDir,
    );


    final p0 = anchorStart.pos;
    final cp1 = cps[0];
    final cp2 = cps[1];
    final p3 = anchorEnd.pos;
    
    if (cullRect != null && !_aabbIntersects(cullRect, start, cp1, cp2, end)) {
      return;
    }

    final lut = _getLut(p0, cp1, cp2, p3);
    _drawBorderLine(canvas, p0, cp1, cp2, p3);
    _drawBaseLine(canvas, p0, cp1, cp2, p3, color, color);

    if (showArrows) {
      _drawMarchingArrows(
        canvas, p0, cp1, cp2, p3,
        lut, pixelOffset, color, color, cullRect,
      );
    }
  }

  Offset? _centerOf(int id) {
    final quest = questSystem.maybeGetQuestById(id);
    if (quest == null) return null;
    final pos = (id == currentDraggedQuestId && currentDraggedQuestPos != null)
        ? currentDraggedQuestPos!
        : quest.position;
    return pos + Offset(quest.sizeX, quest.sizeY) / 2;
  }

  @override
  bool shouldRepaint(covariant QuestLineConnectionPainter old) =>
      old.currentDraggedQuestId != currentDraggedQuestId ||
          old.currentDraggedQuestPos != currentDraggedQuestPos ||
          old.connectionSourceId != connectionSourceId ||
          old.connectionPreviewEnd != connectionPreviewEnd ||
          old.viewportRect != viewportRect ||
          old.scale != scale ||
          old.animation.value != animation.value;
}

class _ArcLut {
  final List<double> _data;
  double get totalLength => _data[_data.length - 1];
  const _ArcLut._(this._data);

  factory _ArcLut.build(
      Offset p0, Offset p1, Offset p2, Offset p3, int samples,
      Offset Function(Offset, Offset, Offset, Offset, double) bezierPoint,
      ) {
    final data = List<double>.filled((samples + 1) * 2, 0.0);
    var cumLen = 0.0;
    var prev = p0;
    for (int i = 0; i <= samples; i++) {
      final t = i / samples;
      final pt = bezierPoint(p0, p1, p2, p3, t);
      if (i > 0) cumLen += (pt - prev).distance;
      data[i * 2] = t;
      data[i * 2 + 1] = cumLen;
      prev = pt;
    }
    return _ArcLut._(data);
  }

  double tForArcLen(double arcLen) {
    final total = totalLength;
    if (arcLen <= 0) return 0;
    if (arcLen >= total) return 1;

    int lo = 0, hi = (_data.length ~/ 2) - 1;
    while (lo + 1 < hi) {
      final mid = (lo + hi) >> 1;
      if (_data[mid * 2 + 1] < arcLen) {
        lo = mid;
      } else {
        hi = mid;
      }
    }

    final len0 = _data[lo * 2 + 1];
    final len1 = _data[hi * 2 + 1];
    final t0 = _data[lo * 2];
    final t1 = _data[hi * 2];
    return t0 + (t1 - t0) * ((arcLen - len0) / (len1 - len0));
  }
}

Color glowColorOfQuest(int id) {
  if (glowColors.containsKey(id)) return glowColors[id]!;
  final hsl = HSLColor.fromColor(getColorFromSeed(id));
  final color = hsl.withLightness(0.65).withSaturation(0.75).toColor();
  return glowColors[id] = color;
}

Map<int, Color> glowColors = {};

class _Anchor {
  final Offset pos;
  final Offset sideDir; 
  _Anchor(this.pos, this.sideDir);
}