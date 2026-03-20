import 'package:flutter/foundation.dart';
import 'package:wurp/logic/quests/quest.dart';
import 'package:wurp/logic/quests/quest_system.dart';
import 'package:wurp/logic/repositories/quest_repository.dart';
///a quest change manager that handles all changes to quests and connections, ensuring that all changes are properly versioned and logged. you can push these changes to the server at any time, and the manager will handle batching and conflict resolution.
class QuestChangeManager with ChangeNotifier {
  final QuestSystem questSystem;

  // A list of pending changes that have not yet been pushed to the server.
  final List<QuestChange> _pendingChanges = [];

  QuestChangeManager({
    required this.questSystem,
  });

  void addChange(QuestChange change) {
    _pendingChanges.add(change);
    notifyListeners();
  }

  Future<void> pushChanges() async {
    if (_pendingChanges.isEmpty) return;

    for (final change in _pendingChanges) {
      await change.apply(questRepo);
    }

    _pendingChanges.clear();
    notifyListeners();
  }
  
  //removes changes that are undone or no longer relevant
  void handleConflicts() {
    _pendingChanges.removeWhere((c) => c.quest.isDeleted);
  }
}

class QuestChange {
  final Quest quest;
  final String updateMessage;
  bool isApplied;

  QuestChange({
    required this.quest,
    required this.updateMessage,
    this.isApplied = false,
  });

  Future<void> apply(QuestRepository repo) async {
    isApplied = true;
  }
  
  void undo() {
    questSystem.upsertQuest(quest);
    isApplied = false;
  }
}