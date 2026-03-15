// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:wurp/logic/quests/quest_system.dart';
import 'package:wurp/ui/screens/quests/core/quest_bubbles_overlay.dart';
import '../../../../logic/quests/quest.dart';
import 'pan_background.dart';

class PanWidget extends StatefulWidget {
  final Widget child;
  final TransformationController? controller;

  const PanWidget({
    super.key,
    required this.child,
    this.controller,
  });

  @override
  State<PanWidget> createState() => _PanWidgetState();
}

class _PanWidgetState extends State<PanWidget> {
  late final TransformationController _controller =
      widget.controller ?? TransformationController();
  final _overlayKey = GlobalKey<QuestBubblesOverlayState>();
  Quest? _draggingQuest;
  double _lastScale = 1.0;
  Offset _focalDelta = Offset.zero;

  Quest? _findQuestAt(Offset scenePos) {
    for (final quest in QuestSystem.quests.values) {
      final rect = Rect.fromLTWH(quest.posX, quest.posY, quest.sizeX, quest.sizeY);
      if (rect.contains(scenePos)) return quest;
    }
    return null;
  }

  void _onScaleStart(ScaleStartDetails details) {
    _lastScale = 1.0;
    _focalDelta = Offset.zero;
    final scenePos = _controller.toScene(details.localFocalPoint);
    _draggingQuest = _findQuestAt(scenePos);

    _overlayKey.currentState
      ?..connectionPainter.currentDraggedQuestId = _draggingQuest?.id
      ..connectionPainter.currentDraggedQuestPos = _draggingQuest?.position
      ..currentlyDraggedQuestId = _draggingQuest?.id
      ..currentlyDraggedQuestPos =
          (_draggingQuest?.position ?? Offset.zero) / _lastScale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    _focalDelta += details.focalPointDelta;

    _overlayKey.currentState
      ?..currentlyDraggedQuestPos =
          (_draggingQuest?.position ?? Offset.zero) / _lastScale + _focalDelta
      ..connectionPainter.currentDraggedQuestPos =
          (_draggingQuest?.position ?? Offset.zero) / _lastScale + _focalDelta;

    if (_draggingQuest != null) {
      _draggingQuest = QuestSystem.quests[_draggingQuest!.id];
      _overlayKey.currentState?.refresh();
      return;
    }

    final matrix = _controller.value.clone();
    matrix.translate(details.focalPointDelta.dx, details.focalPointDelta.dy);

    if (details.scale != 1.0) {
      final scaleChange = details.scale / _lastScale;
      final fp = details.localFocalPoint;
      matrix.translate(fp.dx, fp.dy);
      matrix.scale(scaleChange);
      matrix.translate(-fp.dx, -fp.dy);
      _lastScale = details.scale;
    }

    _controller.value = matrix;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _overlayKey.currentState
      ?..connectionPainter.currentDraggedQuestId = null
      ..connectionPainter.currentDraggedQuestPos = null
      ..currentlyDraggedQuestId = null
      ..currentlyDraggedQuestPos = null;

    if (_draggingQuest != null) {
      final currentScale = _controller.value.getMaxScaleOnAxis();
      QuestSystem.moveQuest(
        _draggingQuest!.id,
        _draggingQuest!.posX + _focalDelta.dx / currentScale,
        _draggingQuest!.posY + _focalDelta.dy / currentScale,
      );
    }

    setState(() => _draggingQuest = null);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFF0A1218)),
        child: Stack(
          children: [
            Positioned.fill(
              child: InfiniteDotsBackground(controller: _controller),
            ),

            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.15,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF0A1218).withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            InteractiveViewer(
              transformationController: _controller,
              panEnabled: false,
              scaleEnabled: false,
              minScale: 0.1,
              maxScale: 30.0,
              boundaryMargin: const EdgeInsets.all(1800),
              child: QuestBubblesOverlay(key: _overlayKey),
            ),

            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
              ),
            ),

            const Positioned.fill(
              child: IgnorePointer(
                child: Column(
                  children: [
                    _EdgeFade(fromColor: Color(0xFF0A1218)),
                    Spacer(),
                    _EdgeFade(fromColor: Color(0xFF0A1218), flip: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _EdgeFade extends StatelessWidget {
  final Color fromColor;
  final bool flip;

  const _EdgeFade({required this.fromColor, this.flip = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: flip ? Alignment.bottomCenter : Alignment.topCenter,
            end: flip ? Alignment.topCenter : Alignment.bottomCenter,
            colors: [
              fromColor.withValues(alpha: 0.85),
              fromColor.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}