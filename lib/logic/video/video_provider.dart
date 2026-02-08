import 'package:wurp/logic/video/video.dart';

import '../feed_recommendation/video_recommender.dart';

abstract class VideoProvider {
  Future<Video?> getVideoByIndex(int index);
  Future<List<Video>> preloadVideos(int count);
  void trackVideoInteraction({
    required String videoId,
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
  final Set<String> _loadedVideoIds = {};
  int _currentIndex = 0;

  static const int _preloadThreshold = 5; // Preload when this many videos left
  static const int _preloadBatchSize = 20;

  RecommendationVideoProvider({required String userId})
      : _recommender = VideoRecommender(userId: userId);

  @override
  Future<Video?> getVideoByIndex(int index) async {
    // Initialize cache if empty
    if (_videoCache.isEmpty) {
      await _loadInitialVideos();
    }

    // Preload more videos if we're running low
    if (index >= _videoCache.length - _preloadThreshold) {
      _preloadMoreVideos();
    }

    // Return video if available
    if (index < _videoCache.length) {
      _currentIndex = index;
      return _videoCache[index];
    }

    return null;
  }

  @override
  Future<List<Video>> preloadVideos(int count) async {
    if (_videoCache.isEmpty) {
      await _loadInitialVideos();
    }
    return _videoCache.take(count).toList();
  }

  Future<void> _loadInitialVideos() async {
    try {
      // For new users, use cold start videos
      final videos = await _recommender.getColdStartVideos(
        limit: _preloadBatchSize,
      );

      _videoCache.addAll(videos);
      _loadedVideoIds.addAll(videos.map((v) => v.videoUrl));
    } catch (e) {
      print('Error loading initial videos: $e');
    }
  }

  Future<void> _preloadMoreVideos() async {
    try {
      final newVideos = await _recommender.getRecommendedVideos(
        limit: _preloadBatchSize,
        excludeVideoIds: _loadedVideoIds.toList(),
      );

      _videoCache.addAll(newVideos);
      _loadedVideoIds.addAll(newVideos.map((v) => v.videoUrl));
    } catch (e) {
      print('Error preloading videos: $e');
    }
  }

  @override
  void trackVideoInteraction({
    required String videoId,
    required double watchTime,
    required double videoDuration,
    bool liked = false,
    bool shared = false,
    bool commented = false,
    bool saved = false,
  }) {
    // Track asynchronously without waiting
    _recommender.trackInteraction(
      videoId: videoId,
      watchTime: watchTime,
      videoDuration: videoDuration,
      liked: liked,
      shared: shared,
      commented: commented,
      saved: saved,
    ).catchError((e) {
      print('Error tracking interaction: $e');
    });
  }

  /// Refresh recommendations (call this when user preferences might have changed)
  Future<void> refreshRecommendations() async {
    _videoCache.clear();
    _loadedVideoIds.clear();
    _currentIndex = 0;
    await _loadInitialVideos();
  }

  /// Clear cache
  void clearCache() {
    _videoCache.clear();
    _loadedVideoIds.clear();
    _currentIndex = 0;
  }
}

class BaseAlgorithmVideoProvider implements VideoProvider {
  @override
  Future<Video?> getVideoByIndex(int index) async {
    return null;
  }

  @override
  Future<List<Video>> preloadVideos(int count) async {
    return [];
  }

  @override
  void trackVideoInteraction({
    required String videoId,
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