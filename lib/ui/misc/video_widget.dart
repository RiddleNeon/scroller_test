import 'dart:math';

import 'package:flutter/material.dart';
import 'package:wurp/logic/video/video.dart';

import '../overlays.dart';

class VideoWidget extends StatelessWidget {
  final int index;
  final TickerProvider provider;
  final Video video;

  const VideoWidget({super.key, required this.index, required this.provider, required this.video});
  
  
  @override
  Widget build(BuildContext context) =>
      AspectRatio(
        aspectRatio: 9 / 16,
        child: Container(
          color: Colors.accents[Random(index).nextInt(Colors.accents.length)],
          child: Stack(
            children: [
              Center(
                child: Text("Video $index with id ${video.id}, created at ${video.createdAt}, title: ${video.title}, author: ${video.authorId}", style: TextStyle(fontSize: 32, color: Colors.white)),
              ),
              PageOverlay(provider: provider, index: index, key: ObjectKey("overlay_$index"),),
            ],
          ),
        ),
      );
}