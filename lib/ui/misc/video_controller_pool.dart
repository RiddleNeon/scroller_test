import 'dart:async';

import 'package:video_player/video_player.dart';
import 'package:wurp/logic/video/video_provider.dart';

import '../../logic/video/video.dart';

class VideoControllerPool {
  final Map<int, FutureOr<VideoWidgetController>> _controllers = {};
  final RecommendationVideoProvider provider;
  int _lastFocusedIndex = 0;

  VideoControllerPool(this.provider);
  
  Future<VideoWidgetController> get(int index) async {
    return _controllers.putIfAbsent(index, () async {
      print("initializing video controller for index $index");
      final c = provider.getVideoByIndex(index).then((video) {
        final c = VideoWidgetController(video);
        c.initialize().then((_) {
          print("initialized video controller for index $index");
          if (_lastFocusedIndex == index) {
            c.play();
          }
        }).catchError((e) {
          print('Failed to initialize video controller for index $index: $e');
          throw e;
        });
        return c;
      }).catchError((e) {
        print('Failed to get video for index $index: $e');
        throw e;
      });
      return c;
    });
  }

  void playOnly(int index) {
    if (_lastFocusedIndex != index) {
      _lastFocusedIndex = index;
    }

    for (final e in _controllers.entries) {
      if(e.value is Future) {
        Future<VideoWidgetController> future = e.value as Future<VideoWidgetController>;
        if (e.key == index) {
          future.then((value) {
            if (value.value.isInitialized) value.play();
          });
        } else {
          future.then((value) {
            if (value.value.isInitialized) value.pause();
          });
        }
      } else {
        VideoWidgetController val = e.value as VideoWidgetController;
        if (e.key == index) {
          if (val.value.isInitialized) val.play();
        } else {
          if (val.value.isInitialized) val.pause();
        }
      }
    }
  }

  void reset(int index) {
    FutureOr<VideoWidgetController>? futureOr = _controllers[index];
    if(futureOr == null) return;
    if(futureOr is Future) {
      (futureOr as Future).then((value) {
        if (value.value.isInitialized) {
          value.seekTo(Duration.zero);
        }
      });
    } else {
      if (futureOr.value.isInitialized) {
        futureOr.seekTo(Duration.zero);
      }
    }
  }

  void keepOnly(Set<int> keep) {
    final extendedKeep = <int>{};
    for (final k in keep) {
      extendedKeep.add(k);
      extendedKeep.add(k + 1);
    }
    
    extendedKeep.forEach((element) => get(element)); // ensure all controllers to keep are created

    final remove = _controllers.keys.where((k) => !extendedKeep.contains(k)).toList();

    for (final k in remove) {
      final controllerOrFuture = _controllers.remove(k);

      if (controllerOrFuture != null) {
        if (controllerOrFuture is Future) {
          (controllerOrFuture as Future).then((controller) {
            Future.delayed(Duration(milliseconds: 200), () {
              controller.dispose();
            });
          });
        } else {
          Future.delayed(Duration(milliseconds: 200), () {
            (controllerOrFuture).dispose();
          });
        }
      }
    }
  }

  void dispose() {
    for (final c in _controllers.values) {
      if(c is Future) {
        (c as Future).then((value) => value.dispose());
      } else {
        c.dispose();
      }
    }
    _controllers.clear();
  }
}


class VideoWidgetController extends VideoPlayerController {
  Video video;

  VideoWidgetController(this.video) : super.networkUrl(
    Uri.parse(video.videoUrl),
    videoPlayerOptions: VideoPlayerOptions(
      mixWithOthers: false,
      allowBackgroundPlayback: false,
    ),
  );

  @override
  Future<void> initialize() async {
    try {
      await super.initialize();
      setVolume(1.0);

    } catch (e) {
      rethrow;
    }
  }
}