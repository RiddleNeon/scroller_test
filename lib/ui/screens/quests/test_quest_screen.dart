//test app for the quest screen

import 'package:flutter/material.dart';
import 'package:wurp/ui/screens/quests/core/pan.dart';

class TestQuestScreen extends StatelessWidget {
  const TestQuestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Quest Screen')),
      body: PanWidget(child: Container(),)
    );
  }
}