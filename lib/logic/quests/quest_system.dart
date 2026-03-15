import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:wurp/logic/quests/quest.dart';

///a class containing all quests and relationships between them, as well as functions to add/remove quests and check for quest completion
class QuestSystem {
  static final Map<int, Quest> quests = {};
  
  static void addQuest(Quest quest) {
    quests[quest.id] = quest;
  }
  static void removeQuest(int id) {
    quests.remove(id);
  }
  static void moveQuest(int id, double newX, double newY) {
    final quest = quests[id];
    if (quest != null) {
      quests[id] = quest.copyWith(posX: newX, posY: newY);
    }
    quests.values.where((q) => q.prerequisites.any((p) => p.id == id)).forEach((q) {
      q.updateMappedPrerequisites();
    });
  }
  
  static Future<void> load() async {
    final json = jsonDecode(await rootBundle.loadString('assets/quests.json')) as List;
    
    for (var questJson in json) {
      addQuest(Quest.fromJson(questJson));
    }
    for(var questJson in json) {
      var quest = quests[questJson['id']]!;
      if (questJson['prerequisites'] != null) {
        assert(questJson['prerequisites'] is List, 'Prerequisites must be a list of quest IDs');
        assert((questJson['prerequisites'] as List).every((id) => quests.containsKey(id)), 'All prerequisite quest IDs must exist in the quest system');
        quest.prerequisites = (questJson['prerequisites'] as List).map((id) => quests[id]!).toList();
      }
    }
  }
  
  static String toJson() {
    return jsonEncode(quests.values.map((quest) => {
      'id': quest.id,
      'name': quest.name,
      'description': quest.description,
      'subject': quest.subject,
      'posX': quest.posX,
      'posY': quest.posY,
      'difficulty': quest.difficulty,
      'prerequisites': quest.prerequisites.map((q) => q.id).toList(),
    }).toList());
  }
}