import 'package:flutter/material.dart';
import 'package:wurp/logic/video/video_provider.dart';
import 'package:wurp/main.dart';

import 'feed_view_model.dart';
import 'misc/video_widget.dart';

Widget feedVideos(TickerProvider tickerProvider, RecommendationVideoProvider videoProvider) {
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
                return VideoItem(
                  controller: snapshot.data!.controller!,
                  video: snapshot.data!.video,
                  provider: tickerProvider,
                  videoProvider: videoProvider,
                  userId: auth!.currentUser!.uid,
                  index: index,
                );
              });
        },
        onPageChanged: (value) {
          feedViewModel.switchToVideoAt(value);
        },
      ),
    ],
  );
}
