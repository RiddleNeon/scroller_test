import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:wurp/logic/quests/quest_system.dart';
import 'bezier_helper.dart';
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

      final endCenter = getQuestCenter(quest.id, questSystem, currentDraggedQuestId, currentDraggedQuestPos);
      if (endCenter == null) continue;
      final questColor = glowColorOfQuest(quest.id);

      for (final prereq in questSystem.prerequisitesOf(quest.id)) {
        final prereqColor = glowColorOfQuest(prereq.id);

        final startQuest = questSystem.maybeGetQuestById(prereq.id);

        if (startQuest == null) continue;

        final startCenter = getQuestCenter(startQuest.id, questSystem, currentDraggedQuestId, currentDraggedQuestPos)!;
        final endCenter = getQuestCenter(quest.id, questSystem, currentDraggedQuestId, currentDraggedQuestPos)!;

        final anchorStart = getBestAnchor(startQuest.id, endCenter, questSystem, currentDraggedQuestId, currentDraggedQuestPos);
        final anchorEnd = getBestAnchor(quest.id, startCenter, questSystem, currentDraggedQuestId, currentDraggedQuestPos);
        
        final cps = calculateCubicControlPointsOffsetting(
            anchorStart.pos, anchorStart.sideDir,
            anchorEnd.pos, anchorEnd.sideDir,
            startQuest.id, quest.id,
              questSystem, currentDraggedQuestPos, currentDraggedQuestId
        );

        final p0 = anchorStart.pos;
        final cp1 = cps[0];
        final cp2 = cps[1];
        final p3 = anchorEnd.pos;

        if (cullRect != null && !_aabbIntersects(cullRect, startCenter, cp1, cp2, endCenter)) {
          continue;
        }

        final lut = getLut(p0, cp1, cp2, p3);
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
      final start = getQuestCenter(connectionSourceId!, questSystem, currentDraggedQuestId, currentDraggedQuestPos);
      if (start != null) {
        _drawConnectionPreview(canvas, start, connectionPreviewEnd!, glowColorOfQuest(connectionSourceId!), connectionSourceId!);
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
      ArcLut lut,
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
      final pos = bezierPoint(p0, p1, p2, p3, t);

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



  Offset _bezierTangent(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final mt = 1.0 - t;
    return (p1 - p0) * (3 * mt * mt) +
        (p2 - p1) * (6 * mt * t) +
        (p3 - p2) * (3 * t * t);
  }



  void _drawConnectionPreview(Canvas canvas, Offset start, Offset end, Color color, int connectionId) {

    final pixelOffset = animation.value * pixelSpacing;
    final showArrows = scale >= arrowHideScale;
    final cullRect = viewportRect?.inflate(_cullPadding());
    
    final anchorStart = getBestAnchor(connectionId, end, questSystem, currentDraggedQuestId, currentDraggedQuestPos);
    final anchorEnd = Anchor(end, ui.Offset.zero);

    final cps = calculateCubicControlPoints(
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

    final lut = getLut(p0, cp1, cp2, p3);
    _drawBorderLine(canvas, p0, cp1, cp2, p3);
    _drawBaseLine(canvas, p0, cp1, cp2, p3, color, color);

    if (showArrows) {
      _drawMarchingArrows(
        canvas, p0, cp1, cp2, p3,
        lut, pixelOffset, color, color, cullRect,
      );
    }
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


Color glowColorOfQuest(int id) {
  if (glowColors.containsKey(id)) return glowColors[id]!;
  final hsl = HSLColor.fromColor(getColorFromSeed(id));
  final color = hsl.withLightness(0.65).withSaturation(0.75).toColor();
  return glowColors[id] = color;
}

Map<int, Color> glowColors = {};

