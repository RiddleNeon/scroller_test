import 'package:wurp/logic/video/video.dart';

import '../feed_recommendation/video_recommender.dart';
import '../local_storage/local_seen_service.dart';

abstract class VideoProvider {
  Future<Video?> getVideoByIndex(int index);

  Future<void> preloadVideos(int count);

  void trackVideoInteraction({
    required Video video,
    required double watchTime,
    required double videoDuration,
    bool liked = false,
    bool shared = false,
    bool commented = false,
    bool saved = false,
  });
}

class RecommendationVideoProvider implements VideoProvider {
  final VideoRecommender _recommender;
  final List<Video> _videoCache = [];

  // ignore: unused_field
  int _currentIndex = 0;

  static const int _preloadThreshold = 5; // Preload when this many videos left
  static const int _preloadBatchSize = 20;

  RecommendationVideoProvider({required String userId})
      : _recommender = VideoRecommender(userId: userId);

  @override
  Future<Video> getVideoByIndex(int index) async {
    print("REQUESTED VIDEO INDEX: $index, CACHE SIZE: ${_videoCache.length}");
    // Preload more videos if we're running low
    if (index >= _videoCache.length - _preloadThreshold) {
      Future loadingFuture = preloadVideos(_preloadBatchSize);
      print("new loading future");
      if(index >= _videoCache.length) {
        // If requested index is beyond current cache, wait for preload to finish
        await loadingFuture;
      }
    }
    

    // Return video if available
    if (index < _videoCache.length) {
      _currentIndex = index;
      return _videoCache[index];
    }
    throw Exception('Video index out of range: $index');
  }
  
  Future<void> _loadInitialVideos() {
    _currentInitVideoLoadingTask ??= _loadInitialVideosInternal();
    return _currentInitVideoLoadingTask!;
  }

  Future<void>? _currentInitVideoLoadingTask;
  Future<void> _loadInitialVideosInternal() async {
    if (_currentInitVideoLoadingTask != null) return _currentInitVideoLoadingTask;
    print("LOADING INITIAL VIDEOS");
    try {
      // For new users, use cold start videos
      final videos = await _recommender.getColdStartVideos(
        limit: _preloadBatchSize,
      );

      _videoCache.addAll(videos);
    } catch (e) {
      print('Error loading initial videos: $e');
    }
  }

  Future<void>? _currentPreloadTask;
  @override
  Future<void> preloadVideos(int count) {
    _currentPreloadTask ??= _preloadMoreVideosInternal(count).then((val) => _currentPreloadTask = null);
    return _currentPreloadTask!;
  }
  
  Future<void> _preloadMoreVideosInternal(int count) async {
    try {      

      final newVideos = await _recommender.getRecommendedVideos(
        limit: count,
      );
      

      _videoCache.addAll(newVideos);
      print("added these videos: ${newVideos.map((e) => e.videoUrl).toList()}");
      for (var value in newVideos) {
        LocalSeenService.markAsSeen(value.id);
      }
    } catch (e) {
      print('Error preloading videos: $e');
    }
  }

  @override
  Future<void> trackVideoInteraction({
    required Video video,
    required double watchTime,
    required double videoDuration,
    bool liked = false,
    bool shared = false,
    bool commented = false,
    bool saved = false,
  }) {    
    return _recommender.trackInteraction(
      watchTime: watchTime,
      videoDuration: videoDuration,
      liked: liked,
      shared: shared,
      commented: commented,
      saved: saved,
      video: video,
    ).catchError((e) {
      print('Error tracking interaction: $e');
    });
  }

  /// Refresh recommendations (call this when user preferences might have changed)
  Future<void> refreshRecommendations() async {
    _videoCache.clear();
    _currentIndex = 0;
    await _loadInitialVideos();
  }

  /// Clear cache
  void clearCache() {
    _videoCache.clear();
    _currentIndex = 0;
  }
}

class BaseAlgorithmVideoProvider implements VideoProvider {
  @override
  Future<Video?> getVideoByIndex(int index) async {
    return null;
  }

  @override
  Future<void> preloadVideos(int count) async {}

  @override
  void trackVideoInteraction({
    required Video video,
    required double watchTime,
    required double videoDuration,
    bool liked = false,
    bool shared = false,
    bool commented = false,
    bool saved = false,
  }) {
    // No-op
  }
}