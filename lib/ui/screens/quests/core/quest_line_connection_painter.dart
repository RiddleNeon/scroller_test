import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:wurp/logic/quests/quest_system.dart';

import 'quest_bubble.dart';

class QuestLineConnectionPainter extends CustomPainter {
  int?   currentDraggedQuestId;
  Offset? currentDraggedQuestPos;
  
  
  int?   connectionSourceId;
  Offset? connectionPreviewEnd;
  
  static final _repaintNotifier = ValueNotifier<int>(0);

  QuestLineConnectionPainter() : super(repaint: _repaintNotifier);

  void triggerRepaint() => _repaintNotifier.value++;

  @override
  void paint(Canvas canvas, Size size) {
    for (final quest in questSystem.quests) {
      if (questSystem.prerequisitesOf(quest.id).isEmpty) continue;

      final startCenter = _centerOf(quest.id);
      final questColor  = glowColorOfQuest(quest.id);

      for (final prereq in questSystem.prerequisitesOf(quest.id)) {
        final endCenter  = _centerOf(prereq.id);
        final prereqColor = glowColorOfQuest(prereq.id);

        if (startCenter == null || endCenter == null) continue;

        final curveControl = _curveControl(startCenter, endCenter);

        final path = Path()
          ..moveTo(startCenter.dx, startCenter.dy)
          ..quadraticBezierTo(
              curveControl.dx, curveControl.dy, endCenter.dx, endCenter.dy);

        canvas.drawPath(
          path,
          Paint()
            ..shader = ui.Gradient.linear(
              startCenter, endCenter,
              [questColor.withValues(alpha: 0.65), prereqColor.withValues(alpha: 0.65)],
            )
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
      }
    }

    if (connectionSourceId != null && connectionPreviewEnd != null) {
      final start = _centerOf(connectionSourceId!);
      if (start != null) {
        _drawConnectionPreview(canvas, start, connectionPreviewEnd!,
            glowColorOfQuest(connectionSourceId!));
      }
    }
  }

  void _drawConnectionPreview(Canvas canvas, Offset start, Offset end, Color color) {
    final delta = end - start;
    final len   = delta.distance;
    if (len < 1) return;

    final dir = delta / len;

    final linePaint = Paint()
      ..color      = color.withValues(alpha: 0.90)
      ..strokeWidth = 2.0
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    const dashLen = 9.0;
    const gapLen  = 5.0;
    double drawn = 0;
    while (drawn < len) {
      final segEnd = (drawn + dashLen).clamp(0.0, len);
      canvas.drawLine(start + dir * drawn, start + dir * segEnd, linePaint);
      drawn += dashLen + gapLen;
    }

    const arrowSize = 9.0;
    final perp = Offset(-dir.dy, dir.dx);
    final tip   = end;
    final left  = end - dir * arrowSize + perp * (arrowSize * 0.45);
    final right = end - dir * arrowSize - perp * (arrowSize * 0.45);

    final arrowPath = Path()
      ..moveTo(tip.dx,   tip.dy)
      ..lineTo(left.dx,  left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = color.withValues(alpha: 0.90)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      start,
      5,
      Paint()
        ..color    = color.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      start,
      3.5,
      Paint()..color = color.withValues(alpha: 0.95),
    );
  }

  Offset? _centerOf(int id) {
    final quest = questSystem.maybeGetQuestById(id);
    if (quest == null) return null;

    final pos = (id == currentDraggedQuestId && currentDraggedQuestPos != null)
        ? currentDraggedQuestPos!
        : quest.position;
    return pos + Offset(quest.sizeX, quest.sizeY) / 2;
  }

  Offset _curveControl(Offset a, Offset b) {
    final mid    = (a + b) / 2;
    final delta  = b - a;
    final perp   = Offset(-delta.dy, delta.dx);
    final perpLen = perp.distance;
    if (perpLen < 1) return mid;
    return mid + (perp / perpLen) * (delta.distance * 0.12);
  }

  @override
  bool shouldRepaint(covariant QuestLineConnectionPainter old) =>
      old.currentDraggedQuestId   != currentDraggedQuestId   ||
          old.currentDraggedQuestPos  != currentDraggedQuestPos  ||
          old.connectionSourceId      != connectionSourceId      ||
          old.connectionPreviewEnd    != connectionPreviewEnd;
}


Color glowColorOfQuest(int id) {
  if (glowColors.containsKey(id)) return glowColors[id]!;

  final hsl   = HSLColor.fromColor(getColorFromSeed(id));
  final color = hsl.withLightness(0.65).withSaturation(0.75).toColor();
  return glowColors[id] = color;
}

Map<int, Color> glowColors = {};