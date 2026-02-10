/*
import 'package:flutter/cupertino.dart';
import 'package:video_player/video_player.dart';

class VideoManager {
  static final VideoManager _instance = VideoManager._internal();
  factory VideoManager() => _instance;
  VideoManager._internal();

  VideoPlayerController? _currentPlayer;
  VideoPlayerController? _nextPlayer;

  bool _isSwitching = false;

  final Map<int, ValueNotifier<VideoPlayerController?>> _controllerNotifiers = {};
  final Map<int, ValueNotifier<bool>> _playingNotifiers = {};

  ValueNotifier<VideoPlayerController?> getControllerNotifier(int index) {
    return _controllerNotifiers.putIfAbsent(index, () => ValueNotifier<VideoPlayerController?>(null));
  }

  ValueNotifier<bool> getPlayingNotifier(int index) {
    return _playingNotifiers.putIfAbsent(index, () => ValueNotifier<bool>(false));
  }

  void _ensureInitialized() {
    if (_currentPlayer != null) return;
    _currentPlayer = _createPlayer();
    _nextPlayer = _createPlayer();
  }

  VideoPlayerController _createPlayer() {
    return VideoPlayerController.networkUrl(
      Uri.https(),
    )..addEventsListener((event) {
      _updatePlayingStates();
    });
  }

  void _updatePlayingStates() {
    _playingNotifiers.forEach((index, notifier) {
      if (index == _currentIndex) notifier.value = _currentPlayer?.isPlaying() ?? false;
      if (index == _nextIndex) notifier.value = _nextPlayer?.isPlaying() ?? false;
    });
  }

  int _currentIndex = -1;
  int _nextIndex = -1;

  void initializeFirst(int index, String url) {
    _ensureInitialized();
    _currentIndex = index;
    _currentPlayer!.setupDataSource(BetterPlayerDataSource(BetterPlayerDataSourceType.network, url));
    getControllerNotifier(index).value = _currentPlayer;
  }

  void preloadNext(int index, String url) {
    _ensureInitialized();
    _nextIndex = index;
    _nextPlayer!.setupDataSource(BetterPlayerDataSource(BetterPlayerDataSourceType.network, url));
    getControllerNotifier(index).value = _nextPlayer;
  }

  Future<void> switchToIndex(int newIndex, String url, int followingIndex, String followingUrl) async {
    if (_isSwitching || newIndex == _currentIndex) return;
    _isSwitching = true;

    try {
      final oldIndex = _currentIndex;

      final temp = _currentPlayer;
      _currentPlayer = _nextPlayer;
      _nextPlayer = temp;

      _currentIndex = newIndex;
      _nextIndex = followingIndex;

      getControllerNotifier(oldIndex).value = null;
      getControllerNotifier(_currentIndex).value = _currentPlayer;
      getControllerNotifier(_nextIndex).value = _nextPlayer;

      await _nextPlayer!.setupDataSource(BetterPlayerDataSource(BetterPlayerDataSourceType.network, followingUrl));
    } finally {
      _isSwitching = false;
    }
  }

  void dispose() {
    _currentPlayer?.dispose();
    _nextPlayer?.dispose();
    for (var n in _controllerNotifiers.values) { n.value = null; n.dispose(); }
    for (var n in _playingNotifiers.values) { n.dispose(); }
    _controllerNotifiers.clear();
    _playingNotifiers.clear();
  }
}*/
