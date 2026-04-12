import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:wurp/logic/quests/quest.dart';
import 'package:wurp/logic/quests/quest_change_manager.dart';
import 'package:wurp/logic/quests/quest_connection.dart';
import 'package:wurp/logic/repositories/quest_repository.dart';

class QuestSystem with ChangeNotifier {
  late QuestChangeManager changeManager;

  final Map<int, Quest> _quests = {};
  /// Key format: "$fromId,$toId"
  final Map<String, QuestConnection> _prerequisites = {};

  static String _key(int fromId, int toId) => '$fromId,$toId';

  List<Quest> get quests => _quests.values.toList();

  // ── Prerequisites ──────────────────────────────────────────────────────────

  /// Returns the IDs of all prerequisites for [questId].
  Set<int> prerequisiteIds(int questId) => _prerequisites.values
      .where((conn) => conn.toQuestId == questId)
      .map((conn) => conn.fromQuestId)
      .toSet();

  /// Returns the [Quest] objects for all prerequisites of [questId].
  /// Silently skips IDs that no longer exist in the system.
  List<Quest> prerequisitesOf(int questId) =>
      prerequisiteIds(questId).map((id) => _quests[id]).whereType<Quest>().toList();

  bool isConnected(int fromId, int toId) => _prerequisites.containsKey(_key(fromId, toId));
  QuestConnection? getConnection(int fromId, int toId) => _prerequisites[_key(fromId, toId)];

  // ── Quest mutations ────────────────────────────────────────────────────────

  void upsertQuest(Quest quest) {
    _quests[quest.id] = quest;
    notifyListeners();
  }

  /// Removes the quest and all connections to/from it.
  void removeQuest(int id) {
    _quests.remove(id);
    _prerequisites.removeWhere((_, conn) => conn.fromQuestId == id || conn.toQuestId == id);
    notifyListeners();
  }

  Quest getQuestById(int id) => _quests[id]!;

  Quest? maybeGetQuestById(int id) => _quests[id];

  // ── Connection mutations ───────────────────────────────────────────────────

  void addConnection(int fromId, int toId) {
    if (isConnected(fromId, toId)) return;

    _prerequisites[_key(fromId, toId)] = QuestConnection(fromQuestId: fromId, toQuestId: toId);
    notifyListeners();
  }

  void removeConnection(int fromId, int toId) {
    _prerequisites.remove(_key(fromId, toId));
    notifyListeners();
  }

  void updateConnection(int fromId, int toId, {String? newType, double? newXpRequirement}) {
    final connection = _prerequisites[_key(fromId, toId)];
    if (connection == null) return;
    if (newType != null) connection.type = newType;
    if (newXpRequirement != null) connection.xpRequirement = newXpRequirement;
    notifyListeners();
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  /// Loads quests from the bundled [assets/quests.json] file (offline / dev).
  Future<void> loadFromAssets() async {
    final rawJson = jsonDecode(await rootBundle.loadString('assets/quests.json')) as List;
    final json = rawJson.cast<Map<String, dynamic>>();

    for (final data in json) {
      _quests[data['id'] as int] = Quest.fromJson(data);
    }

    // Wire up prerequisites in a second pass so all quests are already in the
    // map when we start resolving IDs.
    for (final data in json) {
      final prereqIds = (data['prerequisites'] as List?)?.cast<int>();
      if (prereqIds == null || prereqIds.isEmpty) continue;

      assert(prereqIds.every(_quests.containsKey), 'All prerequisite IDs must reference existing quests.');

      for (final prereqId in prereqIds) {
        final toId = data['id'] as int;
        _prerequisites[_key(prereqId, toId)] = QuestConnection(fromQuestId: prereqId, toQuestId: toId);
      }
    }

    notifyListeners();
  }

  /// Fetches quests for [subject] from the server and merges them into the
  /// local map. Existing quests with the same ID are replaced.
  ///
  /// Note: [QuestRepository.fetchQuestsBySubject] must be updated to return
  /// connection data separately (as a [Map<int, Set<int>>]) instead of
  /// populating [Quest.prerequisites] directly.
  Future<void> loadFromServer(String subject) async {
    print("Loading quests for subject: $subject");
    final (fetchedQuests, fetchedConnections) = await questRepo.fetchQuestsBySubject(subject);

    for (final quest in fetchedQuests) {
      _quests[quest.id] = quest;
    }

    print("Fetched quests: ${fetchedQuests.map((q) => q.id).toList()}");

    for (final conn in fetchedConnections) {
      _prerequisites[_key(conn.fromQuestId, conn.toQuestId)] = conn;
    }
    changeManager = QuestChangeManager(questSystem: this, repo: questRepo);

    notifyListeners();
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  String? toJson() {
    try {
      return jsonEncode(
        _quests.values
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
            'isCompleted': q.isCompleted,
            'prerequisites': prerequisitesOf(q.id),
          },
        )
            .toList(),
      );
    } on Exception {
      return null;
    }
  }
}