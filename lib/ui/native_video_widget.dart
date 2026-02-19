/*

import 'package:flutter/cupertino.dart';
import 'package:fvp/mdk.dart';

class NativeVideoWidget extends StatelessWidget {
  final Player player;
  
  NativeVideoWidget({required this.player});
  
  @override
  Widget build(BuildContext context) {
    Widget result = FutureBuilder(
      future: player.textureSize,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final Size size = snapshot.data! as Size;
          return SizedBox(
            width: size.width.toDouble(),
            height: size.height.toDouble(),
            child: ValueListenableBuilder<int?>(
              valueListenable: player.textureId,
              builder: (context, id, _) {
                if (id == null) {
                  return const SizedBox.shrink();
                } else {
                  return Texture(textureId: id);
                }
              },
            ),
          );
        } else {
          return const Center(child: CupertinoActivityIndicator());
        }
      },
    );
    return result;
  }

  doPlayVideo(String url) async {
    if (player.state != PlaybackState.stopped) {
      player.state = PlaybackState.stopped;
      player.waitFor(PlaybackState.stopped);
    }
    player.media = url;

    final ret = await player.prepare();
    if (ret < 0) {
      print("media open error | invalid or unsupported media");
      return;
    }
    final tex = await player.updateTexture();
    if (tex < 0) {
      print("video size error | invalid or unsupported media");
      return;
    }

    player.state = PlaybackState.playing;
  }
  
  
  
}*/
