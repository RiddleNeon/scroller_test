import 'dart:async';

import 'package:wurp/logic/video/video_provider.dart';
import 'package:wurp/main.dart';

import 'video_container.dart';

FeedViewModel get feedViewModel => _feedViewModel ??= FeedViewModel();
FeedViewModel? _feedViewModel;

class FeedViewModel {
  static RecommendationVideoProvider videoSource = RecommendationVideoProvider(userId: auth!.currentUser!.uid);

  FeedViewModel();

  // Stores futures so we never load the same index twice
  final Map<int, Future<VideoContainer>> _videoFutures = {};
  // Tracks which containers are fully loaded and not yet disposed
  final Map<int, VideoContainer> _loadedContainers = {};
  // Tracks indices that have been disposed so we never use them again
  final Set<int> _disposedIndices = {};

  int _currentIndex = 0;

  /// Returns (and starts loading) the video at [index].
  /// Safe to call multiple times for the same index.
  Future<VideoContainer> getVideoAt(int index) {
    if (_disposedIndices.contains(index)) {
      _videoFutures.remove(index);
      _disposedIndices.remove(index);
    }

    _videoFutures[index] ??= _loadContainer(index);

    // Only pre-load the NEXT video – avoid spawning multiple decoders at once.
    // Do NOT pre-load if we already have 2+ containers loaded (memory pressure).
    final next = index + 1;
    if (_loadedContainers.length < 2 && !_disposedIndices.contains(next)) {
      _videoFutures[next] ??= _loadContainer(next);
    }

    return _videoFutures[index]!;
  }

  Future<VideoContainer> _loadContainer(int index) async {
    final video = await videoSource.getVideoByIndex(index);
    final container = VideoContainer(video: video);
    await container.loadController();
    _loadedContainers[index] = container;
    return container;
  }

  /// Called by the PageView whenever the user lands on a new page.
  Future<void> switchToVideoAt(int index) async {
    final previous = _currentIndex;
    _currentIndex = index;

    // 1. Dispose far-away containers FIRST to free decoder slots and audio focus
    //    before the new player tries to acquire them.
    final indicesToDispose = _loadedContainers.keys
        .where((i) => (i - index).abs() > 2)
        .toList();
    Future.wait(indicesToDispose.map(_disposeIndex));

    // 2. Pause the previous video
    if (previous != index && !_disposedIndices.contains(previous)) {
      final prev = _loadedContainers[previous];
      await prev?.controller?.pause();
      await prev?.controller?.seekTo(Duration.zero);
    }

    // 3. Now play the current video (decoder slot is free, audio focus available)
    final current = await getVideoAt(index);
    if (!_disposedIndices.contains(index)) {
      await current.controller?.play();
    }

    // 4. Trigger pre-load of next video now that we have headroom
    final next = index + 1;
    if (!_disposedIndices.contains(next)) {
      _videoFutures[next] ??= _loadContainer(next);
    }
  }

  Future<void> _disposeIndex(int index) async {
    if (_disposedIndices.contains(index)) return;
    _disposedIndices.add(index);

    final container = _loadedContainers.remove(index);
    _videoFutures.remove(index);

    await container?.controller?.dispose();
  }
}