import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/cupertino.dart';

import 'debug.dart';

class VideoManager extends ChangeNotifier {
  static final VideoManager _instance = VideoManager._internal();
  factory VideoManager() => _instance;
  VideoManager._internal();

  BetterPlayerController? _currentPlayer;
  BetterPlayerController? _nextPlayer;

  int _currentIndex = 0;
  int _nextIndex = 1;

  bool _isInitialized = false;

  final Map<int, String> _videoUrls = {};
  final Map<int, ValueNotifier<bool>> _playingNotifiers = {};

  void _ensureInitialized() {
    if (_isInitialized) return;

    _currentPlayer = _createPlayer(0);
    _nextPlayer = _createPlayer(1);
    _isInitialized = true;
  }

  BetterPlayerController _createPlayer(int index) {
    final controller = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: false,
        looping: false,
        aspectRatio: 9 / 16,
        autoDispose: false,
        fit: BoxFit.cover,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false,
        ),
      ),
    );

    controller.addEventsListener((event) {
      if (event.betterPlayerEventType == BetterPlayerEventType.play) {
        _updatePlayingState();
      } else if (event.betterPlayerEventType == BetterPlayerEventType.pause) {
        _updatePlayingState();
      }
    });

    return controller;
  }

  void _updatePlayingState() {
    _playingNotifiers[_currentIndex]?.value = _currentPlayer?.isPlaying() ?? false;
    _playingNotifiers[_nextIndex]?.value = _nextPlayer?.isPlaying() ?? false;
  }

  ValueNotifier<bool> getPlayingNotifier(int index) {
    return _playingNotifiers.putIfAbsent(index, () => ValueNotifier<bool>(true));
  }

  void registerVideo(int index, String videoUrl) {
    _videoUrls[index] = videoUrl;
  }

  BetterPlayerController? getPlayerForIndex(int index) {
    _ensureInitialized();

    if (index == _currentIndex) {
      return _currentPlayer;
    } else if (index == _nextIndex) {
      return _nextPlayer;
    }

    return null;
  }

  void initializeFirst(int index, String videoUrl) {
    _ensureInitialized();

    _currentIndex = index;
    _videoUrls[index] = videoUrl;

    _currentPlayer!.setupDataSource(
      BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        videoUrl,
      ),
    );

    notifyListeners();
  }

  void preloadNext(int index, String videoUrl) {
    _ensureInitialized();

    if (_nextIndex == index && _videoUrls[index] == videoUrl) {
      return; 
    }

    _nextIndex = index;
    _videoUrls[index] = videoUrl;
    
    BetterPlayerDataSource source =       BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      videoUrl,
    );

    _nextPlayer!.setupDataSource(
      source
    );
    _nextPlayer?.preCache(source);

    notifyListeners();
  }

  void switchToIndex(int newIndex, String videoUrl, int followingIndex, String followingUrl) async {
    _ensureInitialized();

    if (newIndex == _currentIndex) return;

    final isForward = newIndex > _currentIndex;

    if (isForward && newIndex == _nextIndex) {
      final temp = _currentPlayer;
      _currentPlayer = _nextPlayer;
      _nextPlayer = temp;

      final oldCurrentIndex = _currentIndex;
      _currentIndex = newIndex;
      _nextIndex = followingIndex;

      _nextPlayer!.pause();

      _playingNotifiers[oldCurrentIndex]?.value = false;
      _playingNotifiers[_currentIndex]?.value = _currentPlayer?.isPlaying() ?? false;

      _videoUrls[followingIndex] = followingUrl;
      await _nextPlayer!.setupDataSource(
        BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          followingUrl,
        ),
      );
      notifyListeners();
    } else {
      _currentPlayer!.pause();
      _nextPlayer!.pause();

      final oldCurrentIndex = _currentIndex;
      _currentIndex = newIndex;
      _nextIndex = followingIndex;

      _playingNotifiers[oldCurrentIndex]?.value = false;

      _videoUrls[newIndex] = videoUrl;
      _currentPlayer!.setupDataSource(
        BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          videoUrl,
        ),
      );

      _videoUrls[followingIndex] = followingUrl;
      _nextPlayer!.setupDataSource(
        BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          followingUrl,
        ),
      );

      notifyListeners();
    }
  }

  int get currentIndex => _currentIndex;
  int get nextIndex => _nextIndex;

  void pauseAll() {
    if (_currentPlayer != null) _currentPlayer!.pause();
    if (_nextPlayer != null) _nextPlayer!.pause();
    _updatePlayingState();
  }

  @override
  void dispose() {
    _currentPlayer?.dispose();
    _nextPlayer?.dispose();
    _currentPlayer = null;
    _nextPlayer = null;
    _videoUrls.clear();
    for (var notifier in _playingNotifiers.values) {
      notifier.dispose();
    }
    _playingNotifiers.clear();
    _isInitialized = false;
    super.dispose();
  }
}