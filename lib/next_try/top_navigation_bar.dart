import 'package:flutter/material.dart';

class TopNavBar extends StatefulWidget {
  const TopNavBar({super.key});

  @override
  State<TopNavBar> createState() => _TopNavBarState();
}

class _TopNavBarState extends State<TopNavBar> {
  int _selected = 1; // 0 = Following, 1 = For You

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Tab(
            label: 'Following',
            selected: _selected == 0,
            onTap: () => setState(() => _selected = 0),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 16, color: Colors.white54),
          const SizedBox(width: 8),
          _Tab(
            label: 'For You',
            selected: _selected == 1,
            onTap: () => setState(() => _selected = 1),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight:
              selected ? FontWeight.bold : FontWeight.normal,
              fontSize: selected ? 16 : 15,
              shadows: const [Shadow(blurRadius: 4, color: Colors.black45)],
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            width: selected ? 24 : 0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}