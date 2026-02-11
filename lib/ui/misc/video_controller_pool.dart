import 'dart:async';

import 'package:video_player/video_player.dart';
import 'package:wurp/logic/video/video_provider.dart';

class VideoControllerPool {
  final Map<int, FutureOr<VideoPlayerController>> _controllers = {};
  final VideoProvider provider;

  VideoControllerPool(this.provider);

  Future<VideoPlayerController> get(int index) async {
    return _controllers.putIfAbsent(index, () async {
      final c = VideoPlayerController.networkUrl(Uri.parse((await provider.getVideoByIndex(index))!.videoUrl));
      await c.initialize().then((_) {
        c.setLooping(true);
      });
      return c;
    });
  }

  void playOnly(int index) {
    for (final e in _controllers.entries) {
      if(e.value is Future) {
        Future<VideoPlayerController> future = e.value as Future<VideoPlayerController>;
        if (e.key == index) {
          future.then((value) => value.play);
        } else {
          future.then((value) => value.play);
        }
      } else {
        VideoPlayerController val = e.value as VideoPlayerController;
        if (e.key == index) {
          val.play();
        } else {
          val.pause();
        }
      }
    }
  }
  
  void reset(int index) {
    FutureOr<VideoPlayerController>? futureOr = _controllers[index];
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
        (_controllers[k] as VideoPlayerController).dispose();
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
