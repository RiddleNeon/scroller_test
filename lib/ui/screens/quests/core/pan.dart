// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:wurp/logic/quests/quest_system.dart';
import 'package:wurp/ui/screens/quests/core/quest_bubbles_overlay.dart';

import '../../../../logic/quests/quest.dart';
import '../debug_panel.dart';
import 'pan_background.dart';

class PanWidget extends StatefulWidget {
  const PanWidget({super.key, this.controller});

  final TransformationController? controller;

  @override
  State<PanWidget> createState() => PanWidgetState();
}

class PanWidgetState extends State<PanWidget> {
  late final TransformationController _controller = widget.controller ?? TransformationController();

  final _overlayKey = GlobalKey<QuestBubblesOverlayState>();
  final _debugPanelKey = GlobalKey<QuestDebugPanelState>();

  Quest? _draggingQuest;
  Offset _dragStartQuestPos = Offset.zero;
  Offset _focalDelta = Offset.zero;

  // Track last pointer-down position so the double-tap handler can resolve it
  // to a scene coordinate (GestureDetector.onDoubleTap doesn't give a position).
  Offset _lastPointerScenePos = Offset.zero;

  double get _currentScale => _controller.value.getMaxScaleOnAxis();

  String toJson() => QuestSystem.toJson();

  Quest? _findQuestAt(Offset scenePos) {
    for (final quest in QuestSystem.quests.values) {
      if (quest.rect.contains(scenePos)) return quest;
    }
    return null;
  }

  void _onScaleStart(ScaleStartDetails details) {
    _focalDelta = Offset.zero;
    final scenePos = _controller.toScene(details.localFocalPoint);
    _lastPointerScenePos = scenePos;

    _draggingQuest = _findQuestAt(scenePos);
    _dragStartQuestPos = _draggingQuest?.position ?? Offset.zero;

    _overlayKey.currentState?.setDragState(questId: _draggingQuest?.id, position: _draggingQuest != null ? _dragStartQuestPos : null);
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    _focalDelta += details.focalPointDelta;
    final currentScale = _currentScale;

    if (_draggingQuest != null) {
      final newPos = _dragStartQuestPos + (_focalDelta / currentScale);
      _overlayKey.currentState?.setDragState(questId: _draggingQuest!.id, position: newPos);
      return;
    }

    final matrix = _controller.value.clone()..translate(details.focalPointDelta.dx / currentScale, details.focalPointDelta.dy / currentScale);
    _controller.value = matrix;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_draggingQuest != null) {
      final currentScale = _currentScale;
      QuestSystem.moveQuest(_draggingQuest!.id, _draggingQuest!.posX + (_focalDelta.dx / currentScale), _draggingQuest!.posY + (_focalDelta.dy / currentScale));
    }
    _overlayKey.currentState?.setDragState(questId: null, position: null);
    setState(() => _draggingQuest = null);
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _lastPointerScenePos = _controller.toScene(details.localPosition);
  }

  void _onDoubleTap() {
    final quest = _findQuestAt(_lastPointerScenePos);
    if (quest == null) return;
    _debugPanelKey.currentState?.inspectQuest(quest.id);
  }

  void _focusOnQuest(Quest quest) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final viewSize = renderBox.size;
    final scale = _currentScale;

    final targetX = -(quest.posX * scale) + viewSize.width / 2 - (quest.sizeX * scale / 2);
    final targetY = -(quest.posY * scale) + viewSize.height / 2 - (quest.sizeY * scale / 2);

    _controller.value = Matrix4.identity()
      ..scale(scale)
      ..translate(targetX / scale, targetY / scale);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFF0A1218)),
        child: Stack(
          children: [
            Positioned.fill(child: InfiniteDotsBackground(controller: _controller)),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.15,
                      colors: [Colors.transparent, const Color(0xFF0A1218).withValues(alpha: 0.72)],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _controller,
                panEnabled: false,
                scaleEnabled: true,
                minScale: 0.1,
                maxScale: 30.0,
                boundaryMargin: const EdgeInsets.all(1800),
                child: QuestBubblesOverlay(key: _overlayKey),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                onDoubleTapDown: _onDoubleTapDown,
                onDoubleTap: _onDoubleTap,
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
            QuestDebugPanel(key: _debugPanelKey, onChanged: () => _overlayKey.currentState?.refresh(), onFocusQuest: _focusOnQuest),
          ],
        ),
      ),
    );
  }
}

class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.fromColor, this.flip = false});

  final Color fromColor;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: flip ? Alignment.bottomCenter : Alignment.topCenter,
            end: flip ? Alignment.topCenter : Alignment.bottomCenter,
            colors: [fromColor.withValues(alpha: 0.85), fromColor.withValues(alpha: 0.0)],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
