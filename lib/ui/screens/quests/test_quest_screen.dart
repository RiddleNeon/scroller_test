//test app for the quest screen

import 'package:flutter/material.dart';
import 'package:wurp/logic/quests/quest_change_manager.dart';
import 'package:wurp/ui/screens/quests/core/pan.dart';
import 'package:wurp/ui/screens/quests/version_management/change_screen.dart';

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
          child: const Text('Quest Screen'))),
      body: SizedBox.expand(child: PanWidget(key: _panKey)),
      floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.commit),
          onPressed: () {
        showDialog(context: context, builder: (context) => QuestChangeScreen(changeManager: changeManager,)); //show change screen
      }),
    );
  }
}