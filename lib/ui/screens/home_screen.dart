import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:wurp/ui/misc/glowScreen.dart';
import 'package:wurp/ui/scrolling_container.dart';


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