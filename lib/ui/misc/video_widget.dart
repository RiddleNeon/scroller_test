import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:wurp/logic/video/video_provider.dart';

import '../../logic/batches/batch_service.dart';
import '../../logic/video/video.dart';
import '../overlays.dart';

class VideoItem extends StatefulWidget {
  final int index;
  final ValueNotifier<int> focusedIndex;
  final VideoPlayerController controller;
  final Video video;
  final String userId;
  final TickerProvider provider;
  final RecommendationVideoProvider videoProvider;

  const VideoItem({
    super.key,
    required this.index,
    required this.focusedIndex,
    required this.controller,
    required this.video,
    required this.userId,
    required this.provider,
    required this.videoProvider,
  });

  @override
  State<VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<VideoItem> {
  DateTime? _startWatchTime;
  Timer? _trackingTimer;
  double _totalWatchTime = 0.0;
  bool _hasTrackedView = false;
  bool _isLiked = false;
  bool _isDisliked = false;
  bool _hasShared = false;
  bool _hasCommented = false;
  bool _hasSaved = false;
  late VideoPlayerValue _lastValue;

  @override
  void initState() {
    super.initState();
    _lastValue = widget.controller.value;
    widget.controller.addListener(_onVideoChanged);
    widget.focusedIndex.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onVideoChanged);
    widget.focusedIndex.removeListener(_onFocusChanged);
    _trackingTimer?.cancel();
    _saveInteraction();
    super.dispose();
  }

  void _onFocusChanged() {
    final bool isActive = widget.focusedIndex.value == widget.index;

    if (isActive) {
      _startTracking();
    } else {
      _stopTracking();
    }
  }

  void _startTracking() {
    _startWatchTime = DateTime.now();

    // Track view after 3 seconds
    if (!_hasTrackedView) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && widget.focusedIndex.value == widget.index) {
          _trackView();
          _hasTrackedView = true;
        }
      });
    }

    // Update watch time every 5 seconds
    _trackingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _updateWatchTime();
      }
    });
  }

  void _stopTracking() {
    _trackingTimer?.cancel();
    _saveInteraction();
    _startWatchTime = null;
  }

  void _updateWatchTime() {
    if (_startWatchTime != null) {
      final elapsed = DateTime.now().difference(_startWatchTime!).inSeconds.toDouble();
      _totalWatchTime += elapsed;
      _startWatchTime = DateTime.now();
    }
  }

  /// Track view count on video document only (lightweight)
  void _trackView() {
    final firestore = FirebaseFirestore.instance;
    final batchQueue = FirestoreBatchQueue.instance;

    // Only increment view count on video
    final videoRef = firestore.collection('videos').doc(widget.video.id);
    batchQueue.update(videoRef, {'views': FieldValue.increment(1)});
  }

  bool currentlySaving = false;

  /// Save complete interaction when user leaves video
  /// This creates ONE interaction document with all data
  void _saveInteraction() async {
    if (currentlySaving) return;
    if (_startWatchTime != null) {
      final elapsed = DateTime.now().difference(_startWatchTime!).inSeconds.toDouble();
      _totalWatchTime += elapsed;
    }
    currentlySaving = true;

    // Only save if user actually watched something
    if (_totalWatchTime < .4 && !_isLiked && !_isDisliked && !_hasShared && !_hasSaved) {
      return;
    }

    final videoDuration = widget.controller.value.duration.inSeconds.toDouble();

    try {
      // Use VideoRecommender to track interaction
      // This handles BOTH recent_interactions AND preference updates
      widget.videoProvider.trackVideoInteraction(
        video: widget.video,
        watchTime: _totalWatchTime,
        videoDuration: videoDuration > 0 ? videoDuration : 1.0,
        liked: _isLiked,
        shared: _hasShared,
        commented: _hasCommented,
        saved: _hasSaved,
      );

      print(
        "Saved interaction for video ${widget.video.id}: "
            "watchTime=${_totalWatchTime.toStringAsFixed(1)}s, "
            "liked=$_isLiked, shared=$_hasShared",
      );

      // Reset for next viewing session
      _totalWatchTime = 0.0;
    } catch (e) {
      print("Error saving interaction: $e");
    }
    currentlySaving = false;
  }

  /// Update interaction state when user likes/dislikes
  void onLikeChanged(bool isLiked) {
    setState(() {
      _isLiked = isLiked;
      if (isLiked) _isDisliked = false; // Can't like and dislike
    });
    // Interaction will be saved when video stops playing
  }

  void onDislikeChanged(bool isDisliked) {
    setState(() {
      _isDisliked = isDisliked;
      if (isDisliked) _isLiked = false; // Can't like and dislike
    });
    // Interaction will be saved when video stops playing
  }

  void onShareChanged(bool hasShared) {
    setState(() {
      _hasShared = hasShared;
    });
  }

  void onSaveChanged(bool hasSaved) {
    setState(() {
      _hasSaved = hasSaved;
    });
  }

  void onCommentChanged(bool hasCommented) {
    setState(() {
      _hasCommented = hasCommented;
    });
  }

  void _onVideoChanged() {
    final current = widget.controller.value;

    if (_lastValue.isInitialized != current.isInitialized || _lastValue.size != current.size || _lastValue.hasError != current.hasError) {
      setState(() {
        _lastValue = current;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print("starting video widget build");

    final bool isActive = widget.focusedIndex.value == widget.index;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (isActive && !widget.controller.value.isPlaying && widget.controller.value.isInitialized) {
          widget.controller.play();
        } else if (!isActive && widget.controller.value.isPlaying) {
          widget.controller.pause();
        }
      }
    });

    return RepaintBoundary(
      child: Center(
        child: _lastValue.size.width == 0 || _lastValue.size.height == 0
            ? const SizedBox()
            : RepaintBoundary(
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final videoWidth = _lastValue.size.width;
                final videoHeight = _lastValue.size.height;
                final videoPixels = videoWidth * videoHeight;

                const targetPixels = 800 * 400;

                double scaleFactor = 1.0;
                if (videoPixels > targetPixels) {
                  scaleFactor = (targetPixels / videoPixels).clamp(0.3, 1.0);
                  print('📐 Scaling video from ${videoWidth.toInt()}x${videoHeight.toInt()} by ${(scaleFactor * 100).toInt()}%');
                }

                final renderWidth = constraints.maxWidth * scaleFactor*0.5;
                final renderHeight = constraints.maxHeight * scaleFactor*0.5;

                return Stack(
                  children: [
                    RepaintBoundary(
                      child: Center(
                        child: SizedBox(
                          width: renderWidth,
                          height: renderHeight,
                          child: OverflowBox(
                            minWidth: constraints.maxWidth,
                            maxWidth: constraints.maxWidth,
                            minHeight: constraints.maxHeight,
                            maxHeight: constraints.maxHeight,
                            child: Transform.scale(
                              scale: 1 / scaleFactor * 0.5,
                              child: VideoPlayer(
                                widget.controller,
                                key: ValueKey(widget.video.id),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    PageOverlay(
                      provider: widget.provider,
                      index: widget.index,
                      video: widget.video,
                      onLikeChanged: onLikeChanged,
                      onDislikeChanged: onDislikeChanged,
                      onShareChanged: onShareChanged,
                      onSaveChanged: onSaveChanged,
                      onCommentChanged: onCommentChanged,
                      initiallyLiked: false,
                      initiallyDisliked: false,
                      child: Container(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

VideoProvider videoProvider = BaseAlgorithmVideoProvider();