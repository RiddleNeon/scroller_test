import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:wurp/ui/video_container.dart';
import 'package:wurp/ui/video_description.dart';


Widget videoCard(VideoContainer video) {
  return Stack(
    children: [
      video.controller != null
          ? GestureDetector(
        onTap: () {
          if (video.controller!.value.isPlaying) {
            video.controller?.pause();
          } else {
            video.controller?.play();
          }
        },
        child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: video.controller?.value.size.width ?? 0,
                height: video.controller?.value.size.height ?? 0,
                child: VideoPlayer(video.controller!),
              ),
            )),
      )
          : Container(
        color: Colors.black,
        child: Center(
          child: Text("Loading"),
        ),
      ),
      /*Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              VideoDescription(video.video.authorId, video.video.title, ""), //todo song info
            ],
          ),
          SizedBox(height: 20)
        ],
      ),*/
    ],
  );
}