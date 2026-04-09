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
                                i == 2 ? Icons.add_rounded : item.icon,
                                color: i == 2 ? cs.onTertiary : iconColor,
                                size: i == 2 ? 22 : 24,
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
                              child: Text(item.label.isEmpty ? 'Create' : item.label),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                if (items.length > 2)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    left: createCenterX - 18,
                    top: (constraints.maxHeight - 36) / 2,
                    width: 36,
                    height: 36,
                    child: IgnorePointer(
                      child: AnimatedScale(
                        scale: currentSelectedIndex == 2 ? 1.0 : 0.95,
                        duration: const Duration(milliseconds: 180),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: cs.tertiary.withValues(alpha: 0.24),
                            shape: BoxShape.circle,
                            border: Border.all(color: cs.tertiary.withValues(alpha: 0.68)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
