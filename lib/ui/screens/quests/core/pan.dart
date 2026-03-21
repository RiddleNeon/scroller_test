// ignore_for_file: deprecated_member_use

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' hide Matrix4, Colors;
import 'package:wurp/logic/quests/quest_change_manager.dart';
import 'package:wurp/logic/quests/quest_system.dart';
import 'package:wurp/logic/repositories/quest_repository.dart';
import 'package:wurp/ui/screens/quests/core/quest_bubbles_overlay.dart';
import 'package:wurp/ui/screens/quests/core/quest_detail_screen.dart';

import '../../../../logic/quests/quest.dart';
import '../debug_panel.dart';
import 'pan_background.dart';
import 'quest_bubble.dart';

class PanWidget extends StatefulWidget {
  const PanWidget({super.key, this.controller});

  final TransformationController? controller;

  @override
  State<PanWidget> createState() => PanWidgetState();
}

class PanWidgetState extends State<PanWidget> {
  late final TransformationController _controller = widget.controller ?? TransformationController();

  bool debugMode = false;

  final _questBubbleOverlayKey = GlobalKey<QuestBubblesOverlayState>();
  final _debugPanelKey = GlobalKey<QuestDebugPanelState>();

  Quest? _draggingQuest;
  Offset _dragStartQuestPos = Offset.zero;
  Offset _focalDelta = Offset.zero;

  bool _isConnecting = false;
  Quest? _connectingFromQuest;
  Offset _lastConnectionScene = Offset.zero;

  double _scaleAtGestureStart = 1.0;
  double _txAtGestureStart = 0.0;
  double _tyAtGestureStart = 0.0;
  Offset _focalAtGestureStart = Offset.zero;

  Offset _lastPointerScenePos = Offset.zero;

  double get _currentScale => _controller.value.getMaxScaleOnAxis();

  Quest? _findQuestAt(Offset scenePos) {
    for (final quest in questSystem.quests) {
      if (quest.rect.contains(scenePos)) return quest;
    }
    return null;
  }

  Quest? _findQuestInConnectZone(Offset scenePos) {
    const hitRadius = kConnectionHandleRadius * 1.6;
    for (final quest in questSystem.quests) {
      final handleCenter = Offset(quest.posX + quest.sizeX, quest.posY + quest.sizeY / 2);
      if ((scenePos - handleCenter).distance <= hitRadius) return quest;
    }
    return null;
  }

  @override
  void initState() {
    questSystem.addListener(revalidateBoundaries);
    revalidateBoundaries();
    super.initState();
  }

  @override
  void dispose() {
    questSystem.removeListener(revalidateBoundaries);
    super.dispose();
  }

  Offset _boundaryMax = Offset.zero;
  Offset _boundaryMin = Offset.zero;
  static const double _boundaryPadding = 20.0;

