class QuestConnection {
  final int fromQuestId;
  final int toQuestId;
  String type;
  double xpRequirement;
  
  QuestConnection({
    required this.fromQuestId,
    required this.toQuestId,
    this.type = 'prerequisite',
    this.xpRequirement = 777,
  });
  
  QuestConnection.fromJson(Map<String, dynamic> json)
    : fromQuestId = json['fromQuestId'] as int,
      toQuestId = json['toQuestId'] as int,
      type = json['type'] as String? ?? 'prerequisite',
      xpRequirement = (json['xpRequirement'] as num?)?.toDouble() ?? 999;
  
  QuestConnection copyWith({
    int? fromQuestId,
    int? toQuestId,
    String? type,
    double? xpRequirement,
  }) {
    return QuestConnection(
      fromQuestId: fromQuestId ?? this.fromQuestId,
      toQuestId: toQuestId ?? this.toQuestId,
      type: type ?? this.type,
      xpRequirement: xpRequirement ?? this.xpRequirement,
    );
  }
}