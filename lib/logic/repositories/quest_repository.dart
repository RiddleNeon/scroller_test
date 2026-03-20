import 'package:wurp/logic/quests/quest.dart';
import 'package:wurp/tools/supabase_tests/supabase_login_test.dart';

import '../../base_logic.dart';

QuestRepository questRepo = QuestRepository();

class QuestRepository {
  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _questToMap(Quest quest, String updateMessage) => {
    'quest_id': quest.id,
    'created_by': currentUser.id,
    'title': quest.name,
    'description': quest.description,
    'subject': quest.subject,
    'difficulty': quest.difficulty,
    'update_message': updateMessage,
    'pos_x': quest.posX.toInt(),
    'pos_y': quest.posY.toInt(),
    'size_x': quest.sizeX.toInt(),
    'size_y': quest.sizeY.toInt(),
    'is_deleted': quest.isDeleted,
  };

  Quest _questFromRow(Map<String, dynamic> row) => Quest(
    id: row['id'] as int,
    name: row['title'] as String,
    description: row['description'] as String,
    subject: row['subject'] as String,
    difficulty: (row['difficulty'] as num).toDouble(),
    posX: (row['pos_x'] as num).toDouble(),
    posY: (row['pos_y'] as num).toDouble(),
    sizeX: (row['size_x'] as num).toDouble(),
    sizeY: (row['size_y'] as num).toDouble(),
  );

  // ── Fetch ──────────────────────────────────────────────────────────────────

  /// Loads all non-deleted quests for [subject] and wires up their
  /// [Quest.prerequisites] from the connection table.
  Future<List<Quest>> fetchQuestsBySubject(String subject) async {
    // 1. Fetch quests via the view (already joins latest version).
    final questRows = await supabaseClient.from('quests_latest').select().eq('subject', subject).eq('is_deleted', false);

    final Map<int, Quest> questMap = {for (final row in questRows as List<dynamic>) (row['id'] as int): _questFromRow(row as Map<String, dynamic>)};

    if (questMap.isEmpty) return [];

    final connectionRows = await supabaseClient
        .from('quest_connections_full')
        .select('from_id, to_id')
        .inFilter('from_id', questMap.keys.toList())
        .inFilter('to_id', questMap.keys.toList())
        .limit(5000);

    for (final row in connectionRows as List<dynamic>) {
      final fromId = row['from_id'] as int;
      final toId = row['to_id'] as int;
      questMap[fromId]?.prerequisites.add(questMap[toId]!);
    }

    return questMap.values.toList();
  }

  /// Inserts a new quest row and its first version.
  Future<void> addQuest(Quest quest, [String message = 'initial version']) async {
    print('Adding new quest ${quest.id}');
    await supabaseClient.from('quests').insert({'id': quest.id, 'created_by': currentUser.id});
    await updateQuest(quest, message);
  }

  /// Appends a new version snapshot for an existing quest.
  Future<void> updateQuest(Quest quest, String message) async {
    print('Updating quest ${quest.id}: $message');
    await supabaseClient.from('quest_versions').insert(_questToMap(quest, message)).select().single();
  }

  /// Inserts or updates depending on whether the quest already exists in the DB.
  Future<void> upsertQuest(Quest quest, String message) async {
    print('Upserting quest ${quest.id}: $message');
    final existing = await supabaseClient.from('quests').select('id').eq('id', quest.id).maybeSingle();
    if (existing == null) {
      await addQuest(quest, message);
    } else {
      await updateQuest(quest, message);
    }
  }

  /// Soft-deletes a quest by inserting a version with is_deleted = true.
  Future<void> deleteQuest(Quest quest) => upsertQuest(quest.copyWith(isDeleted: true), 'quest deleted');

  /// Creates a prerequisite connection: [toId] must be completed before [fromId].
  /// Does NOT mutate local state – the caller (QuestChangeManager) is responsible
  /// for that via [QuestSystem.addConnection].
  Future<void> addConnection(int fromId, int toId) async {
    print('Adding connection from $fromId to $toId');

    final exists = await supabaseClient.from('quest_connections').select('from_id, to_id').eq('from_id', fromId).eq('to_id', toId).maybeSingle() != null;

    final message = exists ? 'connection updated' : 'connection added';

    if (!exists) {
      await supabaseClient.from('quest_connections').insert({'from_id': fromId, 'to_id': toId, 'created_by': currentUser.id});
    }

    await supabaseClient.from('quest_connection_versions').insert({
      'from_id': fromId,
      'to_id': toId,
      'type': 'prerequisite',
      'is_deleted': false,
      'update_message': message,
      'created_by': currentUser.id,
    });
  }

  /// Soft-deletes a prerequisite connection.
  /// Does NOT mutate local state – the caller (QuestChangeManager) is responsible.
  Future<void> removeConnection(int fromId, int toId) async {
    print('Removing connection from $fromId to $toId');
    await supabaseClient.from('quest_connection_versions').insert({
      'from_id': fromId,
      'to_id': toId,
      'type': 'prerequisite',
      'is_deleted': true,
      'update_message': 'connection removed',
      'created_by': currentUser.id,
    });
  }
}
