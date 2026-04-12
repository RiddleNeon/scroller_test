import 'dart:math';

import 'package:flutter/material.dart';
import 'package:wurp/logic/quests/quest.dart';

const int kNoColorValue = 0xFFFFFFFF;

class QuestColorPropagator {
  QuestColorPropagator._();
  
  static bool isColorless(Color c) => c.toARGB32() == kNoColorValue;
  
  static Map<int, List<int>> buildAdjacency({
    required List<Quest> quests,
    required List<Quest> Function(int questId) prerequisiteResolver,
  }) {
    print("BUILDING QUEST ADJACENCY...");
    final adj = <int, List<int>>{for (final q in quests) q.id: []};

    for (final quest in quests) {
      for (final prereq in prerequisiteResolver(quest.id)) {
        adj[quest.id]!.add(prereq.id);
        if (!(adj[prereq.id]?.contains(quest.id) ?? false)) {
          adj[prereq.id] ??= [];
          adj[prereq.id]!.add(quest.id);
        }
      }
    }

    return adj;
  }
  
  static Map<int, Color> compute({
    required List<Quest> quests,
    required Map<int, List<int>> adjacency,
  }) {
    print("COMPUTING QUEST COLORS...");
    final byId = <int, Quest>{for (final q in quests) q.id: q};
    final seeds = quests.where((q) => !isColorless(q.color)).toList();

    if (seeds.isEmpty) {
      return {for (final q in quests) q.id: q.color};
    }

    final seedDistanceMaps = <int, Map<int, double>>{
      for (final seed in seeds)
        seed.id: _dijkstra(
          source: seed.id,
          adjacency: adjacency,
          byId: byId,
        ),
    };

    final result = <int, Color>{};

    for (final quest in quests) {
      if (!isColorless(quest.color)) {
        result[quest.id] = quest.color;
        continue;
      }

      final influences = <_ColorInfluence>[];
      for (final seed in seeds) {
        final distMap = seedDistanceMaps[seed.id]!;
        final d = distMap[quest.id];
        if (d != null && d.isFinite) {
          influences.add(_ColorInfluence(color: seed.color, distance: d));
        }
      }

      if (influences.isEmpty) {
        result[quest.id] = const Color(kNoColorValue);
        continue;
      }

      if (influences.length == 1) {
        result[quest.id] = _singleInfluence(
          seed: influences.first.color,
          distance: influences.first.distance,
          questId: quest.id,
        );
      } else {
        result[quest.id] = _blendColors(influences);
      }
    }

    return result;
  }
  
  static Map<int, double> _dijkstra({
    required int source,
    required Map<int, List<int>> adjacency,
    required Map<int, Quest> byId,
  }) {
    
    print("Running Dijkstra from seed ${byId[source]!.name} (ID: $source)...");
    final dist = <int, double>{source: 0.0};
    final frontier = <({double d, int id})>[
      (d: 0.0, id: source),
    ];

    while (frontier.isNotEmpty) {
      frontier.sort((a, b) => a.d.compareTo(b.d));
      final current = frontier.removeAt(0);

      if (current.d > dist[current.id]!) continue;

      for (final neighborId in (adjacency[current.id] ?? [])) {
        final edgeDist = _pixelDistance(byId[current.id]!, byId[neighborId]!);
        final newDist = current.d + edgeDist;

        if (newDist < (dist[neighborId] ?? double.infinity)) {
          dist[neighborId] = newDist;
          frontier.add((d: newDist, id: neighborId));
        }
      }
    }

    return dist;
  }

  static double _pixelDistance(Quest a, Quest b) {
    print("Calculating pixel distance between '${a.name}' and '${b.name}'...");
    final dx = (a.posX + a.sizeX / 2) - (b.posX + b.sizeX / 2);
    final dy = (a.posY + a.sizeY / 2) - (b.posY + b.sizeY / 2);
    return sqrt(dx * dx + dy * dy).clamp(1.0, double.infinity);
  }
  
  static Color _blendColors(List<_ColorInfluence> influences) {
    print("Blending colors from ${influences.length} influences...");
    double totalW = 0, sinHue = 0, cosHue = 0, satSum = 0, litSum = 0;

    for (final inf in influences) {
      final w = 1.0 / (inf.distance * inf.distance + 1.0);
      final hsl = HSLColor.fromColor(inf.color);
      final rad = hsl.hue * pi / 180.0;

      sinHue += w * sin(rad);
      cosHue += w * cos(rad);
      satSum += w * hsl.saturation;
      litSum += w * hsl.lightness;
      totalW += w;
    }

    final blendedHue =
        (atan2(sinHue / totalW, cosHue / totalW) * 180.0 / pi + 360.0) % 360.0;
    final blendedSat = (satSum / totalW).clamp(0.0, 1.0);
    final blendedLit = (litSum / totalW).clamp(0.0, 1.0);

    return HSLColor.fromAHSL(1.0, blendedHue, blendedSat, blendedLit).toColor();
  }
  
  static Color _singleInfluence({
    required Color seed,
    required double distance,
    required int questId,
  }) {
    print("Applying single influence from seed color for quest ID $questId...");
    
    final hsl = HSLColor.fromColor(seed);
    
    final rng = Random(questId ^ (distance / 50).toInt() * 0x9e3779b9);

    final maxHueShift = (distance / 400.0).clamp(0.0, 1.0) * 40.0;
    final hueShift = (rng.nextDouble() * 2.0 - 1.0) * maxHueShift;

    final satShift = (rng.nextDouble() * 2.0 - 1.0) * 0.08;

    return HSLColor.fromAHSL(
      1.0,
      (hsl.hue + hueShift + 360.0) % 360.0,
      (hsl.saturation + satShift).clamp(0.25, 1.0),
      hsl.lightness,
    ).toColor();
  }
}

class _ColorInfluence {
  const _ColorInfluence({required this.color, required this.distance});
  final Color color;
  final double distance;
}