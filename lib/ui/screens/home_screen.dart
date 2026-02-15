import 'package:flutter/material.dart';
import 'package:wurp/main.dart';
import 'package:wurp/ui/misc/glow_screen.dart';
import 'package:wurp/ui/scrolling_container.dart';



class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {


  @override
  Widget build(BuildContext context) {
    if(!runningOnMobile) {
      return Glowscreen(child: ScrollingContainer());
    } else {
      return ScrollingContainer();
    }
  }
}