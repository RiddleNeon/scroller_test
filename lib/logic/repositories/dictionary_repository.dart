import 'package:lumox/logic/dictionary/dictionary_entry.dart';
import 'package:lumox/tools/supabase_tests/supabase_login_test.dart';

class DictionaryRepository {
  static final DictionaryRepository instance = DictionaryRepository._();

  DictionaryRepository._();

  Future<List<DictionaryEntry>>? _allEntriesTask;
  final Map<String, Future<List<DictionaryEntry>>> _subjectTasks = {};
  List<DictionaryEntry>? _allEntriesCache;
  final Map<String, List<DictionaryEntry>> _subjectCache = {};

  Future<List<DictionaryEntry>> fetchEntries({String? subject}) {
    final normalizedSubject = subject?.trim();
    if (normalizedSubject == null || normalizedSubject.isEmpty) {
      return _allEntriesTask ??= _loadEntries();
    }

    return _subjectTasks.putIfAbsent(normalizedSubject, () async {
      final cached = _subjectCache[normalizedSubject];
      if (cached != null) return cached;
      final entries = await _loadEntries(subject: normalizedSubject);
      _subjectCache[normalizedSubject] = entries;
      return entries;
    });
  }

  Future<List<String>> fetchSubjects() async {
    final entries = await fetchEntries();
    final seen = <String>{};
    final subjects = <String>[];
    for (final entry in entries) {
      if (entry.subject.isEmpty) continue;
      if (seen.add(entry.subject)) {
        subjects.add(entry.subject);
      }
    }
    subjects.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return subjects;
  }

  Future<DictionaryEntry?> fetchEntryById({required int questId, String? subject}) async {
    final entries = await fetchEntries(subject: subject);
    for (final entry in entries) {
      if (entry.questId == questId) return entry;
    }
    return null;
  }

  Future<Map<String, DictionaryEntry>> fetchTitleIndex({String? subject}) async {
    final entries = await fetchEntries(subject: subject);
    final index = <String, DictionaryEntry>{};
    for (final entry in entries) {
      if (entry.normalizedTitle.isEmpty) continue;
      index.putIfAbsent(entry.normalizedTitle, () => entry);
    }
    return index;
  }

  Future<List<DictionaryEntry>> _loadEntries({String? subject}) async {
    final query = supabaseClient
        .from('quests_latest')
        .select('quest_id, title, description, subject, difficulty')
        .eq('is_deleted', false);
    final rows = subject == null || subject.isEmpty ? await query : await query.eq('subject', subject);

    final baseEntries = (rows as List)
        .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
        .map(DictionaryEntry.fromQuestRow)
        .where((entry) => entry.title.isNotEmpty)
        .toList();

    final questIds = baseEntries.map((entry) => entry.questId).toList();
    final prereqIdsByQuest = <int, List<int>>{};

    if (questIds.isNotEmpty) {
      final connectionRows = await supabaseClient
          .from('quest_connections')
          .select('from_id, to_id, quest_connections_latest!connection_id(is_deleted)')
          .inFilter('from_id', questIds)
          .inFilter('to_id', questIds)
          .limit(10000);

      for (final row in connectionRows as List<dynamic>) {
        final latest = row['quest_connections_latest'] as Map<String, dynamic>?;
        if (latest == null || latest['is_deleted'] == true) continue;
        final fromId = row['from_id'] as int;
        final toId = row['to_id'] as int;
        prereqIdsByQuest.putIfAbsent(toId, () => []).add(fromId);
      }
    }

    final entryById = {for (final entry in baseEntries) entry.questId: entry};

    final entries = baseEntries
        .map((entry) {
          final prereqIds = prereqIdsByQuest[entry.questId] ?? const <int>[];
          final prereqs = <DictionaryPrerequisite>[];
          for (final id in prereqIds) {
            final prereqEntry = entryById[id];
            if (prereqEntry == null) continue;
            prereqs.add(DictionaryPrerequisite(id: prereqEntry.questId, title: prereqEntry.title, subject: prereqEntry.subject));
          }
          return entry.copyWith(prerequisites: prereqs);
        })
        .toList()
      ..sort((a, b) {
        final subjectCompare = a.subject.toLowerCase().compareTo(b.subject.toLowerCase());
        if (subjectCompare != 0) return subjectCompare;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

    if (subject == null || subject.isEmpty) {
      _allEntriesCache = entries;
    }
    return entries;
  }
}

final dictionaryRepository = DictionaryRepository.instance;

