import 'package:wurp/logic/video/video.dart';

import '../feed_recommendation/video_recommender.dart';

abstract class VideoProvider {
  Future<Video?> getVideoByIndex(int index);

  Future<void> preloadVideos(int count);
}

class RecommendationVideoProvider implements VideoProvider {
  final VideoRecommender _recommender;
  final List<Video> _videoCache = [];

  // ignore: unused_field
  int _currentIndex = 0;

  static const int _preloadThreshold = 5; // Preload when this many videos left
  static const int _preloadBatchSize = 20;

  RecommendationVideoProvider()
      : _recommender = VideoRecommender();

  @override
  Future<Video> getVideoByIndex(int index, [bool retry = true]) async {
    // Preload more videos if we're running low
    if (index >= _videoCache.length - _preloadThreshold) {
      Future loadingFuture = preloadVideos(_preloadBatchSize);
      if(index >= _videoCache.length) {
        // If requested index is beyond current cache, wait for preload to finish
        await loadingFuture;
      }
    }
    

    // Return video if available
    if (index < _videoCache.length) {
      _currentIndex = index;
      return _videoCache[index];
    } else if(retry) {
      return getVideoByIndex(index, false);
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
    _videoCache.clear();
    _currentIndex = 0;
  }
  
  void appendToCache(List<Video> videos) {
    _videoCache.addAll(videos);
  }
  
  int get currentCacheLength => _videoCache.length;
}