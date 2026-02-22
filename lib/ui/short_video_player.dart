import 'package:flutter/material.dart';
import 'package:wurp/logic/video/video_provider.dart';
import 'package:wurp/main.dart';

import 'misc/video_widget.dart';

Widget feedVideos(TickerProvider tickerProvider, RecommendationVideoProvider videoProvider) {
  feedViewModel.switchToVideoAt(0); //so that the first video starts bc this function only gets called on page switches and the first page hasn't had a switch yet
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
