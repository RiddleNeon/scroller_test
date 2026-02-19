import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'feed_view_model.dart';

Widget feedVideos() {
  return Stack(
    children: [
      PageView.builder(
        controller: PageController(
          initialPage: 0,
          viewportFraction: 1,
        ),
        itemCount: 500,
        scrollDirection: Axis.vertical,
        itemBuilder: (context, index) {
          return FutureBuilder(
              future: feedViewModel.getVideoAt(index),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Container(
                    color: Colors.black,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                print("data: ${snapshot.data}");
                return VideoPlayer(snapshot.data!.controller!);
              });
        },
        onPageChanged: (value) {
          feedViewModel.switchToVideoAt(value);
        },
      ),
      /*SafeArea(
        child: Container(
          padding: EdgeInsets.only(top: 20),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
            Text('Following', style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.normal, color: Colors.white70)),
            SizedBox(
              width: 7,
            ),
            Container(
              color: Colors.white70,
              height: 10,
              width: 1.0,
            ),
            SizedBox(
              width: 7,
            ),
            Text('For You', style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold, color: Colors.white))
          ]),
        ),
      ),*/
    ],
  );
}
