//test app for the quest screen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wurp/ui/screens/quests/core/pan.dart';

class TestQuestScreen extends StatefulWidget {
  const TestQuestScreen({super.key});

  @override
  State<TestQuestScreen> createState() => _TestQuestScreenState();
}

class _TestQuestScreenState extends State<TestQuestScreen> {
  final GlobalKey<PanWidgetState> _panKey = GlobalKey<PanWidgetState>();
  bool debugMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: InkWell(
          onTap: () {
            debugMode = !debugMode;
            _panKey.currentState?.debugMode = debugMode;
            setState(() {});
          },
          child: const Text('Test Quest Screen'))),
      body: SizedBox.expand(child: PanWidget(key: _panKey)),
    );
  }
}