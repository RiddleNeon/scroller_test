import 'dart:ui';

import 'package:wurp/logic/quests/quest_system.dart';

Offset bezierPoint(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
  final mt = 1.0 - t;
  return p0 * (mt * mt * mt) +
      p1 * (3 * mt * mt * t) +
      p2 * (3 * mt * t * t) +
      p3 * (t * t * t);
}


List<Offset> calculateCubicControlPointsOffsetting(
    Offset pStart, Offset dirStart,
    Offset pEnd, Offset dirEnd,
    int sourceId, int targetId,
    QuestSystem questSystem,
    Offset? currentDraggedQuestPos,
    int? currentDraggedQuestId
    ) {
  final delta = pEnd - pStart;
  final dist = delta.distance;
  final tension = (dist * 0.4).clamp(30.0, 200.0);

  Offset cp1 = pStart + dirStart * tension;
  Offset cp2 = pEnd + dirEnd * tension;

  final int lowId = sourceId < targetId ? sourceId : targetId;
  final int highId = sourceId < targetId ? targetId : sourceId;

  final pLow = getQuestCenter(lowId, questSystem, currentDraggedQuestId, currentDraggedQuestPos)!;
  final pHigh = getQuestCenter(highId, questSystem, currentDraggedQuestId, currentDraggedQuestPos)!;
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

List<Offset> calculateCubicControlPoints(Offset pStart, Offset dirStart, Offset pEnd, Offset dirEnd) {
  final dist = (pEnd - pStart).distance;
  final tension = (dist * 0.4).clamp(30.0, 200.0);

  return [
    pStart + dirStart * tension,
    pEnd + dirEnd * tension,
  ];
}


class Anchor {
  final Offset pos;
  final Offset sideDir;
  Anchor(this.pos, this.sideDir);
}

Anchor getBestAnchor(int id, Offset targetCenter, QuestSystem questSystem, int? currentDraggedQuestId, Offset? currentDraggedQuestPos) {
  final quest = questSystem.maybeGetQuestById(id);
  if (quest == null) return Anchor(Offset.zero, Offset.zero);

  final pos = (id == currentDraggedQuestId && currentDraggedQuestPos != null)
      ? currentDraggedQuestPos
      : quest.position;

  final double w = quest.sizeX;
  final double h = quest.sizeY;
  final Offset center = pos + Offset(w / 2, h / 2);

  final dx = targetCenter.dx - center.dx;
  final dy = targetCenter.dy - center.dy;


  if ((dx / w).abs() > (dy / h).abs()) {
    if (dx > 0) {
      return Anchor(Offset(pos.dx + w, center.dy), const Offset(1, 0));
    } else {
      return Anchor(Offset(pos.dx, center.dy), const Offset(-1, 0));
    }
  } else {
    if (dy > 0) {
      return Anchor(Offset(center.dx, pos.dy + h), const Offset(0, 1));
    } else {
      return Anchor(Offset(center.dx, pos.dy), const Offset(0, -1));
    }
  }
}

Offset? getQuestCenter(int id, QuestSystem questSystem, int? currentDraggedQuestId, Offset? currentDraggedQuestPos) {
  final quest = questSystem.maybeGetQuestById(id);
  if (quest == null) return null;
  final pos = (id == currentDraggedQuestId && currentDraggedQuestPos != null)
      ? currentDraggedQuestPos
      : quest.position;
  return pos + Offset(quest.sizeX, quest.sizeY) / 2;
}