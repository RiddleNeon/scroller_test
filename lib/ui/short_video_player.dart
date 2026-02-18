import 'package:flutter/material.dart';
import 'package:wurp/ui/video_card.dart';
import 'package:wurp/ui/video_container.dart';
import 'feed_view_model.dart';

Widget feedVideos(FeedViewModel feedViewModel) {
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
          // Pass `index` (not currentIndex) so each page loads its own video
          return FutureBuilder<VideoContainer>(
            future: feedViewModel.getVideoAt(index),
            builder: (context, snapshot) {
              if (snapshot.data != null) {
                return videoCard(snapshot.data!);
              }
              return const Center(child: CircularProgressIndicator());
            },
          );
        },
        onPageChanged: (value) {
          feedViewModel.switchToVideoAt(value);
        },
      ),
      SafeArea(
        child: Container(
          padding: const EdgeInsets.only(top: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Following',
                style: TextStyle(
                  fontSize: 17.0,
                  fontWeight: FontWeight.normal,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                color: Colors.white70,
                height: 10,
                width: 1.0,
              ),
              const SizedBox(width: 7),
              const Text(
                'For You',
                style: TextStyle(
                  fontSize: 17.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}