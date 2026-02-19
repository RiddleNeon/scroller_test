import 'package:flutter/material.dart';
import 'package:wurp/main.dart';
import 'package:wurp/ui/misc/glow_screen.dart';
import 'package:wurp/ui/short_video_player.dart';



class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin{


  @override
  Widget build(BuildContext context) {
    if(!runningOnMobile) {
      return Glowscreen(child: feedVideos(this, videoProvider));
    } else {
      return Scaffold(
        backgroundColor: Colors.black,
        body: feedVideos(this, videoProvider),
      );
    }
  }
}
