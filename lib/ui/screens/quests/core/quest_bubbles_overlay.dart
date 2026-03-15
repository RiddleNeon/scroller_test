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
  late final QuestLineConnectionPainter _connectionPainter;
  late Size _worldBounds;

  int? _draggedQuestId;
  Offset? _draggedQuestPos;

  @override
  void initState() {
    super.initState();
    _connectionPainter = QuestLineConnectionPainter();
    _worldBounds = _computeWorldBounds();
  }

  void setDragState({required int? questId, required Offset? position}) {
    setState(() {
      _draggedQuestId = questId;
      _draggedQuestPos = position;
      _connectionPainter
        ..currentDraggedQuestId = questId
        ..currentDraggedQuestPos = position;
    });
  }

  void refresh() => setState(() {});

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
            painter: _connectionPainter,
          ),
          for (final quest in QuestSystem.quests.values)
            _positionedBubble(quest),
        ],
      ),
    );
  }

  Widget _positionedBubble(Quest quest) {
    final isDragged = quest.id == _draggedQuestId && _draggedQuestPos != null;

    return Positioned(
      left: isDragged ? _draggedQuestPos!.dx : quest.posX,
      top: isDragged ? _draggedQuestPos!.dy : quest.posY,
      child: QuestBubble(quest: quest),
    );
  }

  Size _computeWorldBounds() {
    double maxX = 0, maxY = 0;
    for (final quest in QuestSystem.quests.values) {
      if (quest.posX + quest.sizeX > maxX) maxX = quest.posX + quest.sizeX;
      if (quest.posY + quest.sizeY > maxY) maxY = quest.posY + quest.sizeY;
    }
    return Size(maxX, maxY);
  }
}