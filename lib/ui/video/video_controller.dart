import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:wurp/ui/misc/shorts_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

abstract class VideoController {
  FutureOr<void> play();

  FutureOr<void> pause();

  FutureOr<void> dispose();

  FutureOr<void> init();

  FutureOr<void> setLooping(bool looping);

  bool get isPlaying;

  bool get isInitialized;

  FutureOr<bool> get isLooping;

  Future<void> seekTo(Duration position);

  FutureOr<Size> get videoSize;

  double get aspectRatio;

  Duration get duration;

  FutureOr<Duration> get position;

  void addListener(void Function(bool playing) listener);

  void removeListener(void Function(bool playing) listener);

  Widget buildVideoWidget(BuildContext context, {Key? key, String? thumbnailUrl});

  factory VideoController.fromVideoUrl(String url, {bool looping = true}) {
    String? videoId = YoutubePlayerController.convertUrlToId(url);
    print("CREATING VIDEO CONTROLLER for URL: $url, extracted video ID: $videoId");
    if (videoId != null) {
      return YoutubeVideoController(
        YoutubePlayerController.fromVideoId(
          videoId: videoId,
          autoPlay: true,
          params: const YoutubePlayerParams(
            showControls: false,
            showFullscreenButton: false,
            mute: false,
            loop: true,
            playsInline: true,
            pointerEvents: .none,
            enableCaption: false,
          ),
        ),
      );
    } else {
      return MemoryVideoController(VideoPlayerController.networkUrl(Uri.parse(url), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true)));
    }
  }
}

class MemoryVideoController implements VideoController {
  final VideoPlayerController controller;

  @override
  Future<void> dispose() async {
    await controller.dispose();
  }

  @override
  Future<void> init() {
    return controller.initialize();
  }

  @override
  bool get isInitialized => controller.value.isInitialized;

  @override
  FutureOr<bool> get isLooping => controller.value.isLooping;

  @override
  bool get isPlaying => controller.value.isPlaying;

  @override
  Future<void> pause() => controller.pause();

  @override
  Future<void> play() => controller.play();

  @override
  Future<void> setLooping(bool looping) {
    return controller.setLooping(looping);
  }

  MemoryVideoController(this.controller);

  @override
  Future<void> seekTo(Duration position) => controller.seekTo(position);

  @override
  double get aspectRatio => controller.value.aspectRatio;

  @override
  Duration get duration => controller.value.duration;

  @override
  Duration get position => controller.value.position;

  @override
  Size get videoSize => controller.value.size;

  final Map<void Function(bool), VoidCallback> _listeners = {};

  @override
  void addListener(void Function(bool playing) listener) {
    void internal() {
      listener(controller.value.isPlaying);
    }

    _listeners[listener] = internal;
    controller.addListener(internal);
  }

  @override
  void removeListener(void Function(bool playing) listener) {
    final internal = _listeners.remove(listener);
    if (internal != null) {
      controller.removeListener(internal);
    }
  }

  @override
  Widget buildVideoWidget(BuildContext context, {Key? key, String? thumbnailUrl}) {
    return isInitialized ? VideoPlayer(controller, key: key) : CachedNetworkImage(imageUrl: thumbnailUrl ?? '', fit: BoxFit.cover, key: key);
  }
}

class YoutubeVideoController implements VideoController {
  YoutubePlayerController controller;

  bool _disposed = false;

  @override
  FutureOr<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _subscriptions.forEach((listener, subscription) => subscription.cancel());
    _subscriptions.clear();
    await controller.close();
  }

  
  
  YoutubeVideoController(this.controller) {
    bool ready = false;
/*    controller.listen((event) {
      if (!ready &&
          event.playerState != PlayerState.unknown) {
        ready = true;
      }
    });*/
  }
  
  
  
  @override
  Future<void> init() async {}

  @override
  bool get isInitialized => controller.metadata.videoId.isNotEmpty;

  @override
  FutureOr<bool> get isLooping => controller.params.loop;

  @override
  bool get isPlaying => controller.value.playerState == PlayerState.playing;

  @override
  FutureOr<void> pause() => controller.pauseVideo();

  @override
  FutureOr<void> play() => controller.playVideo();

  @override
  FutureOr<void> setLooping(bool looping) {}

  @override
  Future<void> seekTo(Duration position) => controller.seekTo(seconds: position.inMilliseconds / 1000.0);

  @override
  double get aspectRatio => 9 / 16;

  @override
  Duration get duration => controller.value.metaData.duration;

  @override
  Future<Duration> get position async => Duration(milliseconds: ((await controller.currentTime) * 1000).round());

  @override
  FutureOr<Size> get videoSize async {
    String qualityRaw = (await controller.videoData).videoQuality;
    final parts = qualityRaw.split('x');
    return Size(double.parse(parts[0]), double.parse(parts[1]));
  }

  final Map<void Function(bool playing), StreamSubscription> _subscriptions = {};

  @override
  void addListener(void Function(bool playing) listener) {
    final subscription = controller.listen((event) {
      listener(event.playerState == PlayerState.playing);
    });
    _subscriptions[listener] = subscription;
  }

  @override
  void removeListener(void Function(bool playing) listener) {
    final subscription = _subscriptions.remove(listener);
    subscription?.cancel();
  }

  @override
  Widget buildVideoWidget(BuildContext context, {Key? key, String? thumbnailUrl}) {
    print("Building YouTube video widget with thumbnail: $thumbnailUrl");
    // return ShortVideoPage(controller: controller, thumbnailUrl: thumbnailUrl, key: key);
    return const SizedBox();
  }
}
