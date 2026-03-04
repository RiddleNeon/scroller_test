import 'package:flutter/material.dart';
import 'package:preload_page_view/preload_page_view.dart';
import 'package:wurp/logic/video/video_provider.dart';
import 'package:wurp/ui/feed_view_model.dart';
import 'package:wurp/ui/router.dart';

import '../base_logic.dart';
import 'widgets/video_widget.dart';

Widget feedVideos(TickerProvider tickerProvider, VideoProvider videoProvider, BuildContext context, {FeedViewModel? feedModel, int itemCount = 5000, int initialPage = 0}) {
  feedModel ??= feedViewModel;
  feedModel.switchToVideoAt(initialPage,
      videoSource:
          videoProvider); //so that the first video starts bc this function only gets called on page switches and the first page hasn't had a switch yet
  return Stack(
    children: [
      ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: PreloadPageView.builder(
          controller: PreloadPageController(
            initialPage: initialPage,
            viewportFraction: 1,
          ),
          itemCount: itemCount,
          scrollDirection: Axis.vertical,
          itemBuilder: (context, index) {
            return FutureBuilder(
                future: feedModel!.getVideoAt(index, videoSource: videoProvider),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Container(
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 72, color: Theme.of(context).colorScheme.error),
                            const SizedBox(height: 16),
                            Text('Error loading Video', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(
                              'An error occurred when loading the videos. Please try again later!',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => routerConfig.go('/search_screen'),
                              child: const Text('Back'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final videoData = snapshot.data?.video;
                  if (videoData == null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.video_library_outlined, size: 80, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                            const SizedBox(height: 20),
                            Text('No More Videos', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            Text('You have seen all available videos! check again tomorrow!',
                                textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 18),
                            ElevatedButton(
                              onPressed: () => routerConfig.go('/search_screen'),
                              child: const Text('Explore videos'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return VideoItem(
                    controller: snapshot.data!.controller!,
                    video: snapshot.data!.video!,
                    provider: tickerProvider,
                    videoProvider: videoProvider,
                    userId: auth!.currentUser!.uid,
                    index: index,
                  );
                });
          },
          onPageChanged: (value) {
            feedModel!.switchToVideoAt(value, videoSource: videoProvider);
          },
        ),
      ),
    ],
  );
}

class VideoFeed extends StatefulWidget {
  final VideoProvider? videoProvider;

  const VideoFeed({super.key, this.videoProvider});

  @override
  State<VideoFeed> createState() => _VideoFeedState();
}

class _VideoFeedState extends State<VideoFeed> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return feedVideos(this, widget.videoProvider ?? videoProvider, context);
  }
}
