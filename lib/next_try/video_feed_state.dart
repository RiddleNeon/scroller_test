import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../logic/video/video.dart';
import '../logic/video/video_provider.dart';

enum _SlotState { idle, loading, loaded, error }

class _VideoSlot {
  _SlotState state;
  VideoWithAuthor? data;
  VideoPlayerController? controller;
  String? errorMessage;

  _VideoSlot({this.state = _SlotState.idle});
}

class VideoFeedState extends ChangeNotifier {
  VideoFeedState({
    required VideoProvider provider,
    required String currentUserId,
  })  : _provider = provider,
        _currentUserId = currentUserId;

  final VideoProvider _provider;
  final String _currentUserId;

  // Hard limit: never more than this many controllers alive at once.
  // Each ExoPlayer instance uses ~40-60 MB on device.
  static const int _maxControllers = 2;

  final Map<int, _VideoSlot> _slots = {};
  int _currentIndex = 0;

  // Guard: don't start a new pre-warm while one is already in flight
  bool _preWarmInProgress = false;

  int get currentIndex => _currentIndex;

  // ─── Public API ───────────────────────────────────────────────────────────

  bool isLoading(int index) =>
      (_slots[index]?.state ?? _SlotState.idle) == _SlotState.loading;

  bool hasError(int index) =>
      (_slots[index]?.state ?? _SlotState.idle) == _SlotState.error;

  String? errorMessage(int index) => _slots[index]?.errorMessage;

  VideoWithAuthor? videoWithAuthorAt(int index) => _slots[index]?.data;

  VideoPlayerController? controllerAt(int index) =>
      _slots[index]?.controller;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    await _provider.preloadVideos(3);
    // Load only the first video on init – pre-warm next AFTER it's ready
    await _loadSlot(0);
    _maybePreWarmNext(0);
  }

  Future<void> onPageChanged(int index) async {
    _currentIndex = index;

    // Pause everything except current
    for (final entry in _slots.entries) {
      if (entry.key == index) {
        _playWhenReady(entry.value.controller);
      } else {
        entry.value.controller?.pause();
      }
    }

    // Dispose slots outside the window BEFORE loading new ones
    _evictFarSlots(index);

    // Load current if needed, then pre-warm next
    await _loadSlot(index);
    _maybePreWarmNext(index);

    notifyListeners();
  }

  void toggleLike(int index) {
    final old = _slots[index]?.data;
    if (old == null) return;
    _slots[index]!.data = VideoWithAuthor(
      video: old.video,
      author: old.author,
      isLiked: !old.isLiked,
      isAuthorFollowed: old.isAuthorFollowed,
    );
    notifyListeners();
  }

  void toggleFollow(int index) {
    final old = _slots[index]?.data;
    if (old == null) return;
    _slots[index]!.data = VideoWithAuthor(
      video: old.video,
      author: old.author,
      isLiked: old.isLiked,
      isAuthorFollowed: !old.isAuthorFollowed,
    );
    notifyListeners();
  }

  void trackInteraction({
    required int index,
    required double watchTime,
    required double videoDuration,
    bool liked = false,
    bool shared = false,
    bool commented = false,
    bool saved = false,
  }) {
    final video = _slots[index]?.data?.video;
    if (video == null) return;
    _provider.trackVideoInteraction(
      video: video,
      watchTime: watchTime,
      videoDuration: videoDuration,
      liked: liked,
      shared: shared,
      commented: commented,
      saved: saved,
    );
  }

  // ─── Private ──────────────────────────────────────────────────────────────

  /// Pre-warm the next slot only if we're under the controller limit
  /// and no other pre-warm is already running.
  void _maybePreWarmNext(int currentIndex) {
    if (_preWarmInProgress) return;
    final nextIndex = currentIndex + 1;
    if (_slots[nextIndex]?.state == _SlotState.loaded) return;
    if (_controllerCount() >= _maxControllers) return;

    _preWarmInProgress = true;
    _loadSlot(nextIndex).whenComplete(() => _preWarmInProgress = false);
  }

  int _controllerCount() =>
      _slots.values.where((s) => s.controller != null).length;

  /// Remove slots that are more than 1 page away from [currentIndex].
  void _evictFarSlots(int currentIndex) {
    final toRemove = _slots.keys
        .where((i) => (i - currentIndex).abs() > 1)
        .toList();
    for (final i in toRemove) {
      _disposeSlot(i);
    }
  }

  void _disposeSlot(int index) {
    final slot = _slots[index];
    if (slot == null) return;
    slot.controller?.dispose();
    _slots.remove(index);
  }

  Future<void> _loadSlot(int index) async {
    final existing = _slots[index];
    if (existing != null &&
        existing.state != _SlotState.idle &&
        existing.state != _SlotState.error) {
      return;
    }

    // Hard limit check before creating a new controller
    if (_controllerCount() >= _maxControllers) {
      debugPrint(
          'VideoFeedState: skipping pre-warm for $index – at controller limit');
      return;
    }

    _slots[index] = _VideoSlot(state: _SlotState.loading);
    notifyListeners();

    try {
      final video = await _provider.getVideoByIndex(index);
      if (video == null) {
        _slots[index] = _VideoSlot(state: _SlotState.error)
          ..errorMessage = 'No more videos';
        notifyListeners();
        return;
      }

      final withAuthor = await VideoWithAuthor.fromVideo(video, _currentUserId);
      if (withAuthor == null) {
        _slots[index] = _VideoSlot(state: _SlotState.error)
          ..errorMessage = 'Could not load author';
        notifyListeners();
        return;
      }

      // Re-check limit after the async gap – another slot may have been
      // created in the meantime
      if (_controllerCount() >= _maxControllers && index != _currentIndex) {
        // We fetched the data but won't create a controller yet.
        // Store data-only so the controller can be created when needed.
        _slots[index] = _VideoSlot(state: _SlotState.loaded)
          ..data = withAuthor;
        notifyListeners();
        return;
      }

      final controller =
      _buildController(video, isActive: index == _currentIndex);

      _slots[index] = _VideoSlot(state: _SlotState.loaded)
        ..data = withAuthor
        ..controller = controller;

      notifyListeners();
    } catch (e, st) {
      debugPrint('VideoFeedState._loadSlot($index) error: $e\n$st');
      _slots[index] = _VideoSlot(state: _SlotState.error)
        ..errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Play immediately if already initialized, otherwise wait for the event.
  /// Uses List.of() to avoid concurrent modification of the listener list.
  void _playWhenReady(VideoPlayerController? controller) {
    if (controller == null) return;
    print("initializing controller");
    controller..initialize().then((value) {
      controller.play();
      notifyListeners();
    });
  }

  VideoPlayerController _buildController(Video video,
      {required bool isActive}) {

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(video.videoUrl),
      viewType: VideoViewType.platformView, //todo
    );

    if (isActive) {
      _playWhenReady(controller);
    }

    return controller;
  }

  @override
  void dispose() {
    print("dispose called");
    for (final slot in _slots.values) {
      slot.controller?.dispose();
    }
    _slots.clear();
    super.dispose();
  }
}