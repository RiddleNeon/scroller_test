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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Quest Screen')),
      body: SizedBox.expand(child: PanWidget(key: _panKey)),
      floatingActionButton: FloatingActionButton(
        child: const Text("copy json", textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
        onPressed: () {
          String result = _panKey.currentState?.toJson() ?? "error generating json";
          Clipboard.setData(ClipboardData(text: result));
          print(result);
      }),
    );
  }
}