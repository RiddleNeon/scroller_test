import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:wurp/logic/quests/quest_system.dart';
import 'quest_bubble.dart';

class QuestLineConnectionPainter extends CustomPainter {
  int? currentDraggedQuestId;
  Offset? currentDraggedQuestPos;

  @override
  void paint(Canvas canvas, Size size) {
    for (final quest in QuestSystem.quests.values) {
      if (quest.prerequisites.isEmpty) continue;

      final startPos = quest.id == currentDraggedQuestId
          ? currentDraggedQuestPos!
          : Offset(quest.posX, quest.posY);
      final startCenter = startPos + Offset(quest.sizeX, quest.sizeY) / 2;

      final questColor = _glowColor(quest.id);

      for (final prereq in quest.prerequisites) {
        final endPos = prereq.id == currentDraggedQuestId
            ? currentDraggedQuestPos!
            : Offset(prereq.posX, prereq.posY);
        final endCenter = endPos + Offset(prereq.sizeX, prereq.sizeY) / 2;

        final prereqColor = _glowColor(prereq.id);

        final controlPoint = _curveControl(startCenter, endCenter);

        final path = Path()
          ..moveTo(startCenter.dx, startCenter.dy)
          ..quadraticBezierTo(
              controlPoint.dx, controlPoint.dy, endCenter.dx, endCenter.dy);

        final linePaint = Paint()
          ..shader = ui.Gradient.linear(
            startCenter,
            endCenter,
            [
              questColor.withValues(alpha: 0.65),
              prereqColor.withValues(alpha: 0.65),
            ],
          )
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawPath(path, linePaint);
      }
    }
  }

  Color _glowColor(int id) {
    final base = getColorFromSeed(id);
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness(0.65).withSaturation(0.75).toColor();
  }

  Offset _curveControl(Offset a, Offset b) {
    final mid = (a + b) / 2;
    final delta = b - a;
    final perp = Offset(-delta.dy, delta.dx);
    final perpLen = perp.distance;
    if (perpLen < 1) return mid;
    return mid + (perp / perpLen) * (delta.distance * 0.12);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}