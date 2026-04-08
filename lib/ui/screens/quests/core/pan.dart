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
import 'bezier_helper.dart';
import 'pan_background.dart';
import 'quest_bubble.dart';

class PanWidget extends StatefulWidget {
  const PanWidget({super.key, this.controller, required this.questSystem});

  final TransformationController? controller;
  final QuestSystem questSystem;

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

  QuestSystem get questSystem => widget.questSystem;
  QuestChangeManager get changeManager => widget.questSystem.changeManager;

  Quest? _findQuestAt(Offset scenePos) {
    for (final quest in questSystem.quests) {
      if (quest.rect.contains(scenePos)) return quest;
    }
    return null;
  }

  Quest? _findQuestInConnectZone(Offset scenePos) {
    const hitRadius = kConnectionHandleRadius * 1.6;
    for (final quest in questSystem.quests) {
      final handleCenter = Offset(quest.posX + quest.sizeX, quest.posY + quest.sizeY / 2); //on the right side of the bubble
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
  static const double _boundaryPadding = 200.0;

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
      double questX = quest.posX + (quest.sizeX / 2);
      double questY = quest.posY + (quest.sizeY / 2);
      if (questX > maxX) maxX = questX;
      if (questY > maxY) maxY = questY;
      if (questX < minX) minX = questX;
      if (questY < minY) minY = questY;
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

    if (debugMode && details.pointerCount == 1) {
      //ignore if not a single finger, to avoid conflicts with pinch zoom or other gestures
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
      final newPos = snap(_dragStartQuestPos);
      _questBubbleOverlayKey.currentState?.setDragState(questId: _draggingQuest!.id, position: newPos);
      return;
    }

    final s = (_scaleAtGestureStart * details.scale).clamp(minScale, maxScale);

    var tx = details.localFocalPoint.dx - s * (_focalAtGestureStart.dx - _txAtGestureStart) / _scaleAtGestureStart;
    var ty = details.localFocalPoint.dy - s * (_focalAtGestureStart.dy - _tyAtGestureStart) / _scaleAtGestureStart;

    final viewportRect = Rect.fromLTWH(-tx / s, -ty / s, context.size!.width / s, context.size!.height / s);
    _questBubbleOverlayKey.currentState?.onScaleChange(s, viewportRect);

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
      QuestPatch before = QuestPatch(posX: _draggingQuest!.posX, posY: _draggingQuest!.posY);

      final newPos = snap(_dragStartQuestPos);
      QuestPatch after = QuestPatch(posX: newPos.dx, posY: newPos.dy);

      _draggingQuest = after.applyTo(_draggingQuest!);

      changeManager.record(UpdateQuestChange(questId: _draggingQuest!.id, patch: after, reversePatch: before, updateMessage: 'moved quest'));

      questSystem.upsertQuest(_draggingQuest!);
    }
    _questBubbleOverlayKey.currentState?.setDragState(questId: null, position: null);
    setState(() => _draggingQuest = null);
  }

  Offset snap(Offset before) {
    final currentScale = _currentScale;
    final worldDelta = _focalDelta / currentScale;

    final rawPos = before + worldDelta;

    final snappedX = ((rawPos.dx / gridSize + 0.5).round()) * gridSize;
    final snappedY = ((rawPos.dy / gridSize + 0.5).round()) * gridSize;

    final Offset newPos;
    if (isGridSnappingEnabled) {
      newPos = Offset(snappedX, snappedY);
    } else {
      newPos = rawPos;
    }
    return newPos;
  }

