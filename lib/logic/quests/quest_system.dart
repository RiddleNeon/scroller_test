import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:wurp/logic/quests/quest.dart';

/// Contains all quests and exposes operations to add, remove, move, and
/// serialize them.
class QuestSystem {
  static final Map<int, Quest> quests = {};

  static void addQuest(Quest quest) => quests[quest.id] = quest;

  static void removeQuest(int id) => quests.remove(id);
  
  static void moveQuest(int id, double newX, double newY) {
    final quest = quests[id];
    if (quest == null) return;
    quest.posX = newX;
    quest.posY = newY;
  }

  static Future<void> load() async {
    final rawJson =
    jsonDecode(await rootBundle.loadString('assets/quests.json')) as List;
    final json = rawJson.cast<Map<String, dynamic>>();

    for (final data in json) {
      addQuest(Quest.fromJson(data));
    }

    for (final data in json) {
      final prereqIds = (data['prerequisites'] as List?)?.cast<int>();
      if (prereqIds == null || prereqIds.isEmpty) continue;

      assert(
      prereqIds.every(quests.containsKey),
      'All prerequisite IDs must reference existing quests.',
      );
      quests[data['id'] as int]!.prerequisites =
          prereqIds.map((id) => quests[id]!).toList();
    }
  }

  static String toJson() {
    return jsonEncode(quests.values.map((q) => {
      'id': q.id,
      'name': q.name,
      'description': q.description,
      'subject': q.subject,
      'posX': q.posX,
      'posY': q.posY,
      'difficulty': q.difficulty,
      'prerequisites': q.prerequisites.map((p) => p.id).toList(),
    }).toList());
  }
}