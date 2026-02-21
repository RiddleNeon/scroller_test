import 'package:flutter/material.dart';

class BottomNavBar extends StatefulWidget {
  final void Function(int) onSelectionChange;

  const BottomNavBar({super.key, required this.onSelectionChange});

  @override
  State<BottomNavBar> createState() => BottomNavBarState();
}

class BottomNavBarState extends State<BottomNavBar> {
  int currentSelectedIndex = 0;

  static const _items = [
    (icon: Icons.home, label: 'Home'),
    (icon: Icons.search, label: 'Discover'),
    (icon: Icons.add_box_outlined, label: ''),
    (icon: Icons.notifications_none, label: 'Inbox'),
    (icon: Icons.person_outline, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      height: 56 + bottomPad,
      padding: EdgeInsets.only(bottom: bottomPad),
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotWidth = constraints.maxWidth / _items.length;

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
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_items.length, (i) {
                  final item = _items[i];

                  if (i == 2) {
                    return GestureDetector(
                      onTap: () {
                        setState(() => currentSelectedIndex = i);
                        widget.onSelectionChange(currentSelectedIndex);
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
                      widget.onSelectionChange(currentSelectedIndex);
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
