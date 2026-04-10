//test app for the quest screen

import 'package:flutter/material.dart';
import 'package:wurp/logic/quests/quest_system.dart';
import 'package:wurp/ui/screens/quests/core/pan.dart';
import 'package:wurp/ui/screens/quests/version_management/change_screen.dart';

class TestQuestScreen extends StatefulWidget {
  final String subject;

  const TestQuestScreen({super.key, required this.subject});

  @override
  State<TestQuestScreen> createState() => _TestQuestScreenState();
}

class _TestQuestScreenState extends State<TestQuestScreen> {
  final GlobalKey<PanWidgetState> _panKey = GlobalKey<PanWidgetState>();
  bool debugMode = false;
  bool hasPendingChanges = false;

  @override
  initState() {
    super.initState();
    print("Initializing TestQuestScreen with subject: ${widget.subject}");
    questSystemFuture = loadQuestSystem();
  }

  Future<QuestSystem> loadQuestSystem() async {
    QuestSystem questSystem = QuestSystem();
    print("-- Loading quests for subject: ${widget.subject}");
    await questSystem.loadFromServer(widget.subject);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (!mounted) return;
      setState(() {
        _panKey.currentState?.centerOnAllQuests(context.size?.width ?? 1000, context.size?.height ?? 1000);
      });
    });

    questSystem.changeManager.addListener(() {
      if (!mounted) return;
      if (questSystem.changeManager.hasPendingChanges != hasPendingChanges) {
        setState(() {
          hasPendingChanges = questSystem.changeManager.hasPendingChanges;
        });
      }
    });
    return questSystem;
  }

  late Future<QuestSystem> questSystemFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: questSystemFuture,
      builder: (context, asyncSnapshot) {
        final loaded = asyncSnapshot.hasData;
        final questSystem = asyncSnapshot.data;
        
        print("loaded: $loaded, questSystem: $questSystem");

        return Scaffold(
          appBar: AppBar(
            title: InkWell(
              onTap: () {
                debugMode = !debugMode;
                _panKey.currentState?.debugMode = debugMode;
                setState(() {});
              },
              child: const Text('Quest Screen'),
            ),
          ),
          body: loaded
              ? SizedBox.expand(
                  child: PanWidget(key: _panKey, questSystem: questSystem!),
                )
              : const Center(child: CircularProgressIndicator()),
          floatingActionButton: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedSlide(
                offset: debugMode && loaded ? Offset.zero : const Offset(0, 2),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCirc,
                child: FloatingActionButton(
                  heroTag: null,
                  clipBehavior: Clip.none,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.commit),
                      if (loaded)
                        Positioned(
                          top: -kFloatingActionButtonMargin*1.5,
                          right: -kFloatingActionButtonMargin*1.5,
                          child: AnimatedScale(
                            scale: questSystem!.changeManager.hasPendingChanges ? 1 : 0,
                            duration: const Duration(milliseconds: 420),
                            curve: Curves.easeOutBack,
                            child: AnimatedSlide(
                              offset: questSystem!.changeManager.hasPendingChanges ? Offset.zero : const Offset(0, 0.35),
                              duration: const Duration(milliseconds: 420),
                              curve: Curves.easeOutCubic,
                              child: const Icon(Icons.circle, color: Colors.red), //red dot
                            ),
                          ), //red dot to indicate changes
                        ),
                    ],
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => QuestChangeScreen(changeManager: questSystem!.changeManager),
                    ); //show change screen
                  },
                ),
              ),
              const SizedBox(width: 16), //space between buttons
              FloatingActionButton(
                heroTag: null,
                child: const Icon(Icons.filter_center_focus),
                onPressed: () {
                  _panKey.currentState?.centerOnAllQuests(context.size?.width ?? 100, context.size?.height ?? 100, autoZoom: true);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
