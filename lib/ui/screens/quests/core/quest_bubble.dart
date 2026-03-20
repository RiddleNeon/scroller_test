import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wurp/logic/quests/quest.dart';
import 'package:wurp/ui/screens/quests/core/quest_bubbles_overlay.dart';

class QuestBubble extends StatelessWidget {
  final Quest quest;

  const QuestBubble({
    super.key,
    required this.quest,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = getColorFromSeed(quest.id);
    final darkColor = _adjustColor(baseColor, lightness: 0.28, saturation: 0.60);
    final midColor = _adjustColor(baseColor, lightness: 0.28, saturation: 0.60);
    final glowColor = _adjustColor(baseColor, lightness: 0.60, saturation: 0.75);

    return Container(
      width: quest.sizeX,
      height: quest.sizeY,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(quest.sizeY / 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            midColor,
            darkColor,
          ],
        ),
        border: Border.all(
          color: glowColor.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(quest.sizeY / 2),
        child: Stack(
          children: [
            Positioned.fill(
              child: InkWell(
                onTap: () {
                  print("Tapped quest ${quest.name} (ID: ${quest.id})");
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const QuestBubblesOverlay()));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        quest.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


Color getColorFromSeed(int seed) {
  final rng = Random(seed);
  final hue = rng.nextDouble() * 360;
  final saturation = 0.55 + rng.nextDouble() * 0.25;
  final lightness = 0.45 + rng.nextDouble() * 0.15;
  return HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
}

Color _adjustColor(Color color, {double? lightness, double? saturation}) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness(lightness ?? hsl.lightness)
      .withSaturation(saturation ?? hsl.saturation)
      .toColor();
}