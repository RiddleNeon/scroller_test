import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:lumox/logic/quests/quest.dart';
import 'package:lumox/tools/supabase_tests/supabase_login_test.dart';

import '../logic/quests/quest_change_manager.dart';
import '../logic/quests/quest_connection.dart';
import '../logic/repositories/quest_repository.dart';

Future<void> importQuestsFromJson(String path) async {
  final file = await rootBundle.loadString(path);
  final jsonData = jsonDecode(file);

  final List quests = jsonData['quests'] ?? [];
  final List connections = jsonData['connections'] ?? [];

  final Map<int, List<Map<String, dynamic>>> grouped = {};

  for (final q in quests) {
    final id = q['id'];
    grouped.putIfAbsent(id, () => []).add(Map<String, dynamic>.from(q));
  }

  for (final entry in grouped.entries) {
    final int questId = entry.key;
    final versions = entry.value;

    print("Processing quest $questId with ${versions.length} versions");

    final exists = await questExists(questId);

    Quest? current;

    for (int i = 0; i < versions.length; i++) {
      final json = versions[i];

      if (i == 0 && !exists) {
        final quest = Quest.fromJson(json);

        await questRepo.addQuest(quest, "imported initial version");
        current = quest;
      } else {
        final patch = _patchFromJson(json);

        if (patch.isEmpty) continue;

        await questRepo.patchQuest(
          questId,
          patch,
          patch.generateChangeMessage(),
        );

        current = current != null
            ? patch.applyTo(current)
            : null;
      }
    }
  }

  for (final c in connections) {
    final conn = QuestConnection.fromJson(c);

    await questRepo.updateConnection(
      conn.fromQuestId,
      conn.toQuestId,
      newType: conn.type,
      newXpRequirement: conn.xpRequirement,
      updateMessage: "imported connection",
    );
  }

  print("Import finished.");
}

Future<bool> questExists(int questId) async {
  final result = await supabaseClient
      .from('quests')
      .select('id')
      .eq('id', questId)
      .maybeSingle();

  return result != null;
}

QuestPatch _patchFromJson(Map<String, dynamic> json) {
  return QuestPatch(
    name: json.containsKey('name') ? json['name'] : null,
    description: json.containsKey('description') ? json['description'] : null,
    subject: json.containsKey('subject') ? json['subject'] : null,
    posX: json.containsKey('posX') ? (json['posX'] as num?)?.toDouble() : null,
    posY: json.containsKey('posY') ? (json['posY'] as num?)?.toDouble() : null,
    difficulty: json.containsKey('difficulty') ? (json['difficulty'] as num?)?.toDouble() : null,
    sizeX: json.containsKey('sizeX') ? (json['sizeX'] as num?)?.toDouble() : null,
    sizeY: json.containsKey('sizeY') ? (json['sizeY'] as num?)?.toDouble() : null,
    color: json.containsKey('color') && json['color'] != null
        ? Color(json['color'])
        : null,
  );
}