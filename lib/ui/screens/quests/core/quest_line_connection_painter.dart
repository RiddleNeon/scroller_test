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

      final startCenter = _centerOf(quest.id);
      final questColor = glowColorOfQuest(quest.id);

      for (final prereq in quest.prerequisites) {
        final endCenter = _centerOf(prereq.id);
        final prereqColor = glowColorOfQuest(prereq.id);

        final curveControl = _curveControl(startCenter, endCenter);

        final path = Path()
          ..moveTo(startCenter.dx, startCenter.dy)
          ..quadraticBezierTo(curveControl.dx, curveControl.dy, endCenter.dx, endCenter.dy);

        canvas.drawPath(
          path,
          Paint()
            ..shader = ui.Gradient.linear(startCenter, endCenter, [questColor.withValues(alpha: 0.65), prereqColor.withValues(alpha: 0.65)])
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  Offset _centerOf(int id) {
    if (id == currentDraggedQuestId && currentDraggedQuestPos != null) {
      final quest = QuestSystem.quests[id]!;
      return currentDraggedQuestPos! + Offset(quest.sizeX, quest.sizeY) / 2;
    }
    final quest = QuestSystem.quests[id]!;
    return quest.position + Offset(quest.sizeX, quest.sizeY) / 2;
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
  bool shouldRepaint(covariant QuestLineConnectionPainter old) =>
      old.currentDraggedQuestId != currentDraggedQuestId ||
          old.currentDraggedQuestPos != currentDraggedQuestPos;
}

Color glowColorOfQuest(int id) {
  if(glowColors.containsKey(id)) return glowColors[id]!;

  final hsl = HSLColor.fromColor(getColorFromSeed(id));
  final color = hsl.withLightness(0.65).withSaturation(0.75).toColor();
  return glowColors[id] = color;
}

Map<int, Color> glowColors = {};