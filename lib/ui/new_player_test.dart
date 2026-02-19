/*
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fvp/mdk.dart';
import 'package:wurp/ui/native_video_widget.dart';

class NewPlayerTest extends StatelessWidget {
  
  final player = Player();
  NewPlayerTest() {
    player.media = "https://cdn.pixabay.com/video/2025/05/26/281801_large.mp4";
    player.prepare().then((ret) {
      if (ret < 0) {
        print("media open error | invalid or unsupported media");
        return;
      }
      player.updateTexture().then((tex) {
        if (tex < 0) {
          print("video size error | invalid or unsupported media");
          return;
        }
        player.state = PlaybackState.playing;
      });
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("New Player Test")),
      body: Center(
        child: NativeVideoWidget(player: player),
      ),
    );
  }
  
  
}*/
