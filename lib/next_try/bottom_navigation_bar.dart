import 'package:flutter/material.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _current = 0;

  static const _items = [
    (icon: Icons.home, label: 'Home'),
    (icon: Icons.search, label: 'Discover'),
    (icon: Icons.add_box_outlined, label: ''),
    (icon: Icons.notifications_none, label: 'Inbox'),
    (icon: Icons.person_outline, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (i) {
          final item = _items[i];

          if (i == 2) {
            // ── Upload button ─────────────────────────────────────────
            return GestureDetector(
              onTap: () {},
              child: Container(
                width: 42,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF69C9D0), Color(0xFFEE1D52)],
                  ),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            );
          }

          final selected = _current == i;
          return GestureDetector(
            onTap: () => setState(() => _current = i),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  color: selected ? Colors.white : Colors.grey,
                  size: 26,
                ),
                Text(
                  item.label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.grey,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}