import 'package:flutter/material.dart';
import 'package:wurp/main.dart';
import 'package:wurp/next_try/bottom_navigation_bar.dart';
import 'package:wurp/next_try/search_screen.dart';
import 'package:wurp/ui/auth/auth_screen.dart';
import 'package:wurp/ui/misc/glow_screen.dart';
import 'package:wurp/ui/short_video_player.dart';



class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin{
  final GlobalObjectKey<BottomNavBarState> bottomNavBarKey = GlobalObjectKey("bottomNavBar");
  
  static const startScreen = 0;
  int selectedIndex = startScreen;
  
  void onNavBarSelectionChange(int newIndex){
    setState(() {
      selectedIndex = newIndex;
    });
  }
  


  @override
  Widget build(BuildContext context) {
    final Widget content;
    
    switch(selectedIndex) {
      case 0: content = feedVideos(this, videoProvider); break;
      case 1: content = SearchScreen(); break;
      case 4: content = LoginScreen(); break;
      case int(): content = feedVideos(this, videoProvider); break;
    };
    
    bool loggedOut = selectedIndex == 4;
    return Scaffold(
      backgroundColor: Colors.black,
      body: runningOnMobile ? content : Glowscreen(child: content),
      bottomNavigationBar: loggedOut ? null : BottomNavBar(key: bottomNavBarKey, onSelectionChange: onNavBarSelectionChange),
    );
  }
}
