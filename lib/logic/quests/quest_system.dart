import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:wurp/logic/quests/quest.dart';
import 'package:wurp/logic/repositories/quest_repository.dart';

class QuestSystem with ChangeNotifier {
  final Map<int, Quest> _allQuests = {};

  Map<int, Quest> _quests = {};
  List<Quest> get quests => _quests.values.toList();

  final Map<int, Set<int>> _prerequisites = {};

  // ── Internal ───────────────────────────────────────────────────────────────

  void _revalidate() {
    _quests = Map.fromEntries(
      _allQuests.entries.where((e) => !e.value.isDeleted),
    );
  }

  // ── Quest mutations ────────────────────────────────────────────────────────

  void upsertQuest(Quest quest) {
    _allQuests[quest.id] = quest;
    _revalidate();
    notifyListeners();
  }

  void removeQuestById(int id) {
    _allQuests.removeWhere((key, value) => value.id == id);
    _revalidate();
    notifyListeners();
  }
  
  void removeQuest(Quest quest) => removeQuestById(quest.id);
  
  @Deprecated("use upsertQuest instead")
  void moveQuest(int id, double newX, double newY) {
    final quest = _allQuests[id];
    if (quest == null) return;
    quest.posX = newX;
    quest.posY = newY;
    // No revalidate needed; isDeleted didn't change
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
    _prerequisites[fromId]?.remove(toId);
    notifyListeners();
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  /// Loads quests from the bundled [assets/quests.json] file (offline / dev).
  Future<void> loadFromAssets() async {
    final rawJson =
    jsonDecode(await rootBundle.loadString('assets/quests.json')) as List;
    final json = rawJson.cast<Map<String, dynamic>>();

    for (final data in json) {
      upsertQuest(Quest.fromJson(data));
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
      _quests[data['id'] as int]!.prerequisites =
          prereqIds.map((id) => _quests[id]!).toList();
    }

    notifyListeners();
  }

  /// Fetches quests for [subject] from the server and merges them into the
  /// local map. Existing quests with the same ID are replaced.
  Future<void> loadFromServer(String subject) async {
    final fetched = await questRepo.fetchQuestsBySubject(subject);
    for (final quest in fetched) {
      upsertQuest(quest);
    }
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
            'prerequisites': q.prerequisites.map((p) => p.id).toList(),
          },
        )
            .toList(),
      );
    } on Exception {
      return null;
    }
  }
}

QuestSystem questSystem = QuestSystem();