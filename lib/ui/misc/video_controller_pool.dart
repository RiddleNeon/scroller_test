import 'package:video_player/video_player.dart';

class VideoControllerPool {
  final Map<int, VideoPlayerController> _controllers = {};
  final String url;

  VideoControllerPool(this.url);

  VideoPlayerController get(int index) {
    return _controllers.putIfAbsent(index, () {
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      c.initialize().then((_) {
        c.setLooping(true);
      });
      return c;
    });
  }

  void playOnly(int index) {
    for (final e in _controllers.entries) {
      if (e.key == index) {
        e.value.play();
      } else {
        e.value.pause();
      }
    }
  }

  void keepOnly(Set<int> keep) {
    keep.forEach(get);
    final remove = _controllers.keys.where((k) => !keep.contains(k)).toList();
    for (final k in remove) {
      _controllers[k]?.dispose();
      _controllers.remove(k);
    }
  }

  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
  }
}
