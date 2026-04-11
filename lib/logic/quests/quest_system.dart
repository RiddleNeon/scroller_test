import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:wurp/logic/quests/quest.dart';
import 'package:wurp/logic/quests/quest_change_manager.dart';
import 'package:wurp/logic/repositories/quest_repository.dart';

class QuestSystem with ChangeNotifier {
  late QuestChangeManager changeManager;
  
  final Map<int, Quest> _quests = {};
  final Map<int, Set<int>> _prerequisites = {};

  List<Quest> get quests => _quests.values.toList();

  // ── Prerequisites ──────────────────────────────────────────────────────────

  /// Returns the IDs of all prerequisites for [questId].
  Set<int> prerequisiteIds(int questId) => _prerequisites[questId] ?? const {};

  /// Returns the [Quest] objects for all prerequisites of [questId].
  /// Silently skips IDs that no longer exist in the system.
  List<Quest> prerequisitesOf(int questId) => prerequisiteIds(questId)
      .map((id) => _quests[id])
      .whereType<Quest>()
      .toList();
  
  bool isConnected(int fromId, int toId) => _prerequisites[fromId]?.contains(toId) ?? false;

  // ── Quest mutations ────────────────────────────────────────────────────────

  void upsertQuest(Quest quest) {
    _quests[quest.id] = quest;
    notifyListeners();
  }

  /// Removes the quest and all connections to/from it.
  void removeQuest(int id) {
    _quests.remove(id);
    _prerequisites.remove(id);                      // outgoing connections
    for (final deps in _prerequisites.values) {     // incoming connections
      deps.remove(id);
    }
    notifyListeners();
  }

  Quest getQuestById(int id) => _quests[id]!;
  Quest? maybeGetQuestById(int id) => _quests[id];

  // ── Connection mutations ───────────────────────────────────────────────────

  void addConnection(int fromId, int toId) {
    _prerequisites.putIfAbsent(fromId, () => {}).add(toId);
    notifyListeners();
  }

  void removeConnection(int fromId, int toId) {
    print("Attempting to remove connection from $fromId to $toId. Current connections from $fromId: ${_prerequisites[fromId]} and from $toId: ${_prerequisites[toId]}");
    _prerequisites[fromId]!.remove(toId);
    print("Removed connection from $fromId to $toId. Remaining connections from $fromId: ${_prerequisites[fromId]}");
    notifyListeners();
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  /// Loads quests from the bundled [assets/quests.json] file (offline / dev).
  Future<void> loadFromAssets() async {
    final rawJson =
    jsonDecode(await rootBundle.loadString('assets/quests.json')) as List;
    final json = rawJson.cast<Map<String, dynamic>>();

    for (final data in json) {
      _quests[data['id'] as int] = Quest.fromJson(data);
    }

    // Wire up prerequisites in a second pass so all quests are already in the
    // map when we start resolving IDs.
    for (final data in json) {
      final prereqIds = (data['prerequisites'] as List?)?.cast<int>();
      if (prereqIds == null || prereqIds.isEmpty) continue;

      assert(
      prereqIds.every(_quests.containsKey),
      'All prerequisite IDs must reference existing quests.',
      );

      _prerequisites[data['id'] as int] = prereqIds.toSet();
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

    for (final entry in fetchedConnections.entries) {
      _prerequisites[entry.key] = entry.value.toSet();
    }

    print("fetched connections: ${fetchedConnections.entries.map((e) => "${e.key} -> ${e.value}").toList()}");
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
            'prerequisites': (_prerequisites[q.id] ?? {}).toList(),
          },
        )
            .toList(),
      );
    } on Exception {
      return null;
    }
  }
}