  void revalidateBoundaries() {
    if (!mounted) return;

    if (questSystem.quests.isEmpty) {
      setState(() {
        _boundaryMax = const Offset(_boundaryPadding, _boundaryPadding);
        _boundaryMin = const Offset(-_boundaryPadding, -_boundaryPadding);
      });
      return;
    }

    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;
    double minX = double.infinity;
    double minY = double.infinity;
    for (final quest in questSystem.quests) {
      if (quest.posX > maxX) maxX = quest.posX;
      if (quest.posY > maxY) maxY = quest.posY;
      if (quest.posX < minX) minX = quest.posX;
      if (quest.posY < minY) minY = quest.posY;
    }

    setState(() {
      _boundaryMax = Offset(maxX + _boundaryPadding, maxY + _boundaryPadding);
      _boundaryMin = Offset(minX - _boundaryPadding, minY - _boundaryPadding);
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _focalDelta = Offset.zero;
    _scaleAtGestureStart = _currentScale;
    _txAtGestureStart = _controller.value.entry(0, 3);
    _tyAtGestureStart = _controller.value.entry(1, 3);
    _focalAtGestureStart = details.localFocalPoint;

    final scenePos = _controller.toScene(details.localFocalPoint);
    _lastPointerScenePos = scenePos;

    final connectQuest = _findQuestInConnectZone(scenePos);
    if (connectQuest != null) {
      _isConnecting = true;
      _connectingFromQuest = connectQuest;
      _lastConnectionScene = scenePos;
      _questBubbleOverlayKey.currentState?.setConnectionState(sourceId: connectQuest.id, targetId: null, previewPos: scenePos);
      return;
    }

    _draggingQuest = _findQuestAt(scenePos);
    _dragStartQuestPos = _draggingQuest?.position ?? Offset.zero;

    _questBubbleOverlayKey.currentState?.setDragState(questId: _draggingQuest?.id, position: _draggingQuest != null ? _dragStartQuestPos : null);
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    _focalDelta += details.focalPointDelta;

    if (_isConnecting && _connectingFromQuest != null) {
      final scenePos = _controller.toScene(details.localFocalPoint);
      _lastConnectionScene = scenePos;

      final hoveredQuest = _findQuestAt(scenePos);
      final targetId = (hoveredQuest != null && hoveredQuest.id != _connectingFromQuest!.id) ? hoveredQuest.id : null;

      _questBubbleOverlayKey.currentState?.setConnectionState(sourceId: _connectingFromQuest!.id, targetId: targetId, previewPos: scenePos);
      return;
    }

    if (_draggingQuest != null) {
      final currentScale = _currentScale;
      final newPos = _dragStartQuestPos + (_focalDelta / currentScale);
      _questBubbleOverlayKey.currentState?.setDragState(questId: _draggingQuest!.id, position: newPos);
      return;
    }

    final s = (_scaleAtGestureStart * details.scale).clamp(minScale, maxScale);

    var tx = details.localFocalPoint.dx - s * (_focalAtGestureStart.dx - _txAtGestureStart) / _scaleAtGestureStart;
    var ty = details.localFocalPoint.dy - s * (_focalAtGestureStart.dy - _tyAtGestureStart) / _scaleAtGestureStart;

    (tx, ty) = _clampTranslation(tx, ty, s);

    _controller.value = Matrix4.identity()
      ..scale(s)
      ..setTranslation(Vector3(tx, ty, 0));
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_isConnecting && _connectingFromQuest != null) {
      final targetQuest = _findQuestAt(_lastConnectionScene);
      if (targetQuest != null && targetQuest.id != _connectingFromQuest!.id) {
        _addConnection(sourceId: _connectingFromQuest!.id, targetId: targetQuest.id);
      }
      _isConnecting = false;
      _connectingFromQuest = null;
      _questBubbleOverlayKey.currentState?.setConnectionState(sourceId: null, targetId: null, previewPos: null);
      return;
    }

    if (_draggingQuest != null) {
      final currentScale = _currentScale;

      final before = _draggingQuest!.copyWith();
      final after = _draggingQuest!.copyWith(
          posX: _dragStartQuestPos.dx + (_focalDelta.dx / currentScale),
          posY: _dragStartQuestPos.dy + (_focalDelta.dy / currentScale)      
      );

      changeManager.record(UpdateQuestChange(before: before, after: after, updateMessage: 'moved quest'));
      questSystem.upsertQuest(after);
    }
    _questBubbleOverlayKey.currentState?.setDragState(questId: null, position: null);
    setState(() => _draggingQuest = null);
  }

  void _addConnection({required int sourceId, required int targetId}) {
    final target = questSystem.maybeGetQuestById(targetId);
    if (target == null || questSystem.prerequisitesOf(targetId).any((p) => p.id == sourceId)) {
      return;
    }

    try {
      changeManager.record(AddConnectionChange(fromId: targetId, toId: sourceId, updateMessage: 'connection drawn'));
      changeManager.push(); //fixme
    } catch (e) {
      questSystem.addConnection(targetId, sourceId);
      questRepo.addConnection(targetId, sourceId);
    }
    _questBubbleOverlayKey.currentState?.refresh();
  }

  void _onPointerScroll(PointerScrollEvent event) {
    if (_draggingQuest != null || _isConnecting) return;

    const zoomSensitivity = 0.0010;

    final currentScale = _currentScale;
    final newScale = (currentScale * (1.0 - event.scrollDelta.dy * zoomSensitivity)).clamp(minScale, maxScale);

    final currentTx = _controller.value.entry(0, 3);
    final currentTy = _controller.value.entry(1, 3);
    final focal = event.localPosition;

    var tx = focal.dx - newScale * (focal.dx - currentTx) / currentScale;
    var ty = focal.dy - newScale * (focal.dy - currentTy) / currentScale;

    (tx, ty) = _clampTranslation(tx, ty, newScale);

    _controller.value = Matrix4.identity()
      ..scale(newScale)
      ..setTranslation(Vector3(tx, ty, 0));
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _lastPointerScenePos = _controller.toScene(details.localPosition);
  }

  void _onDoubleTap() {
    final quest = _findQuestAt(_lastPointerScenePos);
    if (quest == null) {
      showQuestAddOverlay(_lastPointerScenePos);
      return;
    }
    _debugPanelKey.currentState?.inspectQuest(quest.id);
  }

  void _onTap() {
    final quest = _findQuestAt(_lastPointerScenePos);
    if (quest == null) return;
    showDialog(
      context: context,
      builder: (context) => FractionallySizedBox(
        widthFactor: 0.8,
        heightFactor: 0.8,
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: QuestDetailScreen(
            quest: quest,
            debugMode: debugMode,
            editMode: false,
            onDoneEditing: (updatedQuest, [changeMessage]) async {
              changeManager.record(UpdateQuestChange(
                before: quest,
                after: updatedQuest,
                updateMessage: changeMessage ?? 'no message provided',
              ));
              if (context.mounted) Navigator.of(context).pop();
            },
            onDelete: (q) async {
              await questRepo.deleteQuest(q);
              changeManager.record(DeleteQuestChange(quest: q));
              if(context.mounted) Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  void showQuestAddOverlay(Offset scenePos) {
    showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: FractionallySizedBox(
            widthFactor: 0.9,
            heightFactor: 0.9,
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: QuestDetailScreen(
                quest: Quest(id: DateTime.now().millisecondsSinceEpoch, name: 'No name provided', description: 'No description provided', subject: 'General'),
                debugMode: true,
                editMode: true,
                recommendedChangeMessage: 'Initial version',
                onDoneEditing: (Quest updatedQuest, [String? changeMessage]) async {
                  questSystem.upsertQuest(updatedQuest);
                  await questRepo.upsertQuest(updatedQuest, changeMessage ?? 'no message provided');
                  if (context.mounted) Navigator.of(context).pop();
                },
                onDelete: (q) async {
                  await questRepo.deleteQuest(q);
                  changeManager.record(DeleteQuestChange(quest: q));
                  if(context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
          ),
        );
      },
    );
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

  Size get _viewSize {
    final rb = context.findRenderObject() as RenderBox?;
    return rb?.size ?? const Size(400, 400);
  }

  static const double _padding = 2400.0;
  static const double minScale = 0.000000001;
  static const double maxScale = 3000.0;

  (double, double) _clampTranslation(double tx, double ty, double s) {
    if (debugMode) return (tx, ty);

    final v = _viewSize;
    final txMin = v.width - _padding - _boundaryMax.dx * s;
    final txMax = -_boundaryMin.dx * s + _padding;
    final tyMin = v.height - _padding - _boundaryMax.dy * s;
    final tyMax = -_boundaryMin.dy * s + _padding;

    final clampedTx = txMin > txMax ? (txMin + txMax) / 2 : tx.clamp(txMin, txMax);
    final clampedTy = tyMin > tyMax ? (tyMin + tyMax) / 2 : ty.clamp(tyMin, tyMax);
    return (clampedTx, clampedTy);
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(
        onKey: (node, event) {
          if (event.logicalKey == LogicalKeyboardKey.keyZ && event is RawKeyDownEvent && (event.isMetaPressed || event.isControlPressed)) {
            changeManager.undo();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyY && event is RawKeyDownEvent && (event.isMetaPressed || event.isControlPressed)) {
            changeManager.redo();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        canRequestFocus: true,
      )..requestFocus(),
      child: Listener(
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) {
            final panelBox = _debugPanelKey.currentContext?.findRenderObject() as RenderBox?;
            if (panelBox != null && panelBox.attached) {
              final result = BoxHitTestResult();
              final localPos = panelBox.globalToLocal(e.position);
              if (panelBox.hitTest(result, position: localPos)) return;
            }
            _onPointerScroll(e);
          }
        },
        child: ClipRRect(
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
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => Transform(transform: _controller.value, alignment: Alignment.topLeft, child: child),
                    child: QuestBubblesOverlay(key: _questBubbleOverlayKey),
                  ),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    onScaleEnd: _onScaleEnd,
                    onDoubleTapDown: _onDoubleTapDown,
                    onDoubleTap: _onDoubleTap,
                    onTap: _onTap,
                    onTapDown: _onDoubleTapDown,
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
                if (debugMode)
                  QuestDebugPanel(key: _debugPanelKey, onChanged: () => _questBubbleOverlayKey.currentState?.refresh(), onFocusQuest: _focusOnQuest),
              ],
            ),
          ),
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
