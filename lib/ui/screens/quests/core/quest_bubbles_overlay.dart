import 'package:flutter/material.dart';
import 'package:wurp/logic/quests/quest.dart';
import 'package:wurp/logic/quests/quest_system.dart';
import 'package:wurp/ui/screens/quests/core/quest_line_connection_painter.dart';

import 'quest_bubble.dart';

class QuestBubblesOverlay extends StatefulWidget {
  final bool debugMode;
  final QuestSystem questSystem;
  const QuestBubblesOverlay({super.key, required this.debugMode, required this.questSystem});

  @override
  State<QuestBubblesOverlay> createState() => QuestBubblesOverlayState();
}

class QuestBubblesOverlayState extends State<QuestBubblesOverlay> {
  late final QuestLineConnectionPainter _connectionPainter;
  late Size _worldBounds;
  
  QuestSystem get questSystem => widget.questSystem;

  final _dragNotifier = ValueNotifier<({int? id, Offset? pos})>(
    (id: null, pos: null),
  );

  final _connectionNotifier =
  ValueNotifier<({int? sourceId, int? targetId, Offset? previewPos})>(
    (sourceId: null, targetId: null, previewPos: null),
  );

  @override
  void initState() {
    super.initState();
    _connectionPainter = QuestLineConnectionPainter(questSystem: questSystem);
    _worldBounds = _computeWorldBounds();
    questSystem.addListener(revalidateWorldBounds);
  }
  
  


  void setDragState({required int? questId, required Offset? position}) {
    _dragNotifier.value = (id: questId, pos: position);
    _connectionPainter
      ..currentDraggedQuestId  = questId
      ..currentDraggedQuestPos = position;
    _connectionPainter.triggerRepaint();
  }
  
  void setConnectionState({
    required int?    sourceId,
    required int?    targetId,
    required Offset? previewPos,
  }) {
    _connectionNotifier.value =
    (sourceId: sourceId, targetId: targetId, previewPos: previewPos);
    _connectionPainter
      ..connectionSourceId   = sourceId
      ..connectionPreviewEnd = previewPos;
    _connectionPainter.triggerRepaint();
  }

  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    const padding = 500.0;

    return SizedBox(
      width:  _worldBounds.width  + padding,
      height: _worldBounds.height + padding,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(size: _worldBounds, painter: _connectionPainter),
          for (final quest in questSystem.quests) _positionedBubble(quest),
        ],
      ),
    );
  }


  Widget _positionedBubble(Quest quest) {
    return ValueListenableBuilder(
      valueListenable: _dragNotifier,
      builder: (context, drag, _) {
        final isDragged = quest.id == drag.id && drag.pos != null;

        return ValueListenableBuilder(
          valueListenable: _connectionNotifier,
          builder: (context, conn, _) {
            return Positioned(
              left: isDragged ? drag.pos!.dx : quest.posX,
              top:  isDragged ? drag.pos!.dy : quest.posY,
              child: QuestBubble(
                quest: quest,
                isConnectionSource: conn.sourceId == quest.id,
                isConnectionTarget: conn.targetId == quest.id,
                debugMode: widget.debugMode,
              ),
            );
          },
        );
      },
    );
  }

  Size _computeWorldBounds() {
    double maxX = 0, maxY = 0;
    for (final quest in questSystem.quests) {
      if (quest.posX + quest.sizeX > maxX) maxX = quest.posX + quest.sizeX;
      if (quest.posY + quest.sizeY > maxY) maxY = quest.posY + quest.sizeY;
    }
    return Size(maxX, maxY);
  }
  
  void revalidateWorldBounds() {
    final newBounds = _computeWorldBounds();
    if (newBounds != _worldBounds) {
      setState(() => _worldBounds = newBounds);
    }
  }

  @override
  void dispose() {
    _dragNotifier.dispose();
    _connectionNotifier.dispose();
    questSystem.removeListener(revalidateWorldBounds);
    super.dispose();
  }
}