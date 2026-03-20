import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:wurp/logic/quests/quest.dart';
import 'package:wurp/logic/repositories/quest_repository.dart';

class QuestSystem with ChangeNotifier {
  final Map<int, Quest> quests = {};

  void addQuest(Quest quest) => quests[quest.id] = quest;

  void removeQuest(int id) => quests.remove(id);

  void moveQuest(int id, double newX, double newY) {
    final quest = quests[id];
    if (quest == null) return;
    quest.posX = newX;
    quest.posY = newY;
    notifyListeners();
  }

  /// Loads quests from the bundled [assets/quests.json] file (offline / dev).
  Future<void> loadFromAssets() async {
    final rawJson = jsonDecode(await rootBundle.loadString('assets/quests.json')) as List;
    final json = rawJson.cast<Map<String, dynamic>>();

    for (final data in json) {
      addQuest(Quest.fromJson(data));
    }

    // Wire up prerequisites in a second pass so all quests are already in the
    // map when we start resolving IDs.
    for (final data in json) {
      final prereqIds = (data['prerequisites'] as List?)?.cast<int>();
      if (prereqIds == null || prereqIds.isEmpty) continue;

      assert(prereqIds.every(quests.containsKey), 'All prerequisite IDs must reference existing quests.');
      quests[data['id'] as int]!.prerequisites = prereqIds.map((id) => quests[id]!).toList();
    }

    notifyListeners();
  }

  /// Fetches quests for [subject] from the server and merges them into the
  /// local map. Existing quests with the same ID are replaced.
  Future<void> loadFromServer(String subject) async {
    final fetched = await questRepo.fetchQuestsBySubject(subject);

    for (final quest in fetched) {
      quests[quest.id] = quest;
    }

    notifyListeners();
  }

  String? toJson() {
    try {
      return jsonEncode(
        quests.values
            .map(
              (q) => {
                'id': q.id,
                'name': q.name,
                'description': q.description,
                'subject': q.subject,
                'posX': q.posX,
                'posY': q.posY,
                'sizeX': q.sizeX,
                'sizeY': q.sizeY,
                'difficulty': q.difficulty,
                'prerequisites': q.prerequisites.map((p) => p.id).toList(),
              },
            ).toList(),
      );
    } on Exception {
      return null;
    }
  }
}

QuestSystem questSystem = QuestSystem();
