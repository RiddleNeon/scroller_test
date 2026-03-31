import 'package:flutter/material.dart';

class BottomNavBar extends StatefulWidget {
  final void Function(String) onSelectionChange;
  final List<({IconData icon, String id, String label})> items;
  final int initialIndex;

  const BottomNavBar({super.key, required this.onSelectionChange, required this.items, this.initialIndex = 0});

  @override
  State<BottomNavBar> createState() => BottomNavBarState();
}

class BottomNavBarState extends State<BottomNavBar> {
  late int currentSelectedIndex = widget.initialIndex;  
  List get items => widget.items;
  
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
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      height: 56 + bottomPad,
      padding: EdgeInsets.only(bottom: bottomPad),
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotWidth = constraints.maxWidth / items.length;

          final selectorCenterX = currentSelectedIndex * slotWidth + slotWidth / 2;

          double selectorW = slotWidth;
          double selectorH = constraints.maxHeight;

          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: selectorCenterX - selectorW / 2,
                top: (56 - selectorH) / 2,
                width: selectorW,
                height: selectorH,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (i) {
                  final item = items[i];

                  if (i == 2) {
                    return GestureDetector(
                      onTap: () {
                        setState(() => currentSelectedIndex = i);
                        widget.onSelectionChange(items[currentSelectedIndex].id);
                      },
                      child: SizedBox(
                        width: slotWidth,
                        height: 56,
                        child: Center(
                          child: Container(
                            width: 42,
                            height: 28,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF69C9D0), Color(0xFFEE1D52)],
                              ),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  final selected = currentSelectedIndex == i;

                  return GestureDetector(
                    onTap: () {
                      setState(() => currentSelectedIndex = i);
                      widget.onSelectionChange(items[currentSelectedIndex].id);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: slotWidth,
                      height: 56,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: selected ? 1.15 : 1.0,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                            child: Icon(
                              item.icon,
                              color: selected ? Colors.white : Colors.grey,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.grey,
                              fontSize: 10,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
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
    );
  }
}
