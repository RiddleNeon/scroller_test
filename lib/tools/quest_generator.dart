import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:lumox/logic/quests/quest.dart';
import 'package:lumox/tools/supabase_tests/supabase_login_test.dart';

import '../logic/quests/quest_change_manager.dart';
import '../logic/quests/quest_connection.dart';

import 'package:lumox/logic/quests/quest_system.dart';

Future<void> importWithChangeManager({
  required QuestSystem system,
  required String path,
}) async {
  final file = await rootBundle.loadString(path);
  final jsonData = jsonDecode(file);

  final List quests = jsonData['quests'] ?? [];
  final List connections = jsonData['connections'] ?? [];

  final cm = system.changeManager;

  final Map<int, List<Map<String, dynamic>>> grouped = {};

  for (final q in quests) {
    final id = q['id'];
    grouped.putIfAbsent(id, () => []).add(Map<String, dynamic>.from(q));
  }

  for (final entry in grouped.entries) {
    final int questId = entry.key;
    final versions = entry.value;

    print("Processing quest $questId");

    Quest? current = system.maybeGetQuestById(questId);

    for (int i = 0; i < versions.length; i++) {
      final json = versions[i];

      if (current == null && i == 0) {
        final quest = Quest.fromJson(json);

        cm.record(AddQuestChange(
          quest: quest,
          updateMessage: "imported quest",
        ));

        current = quest;
      } else {
        final patch = _patchFromJson(json);
        if (patch.isEmpty) continue;

        final before = current!;
        final after = patch.applyTo(before);

        cm.record(UpdateQuestChange.fromDiff(
          before: before,
          after: after,
          updateMessage: patch.generateChangeMessage(),
        ));

        current = after;
      }
    }
  }
  
  for (final c in connections) {
    final conn = QuestConnection.fromJson(c);

    final exists = system.isConnected(conn.fromQuestId, conn.toQuestId);

    if (!exists) {
      cm.record(AddConnectionChange(
        fromId: conn.fromQuestId,
        toId: conn.toQuestId,
      ));
    } else {
      final current = system.getConnection(conn.fromQuestId, conn.toQuestId);
      if (current == null) continue;

      final patch = QuestConnectionPatch.diff(current, conn);
      if (patch.isEmpty) continue;

      cm.record(UpdateConnectionChange(
        fromId: conn.fromQuestId,
        toId: conn.toQuestId,
        patch: patch,
        reversePatch: patch.reverse(current),
        updateMessage: "imported connection update",
      ));
    }
  }

  print("Import recorded. Pending changes: ${cm.pendingCount}");
  print("Call changeManager.push() to upload.");
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