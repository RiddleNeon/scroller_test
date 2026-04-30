import 'package:lumox/logic/video/video.dart';

import '../../base_logic.dart';
import '../feed_recommendation/video_recommender_base.dart';
import '../feed_recommendation/video_recommender.dart';

abstract class VideoProvider {
  Future<Video?> getVideoByIndex(int index, {bool useYoutubeVideos = false});

  Future<void> preloadVideos(int count, {bool useYoutubeVideos = false});
}

class RecommendationVideoProvider implements VideoProvider {
  final VideoRecommender _recommender;
  final List<Video> _videoCache = [];

  // ignore: unused_field
  int _currentIndex = 0;

  static const int _preloadThreshold = 5; // Preload when this many videos left
  static const int _preloadBatchSize = 20;

  RecommendationVideoProvider() : _recommender = VideoRecommender();

  @override
  Future<Video?> getVideoByIndex(int index, {bool retry = true, bool useYoutubeVideos = false}) async {
    Future? loadingFuture;
    // Preload more videos if we're running low
    if (index >= _videoCache.length - _preloadThreshold) {
      loadingFuture = preloadVideos(_preloadBatchSize, useYoutubeVideos: useYoutubeVideos);
      if (index >= _videoCache.length) {
        // If requested index is beyond current cache, wait for preload to finish
        await loadingFuture;
      }
    }

    // Return video if available
    if (index < _videoCache.length) {
      _currentIndex = index;
      return _videoCache[index];
    } else if (retry) {
      await loadingFuture;
      print("Retrying getVideoByIndex for index $index after preload");
      return getVideoByIndex(index, retry: false, useYoutubeVideos: useYoutubeVideos);
    }
    return null;
  }

  Future<void> _loadInitialVideos() {
    _currentInitVideoLoadingTask ??= _loadInitialVideosInternal();
    return _currentInitVideoLoadingTask!;
  }

  Future<void>? _currentInitVideoLoadingTask;

  Future<void> _loadInitialVideosInternal() async {
    if (_currentInitVideoLoadingTask != null) return _currentInitVideoLoadingTask;
    try {
      // For new users, use cold start videos
      final videos = await _recommender.getColdStartVideos(limit: _preloadBatchSize);

      _videoCache.addAll(videos);
    } catch (e) {
      print('Error loading initial videos: $e');
    }
  }

  Future<void>? _currentPreloadTask;

  @override
  Future<void> preloadVideos(int count, {bool useYoutubeVideos = false}) {
    _currentPreloadTask ??= _preloadMoreVideosInternal(count, useYoutubeVideos: useYoutubeVideos).then((val) => _currentPreloadTask = null);
    return _currentPreloadTask!;
  }

  Future<void> _preloadMoreVideosInternal(int count, {bool useYoutubeVideos = false}) async {
    try {
      final newVideos = await _recommender.getRecommendedVideos(limit: count, useYoutubeVideos: useYoutubeVideos);

      _videoCache.addAll(newVideos);
    } catch (e) {
      print('Error preloading videos: $e');
    }
  }

  /// Refresh recommendations (call this when user preferences might have changed)
  Future<void> refreshRecommendations() async {
    clearCache();
    await _loadInitialVideos();
  }

  /// Clear cache
  void clearCache() {
    if (userLoggedIn && _videoCache.isNotEmpty) {
      releaseVideosWillPlaySoon(
        userId: currentAuthUserId(),
        videoIds: _videoCache.map((video) => video.id),
      );
    }
    _videoCache.clear();
    _currentIndex = 0;
  }

  void appendToCache(List<Video> videos) {
    _videoCache.addAll(videos);
  }

  int get currentCacheLength => _videoCache.length;
}
