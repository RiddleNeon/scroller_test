import 'package:wurp/logic/quests/quest.dart';
import 'package:wurp/logic/quests/quest_change_manager.dart';
import 'package:wurp/tools/supabase_tests/supabase_login_test.dart';

import '../../base_logic.dart';

QuestRepository questRepo = QuestRepository();

class QuestRepository {
  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Full snapshot – only used for the initial version of a new quest.
  Map<String, dynamic> _questToMap(Quest quest, String updateMessage, {bool isDeleted = false}) => {
    'quest_id': quest.id,
    'created_by': currentUser.id,
    'update_message': updateMessage,
    'title': quest.name,
    'description': quest.description,
    'subject': quest.subject,
    'difficulty': quest.difficulty,
    'pos_x': quest.posX.toInt(),
    'pos_y': quest.posY.toInt(),
    'size_x': quest.sizeX.toInt(),
    'size_y': quest.sizeY.toInt(),
    'is_deleted': isDeleted,
  };

  Quest _questFromRow(Map<String, dynamic> row) => Quest(
    id: row['quest_id'] as int,
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

  /// Loads all non-deleted quests for [subject] and returns them together with
  /// their prerequisite connections as a [Map<fromId, Set<toId>>].
  Future<(List<Quest>, Map<int, Set<int>>)> fetchQuestsBySubject(String subject) async {
    final questRows = await supabaseClient.from('quests_latest').select().eq('subject', subject).eq('is_deleted', false);

    final Map<int, Quest> questMap = {for (final row in questRows as List<dynamic>) (row['quest_id'] as int): _questFromRow(row as Map<String, dynamic>)};

    if (questMap.isEmpty) return (<Quest>[], <int, Set<int>>{});

    print("getting rows now for quests: ${questMap.keys.toList()}");

    final connectionRows = await supabaseClient
        .from('quest_connections')
        .select('from_id, to_id, quest_connections_latest!connection_id(is_deleted)')
        .inFilter('from_id', questMap.keys.toList())
        .inFilter('to_id', questMap.keys.toList())
        .limit(10000);

    final Map<int, Set<int>> connections = {};
    for (final row in connectionRows as List<dynamic>) {
      final latest = row['quest_connections_latest'] as Map<String, dynamic>?;
      if (latest == null || latest['is_deleted'] == true) continue;

      connections.putIfAbsent(row['from_id'] as int, () => {}).add(row['to_id'] as int);

      print('Found connection: ${row['from_id']} -> ${row['to_id']}');
    }

    print("Fetched connections: ${connections.entries.map((e) => "${e.key} -> ${e.value}").toList()}");

    return (questMap.values.toList(), connections);
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Inserts a new quest row and its first version (full snapshot).
  Future<void> addQuest(Quest quest, [String message = 'initial version']) async {
    print('Adding new quest ${quest.id} for user ${supabaseClient.auth.currentUser?.id}');
    await supabaseClient.from('quests').insert({'id': quest.id, 'created_by': currentUser.id});
    print("inserted");
    await supabaseClient.from('quest_versions').insert(_questToMap(quest, message)).select().single();
  }

  /// Appends a version that contains only the changed fields from [patch].
  /// NULL fields are omitted – the DB trigger fills them from the previous
  /// version via COALESCE.
  Future<void> patchQuest(int questId, QuestPatch patch, String message) async {
    print('Patching quest $questId: $message');
    await supabaseClient
        .from('quest_versions')
        .insert(patch.toSupabaseMap(questId: questId, updateMessage: message, createdBy: currentUser.id))
        .select()
        .single();
  }

  /// Soft-deletes a quest by inserting a version with is_deleted = true.
  Future<void> deleteQuest(Quest quest) async {
    print('Deleting quest ${quest.id}');
    await supabaseClient.from('quest_versions').insert(_questToMap(quest, 'quest deleted', isDeleted: true));
  }

  /// Creates a prerequisite connection: [toId] must be completed before [fromId].
  /// Does NOT mutate local state – the caller (QuestChangeManager) is responsible
  /// for that via [QuestSystem.addConnection].
  Future<void> addConnection(int fromId, int toId) async {
    print('Adding connection from $fromId to $toId');

    final int? existingId =
        (await supabaseClient.from('quest_connections').select('connection_id').eq('from_id', fromId).eq('to_id', toId).maybeSingle())?['connection_id']
            as int?;
    final exists = existingId != null;
    print('Connection already exists? $exists (id: $existingId)');
    final int connectionId;

    if (!exists) {
      print('Inserting new connection into quest_connections');
      final result = await supabaseClient
          .from('quest_connections')
          .insert({'from_id': fromId, 'to_id': toId, 'created_at': DateTime.now().toIso8601String(), 'created_by': currentUser.id})
          .select()
          .single();
      connectionId = result['connection_id'] as int;
    } else {
      connectionId = existingId;
    }

    print('Connection ID to version: $connectionId');

    await supabaseClient.from('quest_connection_versions').insert({
      'connection_id': connectionId,
      'type': 'prerequisite',
      'is_deleted': false,
      'update_message': exists ? 'connection updated' : 'connection added',
      'created_by': currentUser.id,
    });
  }

  /// Soft-deletes a prerequisite connection.
  /// Does NOT mutate local state – the caller (QuestChangeManager) is responsible.
  Future<void> removeConnection(int fromId, int toId) async {
    print('Removing connection from $fromId to $toId');
    final int? existingId =
        (await supabaseClient.from('quest_connections').select('connection_id').eq('from_id', fromId).eq('to_id', toId).maybeSingle())?['connection_id']
            as int?;
    final bool exists = existingId != null;
    final int connectionId;
    if (!exists) {
      connectionId =
          (await supabaseClient.from('quest_connections').insert({'from_id': fromId, 'to_id': toId, 'created_by': currentUser.id}).single())['connection_id']
              as int;
    } else {
      connectionId = existingId;
    }
    await supabaseClient.from('quest_connection_versions').insert({
      'connection_id': connectionId,
      'type': 'prerequisite',
      'is_deleted': true,
      'update_message': 'connection removed',
      'created_by': currentUser.id,
    });
  }
}
