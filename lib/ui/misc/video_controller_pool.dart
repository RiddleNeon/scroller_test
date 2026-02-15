import 'dart:async';

import 'package:video_player/video_player.dart';
import 'package:wurp/logic/video/video_provider.dart';

import '../../logic/video/video.dart';

class VideoControllerPool {
  final Map<int, FutureOr<VideoWidgetController>> _controllers = {};
  final RecommendationVideoProvider provider;

  VideoControllerPool(this.provider);

  Future<VideoWidgetController> get(int index) async {
    return _controllers.putIfAbsent(index, () async {
      final c = VideoWidgetController(await provider.getVideoByIndex(index));
      await c.initialize().then((_) {
        c.setLooping(true);
      });
      return c;
    });
  }

  void playOnly(int index) {
    for (final e in _controllers.entries) {
      if(e.value is Future) {
        Future<VideoWidgetController> future = e.value as Future<VideoWidgetController>;
        if (e.key == index) {
          future.then((value) => value.play);
        } else {
          future.then((value) => value.play);
        }
      } else {
        VideoWidgetController val = e.value as VideoWidgetController;
        if (e.key == index) {
          val.play();
        } else {
          val.pause();
        }
      }
    }
  }
  
  void reset(int index) {
    FutureOr<VideoWidgetController>? futureOr = _controllers[index];
    if(futureOr == null) return;
    if(futureOr is Future) {
      (futureOr as Future).then((value) => value.seekTo(Duration.zero));
    } else {
      futureOr.seekTo(Duration.zero);
    }
  }

  void keepOnly(Set<int> keep) {
    keep.forEach(get);
    final remove = _controllers.keys.where((k) => !keep.contains(k)).toList();
    for (final k in remove) {
      if(_controllers[k] is Future) {
        (_controllers[k] as Future).then((value) => value.dispose());
      } else {
        (_controllers[k] as VideoWidgetController).dispose();
      }
      _controllers.remove(k);
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
  VideoWidgetController(this.video) : super.networkUrl(Uri.parse(video.videoUrl));
}