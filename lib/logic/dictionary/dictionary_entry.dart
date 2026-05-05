class DictionaryPrerequisite {
  final int id;
  final String title;
  final String subject;

  const DictionaryPrerequisite({required this.id, required this.title, required this.subject});
}

class DictionaryEntry {
  final int questId;
  final String title;
  final String description;
  final String subject;
  final double difficulty;
  final List<DictionaryPrerequisite> prerequisites;

  const DictionaryEntry({
    required this.questId,
    required this.title,
    required this.description,
    required this.subject,
    this.difficulty = 0.2,
    this.prerequisites = const [],
  });

  factory DictionaryEntry.fromQuestRow(Map<String, dynamic> row) {
    return DictionaryEntry(
      questId: row['quest_id'] as int,
      title: (row['title'] as String? ?? '').trim(),
      description: row['description'] as String? ?? '',
      subject: (row['subject'] as String? ?? 'General').trim(),
      difficulty: (row['difficulty'] as num?)?.toDouble() ?? 0.2,
    );
  }

  DictionaryEntry copyWith({
    int? questId,
    String? title,
    String? description,
    String? subject,
    double? difficulty,
    List<DictionaryPrerequisite>? prerequisites,
  }) {
    return DictionaryEntry(
      questId: questId ?? this.questId,
      title: title ?? this.title,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      difficulty: difficulty ?? this.difficulty,
      prerequisites: prerequisites ?? this.prerequisites,
    );
  }

  String get route => Uri(
        path: '/dictionary',
        queryParameters: {
          'subject': subject,
          'id': questId.toString(),
        },
      ).toString();

  String get questRoute {
    final query = <String, String>{
      'focus': questId.toString(),
      'zoom': 'true',
    };
    if (subject.trim().isNotEmpty) {
      query['subject'] = subject;
    }
    return Uri(path: '/quests', queryParameters: query).toString();
  }

  String get normalizedTitle => title.trim().toLowerCase();

  String get previewSummary {
    final text = description.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return 'No description available';
    if (text.length <= 140) return text;
    return '${text.substring(0, 137)}...';
  }
}