  void _addConnection({required int sourceId, required int targetId}) {
    final target = questSystem.maybeGetQuestById(targetId);
    if (target == null || questSystem.prerequisitesOf(targetId).any((p) => p.id == sourceId)) {
      return;
    }

    try {
      changeManager.record(AddConnectionChange(fromId: targetId, toId: sourceId, updateMessage: 'connection drawn'));
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
    
    final viewportRect = Rect.fromLTWH(-tx / newScale, -ty / newScale, context.size!.width / newScale, context.size!.height / newScale);
    _questBubbleOverlayKey.currentState?.onScaleChange(newScale, viewportRect);
    
    _controller.value = Matrix4.identity()
      ..scale(newScale)
      ..setTranslation(Vector3(tx, ty, 0));
  }
  
  ({int fromId, int toId, Offset midpoint})? _hoveredConnection;

  void _onPointerHover(PointerHoverEvent event) {
    if (_isConnecting || _draggingQuest != null) return;
    int? currentDraggedQuestId = _draggingQuest?.id;
    Offset? currentDraggedQuestPos = _draggingQuest != null ? snap(_dragStartQuestPos) : null;

    final scenePos = _controller.toScene(event.localPosition);
    final threshold = 15.0 / _currentScale;

    ({int fromId, int toId, Offset midpoint})? closest;
    double minDistance = double.infinity;

    for (final quest in questSystem.quests) {
      for (final prereq in questSystem.prerequisitesOf(quest.id)) {
        final startCenter = getQuestCenter(prereq.id, questSystem, currentDraggedQuestId, currentDraggedQuestPos);
        final endCenter = getQuestCenter(quest.id, questSystem, currentDraggedQuestId, currentDraggedQuestPos);
        
        if(startCenter == null || endCenter == null) continue;

        final anchorStart = getBestAnchor(prereq.id, endCenter, questSystem, currentDraggedQuestId, currentDraggedQuestPos);
        final anchorEnd = getBestAnchor(quest.id, startCenter, questSystem, currentDraggedQuestId, currentDraggedQuestPos);

        final cps = calculateCubicControlPoints(anchorStart.pos, anchorStart.sideDir, anchorEnd.pos, anchorEnd.sideDir);
        
        for (double t = 0.1; t <= 0.9; t += 0.1) {
          final pointOnCurve = bezierPoint(anchorStart.pos, cps[0], cps[1], anchorEnd.pos, t);
          final dist = (scenePos - pointOnCurve).distance;

          if (dist < threshold && dist < minDistance) {
            minDistance = dist;
            closest = (
            fromId: prereq.id,
            toId: quest.id,
            midpoint: bezierPoint(anchorStart.pos, cps[0], cps[1], anchorEnd.pos, 0.5)
            );
          }
        }
      }
    }

    if (closest != _hoveredConnection) {
      setState(() => _hoveredConnection = closest);
    }
  }

  void _removeConnection(int fromId, int toId) {
    print("Removing connection from $fromId to $toId");
    changeManager.record(RemoveConnectionChange(fromId: fromId, toId: toId));
    setState(() => _hoveredConnection = null);
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

    if(_hoveredConnection != null) _removeConnection(_hoveredConnection!.fromId, _hoveredConnection!.toId);
    
    
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
              changeManager.record(
                UpdateQuestChange(
                  patch: updatedQuest,
                  reversePatch: QuestPatch.fromQuest(quest),
                  questId: quest.id,
                  updateMessage: changeMessage ?? 'no message provided',
                ),
              );
              if (context.mounted) Navigator.of(context).pop();
            },
            onDelete: (q) async {
              await questRepo.deleteQuest(q);
              changeManager.record(DeleteQuestChange(quest: q));
              if (context.mounted) Navigator.of(context).pop();
            },
            questSystem: questSystem,
          ),
        ),
      ),
    );
  }

  void showQuestAddOverlay(Offset scenePos) {
    final snappedPos = snap(scenePos);
    Quest quest = Quest(
      id: DateTime.now().millisecondsSinceEpoch,
      name: 'No name provided',
      description: 'No description provided',
      subject: 'General',
      posX: snappedPos.dx,
      posY: snappedPos.dy,
    );
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
                quest: quest,
                debugMode: true,
                editMode: true,
                recommendedChangeMessage: 'Initial version',
                onDoneEditing: (updatedQuest, [changeMessage]) async {
                  changeManager.record(AddQuestChange(quest: updatedQuest.applyTo(quest), updateMessage: changeMessage ?? 'no message provided'));
                  if (context.mounted) Navigator.of(context).pop();
                },
                onDelete: (q) async {
                  await questRepo.deleteQuest(q);
                  changeManager.record(DeleteQuestChange(quest: q));
                  if (context.mounted) Navigator.of(context).pop();
                },
                questSystem: questSystem,
              ),
            ),
          ),
        );
      },
    );
  }

  void focusOnQuest(Quest quest) {
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

  void centerOnAllQuests(double screenWidth, double screenHeight, {bool autoZoom = true}) {
    final boundaryCenter = Offset((_boundaryMin.dx + _boundaryMax.dx) / 2, (_boundaryMin.dy + _boundaryMax.dy) / 2);

    double scaleX = screenWidth / (_boundaryMax.dx - _boundaryMin.dx + 1);
    double scaleY = screenHeight / (_boundaryMax.dy - _boundaryMin.dy + 1);
    double targetScale = autoZoom ? (scaleX < scaleY ? scaleX : scaleY) * 0.85 : _currentScale;

    final targetTx = screenWidth / 2 - boundaryCenter.dx * (targetScale);
    final targetTy = screenHeight / 2 - boundaryCenter.dy * (targetScale);

    _controller.value = Matrix4.identity()
      ..scale(targetScale)
      ..translate(targetTx / targetScale, targetTy / targetScale);
  }

  static const double minScale = 0.000000001;
  static const double maxScale = 3000.0;

  bool isGridSnappingEnabled = true;
  double gridSize = 25.0;

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(
        onKey: (node, event) {
          if (event.logicalKey == LogicalKeyboardKey.keyZ && event is RawKeyDownEvent && (event.isMetaPressed || event.isControlPressed)) {
            setState(() {
              changeManager.undo();
              _controller.value.rotateX(0.0000000000001);
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyY && event is RawKeyDownEvent && (event.isMetaPressed || event.isControlPressed)) {
            setState(() {
              changeManager.redo();
              _controller.value.rotateX(0.0000000000001);
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyC && !HardwareKeyboard.instance.isShiftPressed) {
            centerOnAllQuests(context.size?.width ?? 100, context.size?.height ?? 100, autoZoom: false);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyC && HardwareKeyboard.instance.isShiftPressed) {
            centerOnAllQuests(context.size?.width ?? 100, context.size?.height ?? 100, autoZoom: true);
            return KeyEventResult.handled;
          }

          if (HardwareKeyboard.instance.isShiftPressed) {
            isGridSnappingEnabled = false;
          } else {
            isGridSnappingEnabled = true;
          }
          return KeyEventResult.ignored;
        },
        canRequestFocus: true,
      )..requestFocus(),
      child: Listener(
        onPointerHover: _onPointerHover,
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
                    child: QuestBubblesOverlay(key: _questBubbleOverlayKey, debugMode: debugMode, questSystem: questSystem),
                  ),
                ),

                if (_hoveredConnection != null)
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final screenPos = MatrixUtils.transformPoint(_controller.value, _hoveredConnection!.midpoint);

                      return Positioned(
                        left: screenPos.dx - 15,
                        top: screenPos.dy - 15,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => _removeConnection(_hoveredConnection!.fromId, _hoveredConnection!.toId),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close, size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      );
                    },
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
                /*if (debugMode)
                  QuestDebugPanel(key: _debugPanelKey, onChanged: () => _questBubbleOverlayKey.currentState?.refresh(), onFocusQuest: _focusOnQuest),*/
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
