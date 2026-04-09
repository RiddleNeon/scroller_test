import 'package:flutter/material.dart';
import 'package:wurp/base_logic.dart';

class BottomNavBar extends StatefulWidget {
  final void Function(String) onSelectionChange;
  final List<({IconData icon, String id, String label})> items;
  final int initialIndex;

  const BottomNavBar({super.key, required this.onSelectionChange, required this.items, this.initialIndex = 0});

  @override
  State<BottomNavBar> createState() => BottomNavBarState();
}

class BottomNavBarState extends State<BottomNavBar> {
  late int currentSelectedIndex;
  List get items => widget.items;

  @override
  void initState() {
    super.initState();
    currentSelectedIndex = widget.initialIndex;
  }

  void switchToIndex(int index) {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      setState(() {
        currentSelectedIndex = index;
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
            final createCenterX = (2 * slotWidth) + slotWidth / 2;
            const createCircleSize = 36.0;
            const createCircleTop = 8.0;

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

                    return GestureDetector(
                      onTap: () {
                        setState(() => currentSelectedIndex = i);
                        widget.onSelectionChange(items[currentSelectedIndex].id);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: slotWidth,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutBack,
                              scale: selected ? 1.08 : 1.0,
                              child: Icon(
                                item.icon,
                                color: iconColor,
                                size: 24,
                              ),
                            ),
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
