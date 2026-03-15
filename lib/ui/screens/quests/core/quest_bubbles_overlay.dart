import 'package:flutter/material.dart';
import 'package:wurp/logic/quests/quest.dart';
import 'package:wurp/logic/quests/quest_system.dart';
import 'package:wurp/ui/screens/quests/core/quest_line_connection_painter.dart';

import 'quest_bubble.dart';

class QuestBubblesOverlay extends StatefulWidget {
  const QuestBubblesOverlay({super.key});

  @override
  State<QuestBubblesOverlay> createState() => QuestBubblesOverlayState();
}

class QuestBubblesOverlayState extends State<QuestBubblesOverlay> {
  late final QuestLineConnectionPainter connectionPainter;
  late Size _worldBounds;

  bool editMode = false;

  Offset? currentlyDraggedQuestPos;
  int? currentlyDraggedQuestId;

  void refresh() => setState(() {});

  @override
  void initState() {
    super.initState();
    connectionPainter = QuestLineConnectionPainter();
    _worldBounds = _computeWorldBounds();
  }

  @override
  Widget build(BuildContext context) {
    const padding = 500.0;

    return SizedBox(
      width: _worldBounds.width + padding,
      height: _worldBounds.height + padding,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: _worldBounds,
            painter: connectionPainter,
          ),

          for (final quest in QuestSystem.quests.values)
            _positionedBubble(quest),
        ],
      ),
    );
  }

  Widget _positionedBubble(Quest quest) {
    final isDragged = quest.id == currentlyDraggedQuestId &&
        currentlyDraggedQuestPos != null;

    final left = isDragged ? currentlyDraggedQuestPos!.dx : quest.posX;
    final top  = isDragged ? currentlyDraggedQuestPos!.dy : quest.posY;

    return Positioned(
      left: left,
      top: top,
      child: QuestBubble(quest: quest),
    );
  }

  Size _computeWorldBounds() {
    double maxX = 0, maxY = 0;
    for (final quest in QuestSystem.quests.values) {
      if (quest.posX > maxX) maxX = quest.posX;
      if (quest.posY > maxY) maxY = quest.posY;
    }
    return Size(maxX, maxY);
  }
}