class QuestConnection {
  final int fromQuestId;
  final int toQuestId;
  final String type;
  final double xpRequirement;
  
  QuestConnection({
    required this.fromQuestId,
    required this.toQuestId,
    this.type = 'prerequisite',
    this.xpRequirement = 0,
  });
}