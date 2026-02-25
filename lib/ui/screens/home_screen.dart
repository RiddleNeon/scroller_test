
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wurp/main.dart';
import 'package:wurp/next_try/bottom_navigation_bar.dart';
import 'package:wurp/next_try/search_screen.dart';
import 'package:wurp/ui/misc/glow_screen.dart';

import '../../next_try/profile_screen.dart';
import '../short_video_player.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin, WidgetsBindingObserver {
  static const GlobalObjectKey<BottomNavBarState> bottomNavBarKey = GlobalObjectKey("bottomNavBar");

  static const startScreen = 0;
  int selectedIndex = startScreen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Timer.periodic(const Duration(minutes: 3), (timer) {
      localSeenService.syncWithFirestore(onlyLoad: false);
    });
  }
  

  void onNavBarSelectionChange(int newIndex) {
    setState(() {
      selectedIndex = newIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;

    switch (selectedIndex) {
      case 0:
        content = feedVideos(this, videoProvider);
        break;
      case 1:
        content = SearchScreen();
        break;
      case 4:
        content = ProfileScreen(profile: currentUser);
        break;
      case int():
        content = feedVideos(this, videoProvider);
        break;
    }
    ;

    return Scaffold(
      backgroundColor: Colors.black,
      body: runningOnMobile ? content : Glowscreen(child: content),
      bottomNavigationBar: BottomNavBar(key: bottomNavBarKey, onSelectionChange: onNavBarSelectionChange),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      localSeenService.syncWithFirestore(onlyLoad: false);
      print("synced with firestore!");
    }
  }
}