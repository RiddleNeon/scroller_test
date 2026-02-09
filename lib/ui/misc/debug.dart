import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/foundation.dart';

class DebugBetterPlayerController extends BetterPlayerController {
  final String debugLabel;
  bool _isDisposed = false;

  DebugBetterPlayerController(
      super.betterPlayerConfiguration, {
        required this.debugLabel,
      });

  @override
  Future<void> setupDataSource(BetterPlayerDataSource dataSource) {
    debugPrint('[$debugLabel] setupDataSource called - isDisposed: $_isDisposed');
    debugPrint('[$debugLabel] StackTrace:\n${StackTrace.current}');
    return super.setupDataSource(dataSource);
  }

  @override
  Future<void>? dispose({bool forceDispose = false}) async {
    debugPrint('[$debugLabel] ⚠️ DISPOSE CALLED - isDisposed: $_isDisposed, forceDispose: $forceDispose');
    debugPrint('[$debugLabel] Dispose StackTrace:\n${StackTrace.current}');
    _isDisposed = true;
    return super.dispose(forceDispose: forceDispose);
  }

  @override
  Future<void> play() {
    debugPrint('[$debugLabel] play() called - isDisposed: $_isDisposed, forceDispose: $_isDisposed');
    if (_isDisposed) {
      debugPrint('[$debugLabel] ❌ ERROR: Trying to play disposed controller!');
    }
    return super.play();
  }

  @override
  Future<void> pause() {
    debugPrint('[$debugLabel] pause() called - isDisposed: $_isDisposed');
    if (_isDisposed) {
      debugPrint('[$debugLabel] ❌ ERROR: Trying to pause disposed controller!');
    }
    return super.pause();
  }

  @override
  Future<void> seekTo(Duration moment) {
    debugPrint('[$debugLabel] seekTo($moment) called - isDisposed: $_isDisposed');
    if (_isDisposed) {
      debugPrint('[$debugLabel] ❌ ERROR: Trying to seek disposed controller!');
    }
    return super.seekTo(moment);
  }
}