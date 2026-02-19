import 'dart:async';
import 'dart:collection';
import 'package:video_player/video_player.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/logic/video/video_provider.dart';

class VideoControllerPool {
  final RecommendationVideoProvider provider;
  final Map<int, VideoControllerEntry> _cache = {};
  final Queue<int> _initializationQueue = Queue();
  bool _isProcessingQueue = false;

  static const int maxCacheSize = 5;
  static const int preloadDistance = 1;

  VideoControllerPool(this.provider);

  Future<VideoControllerEntry?> get(int index) async {    
    if (_cache.containsKey(index)) {
      final entry = _cache[index]!;
      entry.lastAccessed = DateTime.now();

      if (entry.isInitialized) {
        return entry;
      }

      if (entry.initializationCompleter != null) {
        return await entry.initializationCompleter!.future;
      }
    }

    return await _createController(index);
  }

  Future<VideoControllerEntry?> _createController(int index) async {
    try {
      final video = await provider.getVideoByIndex(index);

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(video.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );
      
      final entry = VideoControllerEntry(
        controller: controller,
        video: video,
        index: index,
      );
      _cache[index] = entry;

      //_addToInitializationQueue(index);

      return await entry.initializationCompleter!.future;
    } catch (e) {
      print('Error creating controller for index $index: $e');
      return null;
    }
  }

  void _addToInitializationQueue(int index) {
    if (!_initializationQueue.contains(index)) {
      _initializationQueue.add(index);
      _processInitializationQueue();
    }
  }

  Future<void> _processInitializationQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    while (_initializationQueue.isNotEmpty) {
      final batch = <int>[];
      for (int i = 0; i < 2 && _initializationQueue.isNotEmpty; i++) {
        batch.add(_initializationQueue.removeFirst());
      }
    }

    _isProcessingQueue = false;
  }

  void playOnly(int index) {
    for (final entry in _cache.entries) {
      if (entry.key == index && entry.value.isInitialized) {
        entry.value.controller.play();
      } else if (entry.value.isInitialized) {
        entry.value.controller.pause();
      }
    }
  }

  void reset(int index) {
    final entry = _cache[index];
    if (entry?.isInitialized == true) {
      entry!.controller.seekTo(Duration.zero);
    }
  }

  void keepOnly(Set<int> indices) {
    final toRemove = <int>[];

    for (final entry in _cache.entries) {
      if (!indices.contains(entry.key)) {
        toRemove.add(entry.key);
      }
    }

    if (_cache.length > maxCacheSize) {
      final sorted = _cache.entries.toList()
        ..sort((a, b) => a.value.lastAccessed.compareTo(b.value.lastAccessed));

      for (int i = 0; i < sorted.length - maxCacheSize; i++) {
        if (!indices.contains(sorted[i].key)) {
          toRemove.add(sorted[i].key);
        }
      }
    }

    for (final index in toRemove) {
      _disposeController(index);
    }
  }

  void preloadAround(int currentIndex) {
    for (int i = 1; i <= preloadDistance; i++) {
      get(currentIndex + i); // Fire and forget
    }
  }

  void _disposeController(int index) {
    final entry = _cache.remove(index);
    if (entry != null) {
      entry.controller.dispose();
      print('🗑️ Disposed controller $index');
    }
  }

  void dispose() {
    for (final entry in _cache.values) {
      entry.controller.dispose();
    }
    _cache.clear();
    _initializationQueue.clear();
  }
}

class VideoControllerEntry {
  final VideoPlayerController controller;
  final Video video;
  final int index;
  bool isInitialized = false;
  DateTime lastAccessed = DateTime.now();
  Completer<VideoControllerEntry>? initializationCompleter = Completer();

  VideoControllerEntry({
    required this.controller,
    required this.video,
    required this.index,
  });
}