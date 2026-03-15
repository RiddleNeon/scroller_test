import 'dart:ui';

/// The base quest class. All quests should extend this class.
class Quest {
  final int id;
  String name;
  String description;
  String subject;
  double difficulty;
  double sizeX;
  double sizeY;

  double posX;
  double posY;

  List<Quest> prerequisites = [];

  bool isCompleted = false;

  Offset get position => Offset(posX, posY);

  Size get size => Size(sizeX, sizeY);

  Rect get rect => Rect.fromLTWH(posX, posY, sizeX, sizeY);

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
  });

  Quest.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        name = json['name'] as String,
        description = json['description'] as String,
        subject = json['subject'] as String,
        posX = (json['posX'] as num?)?.toDouble() ?? 0,
        posY = (json['posY'] as num?)?.toDouble() ?? 0,
        difficulty = (json['difficulty'] as num?)?.toDouble() ?? 0.5,
        sizeX = (json['sizeX'] as num?)?.toDouble() ?? 100,
        sizeY = (json['sizeY'] as num?)?.toDouble() ?? 100;
}