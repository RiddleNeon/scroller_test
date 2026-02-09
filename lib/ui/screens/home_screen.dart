import 'package:flutter/material.dart';
import 'package:wurp/main.dart';
import 'package:wurp/ui/misc/glow_screen.dart';
import 'package:wurp/ui/scrolling_container.dart';

import '../../logic/video/video_provider.dart';


class MyHomePage extends StatefulWidget {
  MyHomePage({super.key}) {
    //videoPublishTest();
  }

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {


  @override
  Widget build(BuildContext context) {
    return Glowscreen(child: ScrollingContainer());
  }
}