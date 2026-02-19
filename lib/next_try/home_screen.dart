import 'package:flutter/material.dart';
import 'package:wurp/next_try/top_navigation_bar.dart';
import 'bottom_navigation_bar.dart';
import 'feed_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: Stack(
        children: [
          // Full-screen feed
          const FeedScreen(),

          // Top navigation overlay
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: TopNavBar(),
          ),

          // Search icon top-right
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            right: 12,
            child: const Icon(Icons.search, color: Colors.white, size: 26),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}