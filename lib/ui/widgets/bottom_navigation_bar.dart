import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:wurp/base_logic.dart';

class BottomNavBar extends StatefulWidget {
  final void Function(String) onSelectionChange;
  final List<({IconData icon, String id, String label})> items;
  final int initialIndex;

  const BottomNavBar({super.key, required this.onSelectionChange, required this.items, this.initialIndex = 0});

  @override
  State<BottomNavBar> createState() => BottomNavBarState();
}

class BottomNavBarState extends State<BottomNavBar> with SingleTickerProviderStateMixin {
  late int currentSelectedIndex;

  List get items => widget.items;

  late final AnimationController _selectionSizeAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 580));

  // Track hover state per item
  late List<bool> _hovered;

  @override
  void initState() {
    super.initState();
    currentSelectedIndex = widget.initialIndex;
    _hovered = List.filled(widget.items.length, false);
  }

  void switchToIndex(int index) {
    print("adding post frame callback to switch to index: $index");
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      setState(() {
        print("Switching to index: $index, which has id: ${items[index].id}");
        currentSelectedIndex = index;
        _selectionSizeAnimationController.reset();
        _selectionSizeAnimationController.animateTo(1.5, curve: Curves.easeOutBack);
      });
    });
  }

  void switchToId(String id) {
    final index = items.indexWhere((item) => item.id == id);
    if (index != -1) {
      switchToIndex(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!userLoggedIn) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      height: 66 + bottomPad,
      padding: EdgeInsets.fromLTRB(10, 8, 10, bottomPad + 6),
      color: Colors.transparent,
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.98),
        elevation: 10,
        shadowColor: cs.shadow.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.9)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slotWidth = constraints.maxWidth / items.length;
            final selectorCenterX = currentSelectedIndex * slotWidth + slotWidth / 2;

            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: selectorCenterX - (slotWidth - 8) / 2,
                  top: 4,
                  width: slotWidth - 8,
                  height: constraints.maxHeight - 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(items.length, (i) {
                    final item = items[i];
                    final selected = currentSelectedIndex == i;
                    final iconColor = selected ? cs.primary : cs.onSurfaceVariant;
                    final isHovered = _hovered[i];

                    return MouseRegion(
                      onEnter: (_) => setState(() => _hovered[i] = true),
                      onExit: (_) => setState(() => _hovered[i] = false),
                      child: GestureDetector(
                        onTapDown: (_) => setState(() => _hovered[i] = false),
                        onTap: () {
                          if (currentSelectedIndex == i) return;
                          setState(() => currentSelectedIndex = i);
                          widget.onSelectionChange(items[currentSelectedIndex].id);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedScale(
                          scale: isHovered ? 1.12 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          child: SizedBox(
                            width: slotWidth,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                selected
                                    ? AnimatedBuilder(
                                        animation: _selectionSizeAnimationController,
                                        builder: (context, child) {
                                          final val = 1 - _selectionSizeAnimationController.value;
                                          final scale = 1 + (val * 0.2);
                                          final scaleY = 1 + (val * 0.01);
                                          final rotation = val * 0.02;

                                          final transform = Matrix4.identity()
                                            ..translateByVector3(Vector3(0, -4 * val, 0))
                                            ..rotateZ(rotation)
                                            ..scaleByVector3(Vector3(scaleY, scale, scale))
                                            ..translateByVector3(Vector3(0, 4 * val, 0));

                                          return Transform(alignment: Alignment.center, transform: transform, child: child);
                                        },
                                        child: Icon(item.icon, color: iconColor, size: 24),
                                      )
                                    : Icon(item.icon, color: iconColor, size: 24),
                                const SizedBox(height: 2),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 180),
                                  style: TextStyle(
                                    color: selected ? cs.onSurface : cs.onSurfaceVariant,
                                    fontSize: 10,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                  child: Text(item.label),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
