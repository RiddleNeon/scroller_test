import 'dart:convert';

class Task {
  
  int id;
  DateTime createdAt;
  String type;
  String createdBy;
  List<String> subjects;
  double xpReward;
  double xpPunishment;
  
  Map<String, dynamic> data; 
  Task({
    required this.id,
    required this.createdAt,
    required this.type,
    required this.createdBy,
    required this.subjects,
    required this.xpReward,
    required this.xpPunishment,
    required this.data,
  });
  
  Task.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        createdAt = DateTime.parse(json['created_at']),
        type = json['type'],
        createdBy = json['created_by'],
        subjects = List<String>.from(json['subjects']),
        xpReward = (json['xp_reward'] as num).toDouble(),
        xpPunishment = (json['xp_punishment'] as num).toDouble(),
        data = switch (json['data']) {
          String raw => Map<String, dynamic>.from(jsonDecode(raw) as Map),
          Map<String, dynamic> map => map,
          Map map => Map<String, dynamic>.from(map),
          null => <String, dynamic>{},
          _ => throw FormatException('Unsupported task data type: ${json['data'].runtimeType}'),
        };
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'created_at': createdAt.toIso8601String(),
    'type': type,
    'created_by': createdBy,
    'subjects': subjects,
    'xp_reward': xpReward,
    'xp_punishment': xpPunishment,
    'data': data,
  };
}