import 'dart:ui';

import 'package:wurp/logic/quests/quest_system.dart';

///the base quest class, all quests should extend this class
class Quest {
  final int id; //a unique identifier for the quest, used for referencing in prerequisites and completion status
  final String name;
  final String description;
  final String subject;
  List<int>? _prerequisites;
  final double posX;
  final double posY;
  final double sizeX;
  final double sizeY;

  final double difficulty; //a value from 0 to 1 representing the difficulty of the quest

  bool get isCompleted => _isCompleted;
  bool _isCompleted = false;
  
  Offset get position => Offset(posX, posY);
  Size get size => Size(sizeX, sizeY);

  Quest({
    required this.id,
    required this.name,
    required this.description,
    required this.subject,
    this.posX = 0,
    this.posY = 0,
    this.difficulty = 0.5,
    this.sizeX = 100,
    this.sizeY = 100,
    List<int>? prerequisites,
  }) {
    if (prerequisites != null) {
      _prerequisites = prerequisites;
    }
    if (prerequisites != null) {
      _prerequisites = prerequisites;
      updateMappedPrerequisites();
    }
  }

  Quest.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      name = json['name'],
      description = json['description'],
      subject = json['subject'],
      posX = json['posX']?.toDouble() ?? 0,
      posY = json['posY']?.toDouble() ?? 0,
      difficulty = json['difficulty']?.toDouble() ?? 0.5,
      sizeX = json['sizeX']?.toDouble() ?? 100,
      sizeY = json['sizeY']?.toDouble() ?? 100 {
    updateMappedPrerequisites();
  }

  set prerequisites(List<Quest> quests) {
    _prerequisites = quests.map((q) => q.id).toList();
    updateMappedPrerequisites();
  }

  void updateMappedPrerequisites() {
    if (_prerequisites != null) {
      _mappedPrerequisites = _prerequisites!.map((e) => QuestSystem.quests[e]!).toList();
    }
  }

  List<Quest>? _mappedPrerequisites = [];

  List<Quest> get prerequisites {
    assert(_mappedPrerequisites != null, 'Prerequisites must be set before accessing them');
    return _mappedPrerequisites!;
  }

  Quest copyWith({
    int? id,
    String? name,
    String? description,
    String? subject,
    double? posX,
    double? posY,
    double? difficulty,
    double? sizeX,
    double? sizeY,
    List<Quest>? prerequisites,
  }) {
    return Quest(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      difficulty: difficulty ?? this.difficulty,
      sizeX: sizeX ?? this.sizeX,
      sizeY: sizeY ?? this.sizeY,
      prerequisites: (prerequisites?.map((e) => e.id).toList()) ?? this._prerequisites ?? this.prerequisites.map((e) => e.id,).toList(),
    );
  }
}
