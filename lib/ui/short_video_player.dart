import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:preload_page_view/preload_page_view.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/logic/video/video_provider.dart';
import 'package:wurp/ui/feed_view_model.dart';
import 'package:wurp/ui/router.dart';
import 'package:wurp/ui/screens/auth_screen.dart';

import '../base_logic.dart';
import 'widgets/video_widget.dart';

Widget feedVideos(
  TickerProvider tickerProvider,
  VideoProvider videoProvider,
  BuildContext context, {
  FeedViewModel? feedModel,
  int itemCount = 5000,
  int initialPage = 0,
  void Function(bool)? onLikeChanged,
  PreloadPageController? pageController,
  void Function(int)? onPageChanged,
}) {
  feedModel ??= feedViewModel;
  return Stack(
    children: [
      ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: PreloadPageView.builder(
          controller: pageController ?? PreloadPageController(initialPage: initialPage, viewportFraction: 1),
          itemCount: itemCount,
          preloadPagesCount: 2,
          scrollDirection: Axis.vertical,
          itemBuilder: (context, index) {
            if (index == 50) {
              return _buildStopWidget('why are you still watching? Is it really THAT interesting???', CupertinoIcons.question_diamond_fill, context);
            }
            if (index == 100) return _buildStopWidget('come on man, are you still doing this?', CupertinoIcons.exclamationmark, context);
            if (index == 150) {
              return _buildStopWidget('dont you have better things to do???', CupertinoIcons.exclamationmark_circle_fill, context); //
            }
            if (index == 200) return _buildStopWidget('ok this is getting out of hand', Icons.warning_amber_outlined, context);
            if (index == 250) {
              return _buildStopWidget(
                'alright thats it, stop watching videos and go touch some grass or something',
                Icons.warning_amber_outlined,
                context,
              ); // also at this point you should probably seek help, maybe you have an addiction or something
            }
            if (index == 300) {
              return _buildStopWidget(
                'bro wtf',
                Icons.warning_amber_outlined,
                context,
              ); // 300 is the point of no return, if you watch 300 videos in a row you are officially a lost cause
            }
            if (index == 350) return _buildStopWidget('this is just sad now', Icons.warning, context);
            if (index == 400) return _buildStopWidget('ok you win, you can keep watching but I will pray for you', Icons.warning, context);
            if (index == 449) return _buildStopWidget('congrats you made it to the end of the feed, you can stop now', Icons.warning_sharp, context);
            if (index == 450) {
              Future.delayed(const Duration(seconds: 4), () {
                userRepository.selfBanUserSupabase();
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) {
                        return const LoginScreen();
                      },
                    ),
                  );
                }
              });
              return _buildStopWidget(
                'well youre banned now. invest your time into something better, like therapy or sth. idk. \n Here is the number of the National Rehab Hotline of the Us: 866-210-1303. lol',
                Icons.celebration_outlined,
                context,
              );
            }
            if (index > 450) {
              feedModel?.switchToVideoAt(index + 1, videoSource: videoProvider);
              return _buildStopWidget('Bye!', Icons.door_back_door_outlined, context);
            }

            return FutureBuilder(
              future: feedModel!.getVideoAt(index, videoSource: videoProvider),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return FutureBuilder(
                    future: videoProvider.getVideoByIndex(index),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data?.thumbnailUrl == null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return FittedBox(
                        fit: BoxFit.fitHeight,
                        child: CachedNetworkImage(imageUrl: snapshot.data!.thumbnailUrl!),
                      );
                    },
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
                          ElevatedButton(onPressed: () => routerConfig.go('/search'), child: const Text('Back')),
                        ],
                      ),
                    ),
                  );
                }

                final videoData = snapshot.data!.video;
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
                          Text(
                            'You have seen all available videos! check again tomorrow!',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton(onPressed: () => routerConfig.go('/search'), child: const Text('Explore videos')),
                        ],
                      ),
                    ),
                  );
                }

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoItem(
                      controller: snapshot.data!.controller!,
                      video: snapshot.data!.video!,
                      provider: tickerProvider,
                      videoProvider: videoProvider,
                      userId: currentAuthUserId(),
                      index: index,
                      onLikeChanged: onLikeChanged,
                    ),
                  ],
                );
              },
            );
          },
          onPageChanged: (value) {
            feedModel!.switchToVideoAt(value, videoSource: videoProvider);
            onPageChanged?.call(value);
          },
        ),
      ),
    ],
  );
}

Widget _buildStopWidget(String label, IconData icon, BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.all(28.0),
    child: Container(
      width: 190,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.75)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: cs.primary, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class VideoFeed extends StatefulWidget {
  final VideoProvider? videoProvider;
  final int? initialPage;

  const VideoFeed({super.key, this.videoProvider, this.initialPage});

  @override
  State<VideoFeed> createState() => _VideoFeedState();
}

class _VideoFeedState extends State<VideoFeed> with TickerProviderStateMixin {
  late final PreloadPageController _pageController;
  late final int _initialPage;

  @override
  void initState() {
    super.initState();
    _initialPage = widget.initialPage ?? (widget.videoProvider == null ? feedViewModel.currentIndex : 0);
    _pageController = PreloadPageController(initialPage: _initialPage, viewportFraction: 1);
    // Ensure initial page starts playing even when opening the feed at index 0.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(feedViewModel.switchToVideoAt(_initialPage, videoSource: widget.videoProvider ?? videoProvider));
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: feedVideos(
        this,
        widget.videoProvider ?? videoProvider,
        context,
        initialPage: _initialPage,
        pageController: _pageController,
      ),
    );
  }
}

class SingleVideoProvider implements VideoProvider {
  SingleVideoProvider(this.video);

  final Video video;

  @override
  Future<Video?> getVideoByIndex(int index) async {
    if (index != 0) return null;
    return video;
  }

  @override
  Future<void> preloadVideos(int count) async {}
}

