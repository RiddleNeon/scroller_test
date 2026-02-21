import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:wurp/logic/video/video_provider.dart';

import '../../logic/batches/batch_service.dart';
import '../../logic/video/video.dart';
import '../overlays.dart';

class VideoItem extends StatefulWidget {
  final VideoPlayerController controller;
  final Video video;
  final String userId;
  final TickerProvider provider;
  final RecommendationVideoProvider videoProvider;
  final int index;

  const VideoItem({
    super.key,
    required this.controller,
    required this.video,
    required this.userId,
    required this.provider,
    required this.videoProvider,
    required this.index,
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

  bool _wasPlaying = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
    if (widget.controller.value.isPlaying) {
      _wasPlaying = true;
      _startTracking();
    }
  }

  @override
  void didUpdateWidget(VideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerUpdate);
      widget.controller.addListener(_onControllerUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    _trackingTimer?.cancel();
    _saveInteraction();
    super.dispose();
  }

  void _onControllerUpdate() {
    final bool isPlaying = widget.controller.value.isPlaying;
    if (isPlaying && !_wasPlaying) {
      _wasPlaying = true;
      _startTracking();
    } else if (!isPlaying && _wasPlaying) {
      _wasPlaying = false;
      _stopTracking();
    }
  }

  void _startTracking() {
    _startWatchTime = DateTime.now();

    // Track view after 3 seconds
    if (!_hasTrackedView) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (widget.controller.value.isPlaying) {
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
    batchQueue.update(videoRef, {'viewsCount': FieldValue.increment(1)});
    print("view tracked for url ${widget.video.videoUrl}: ${widget.video}");
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
      await widget.videoProvider.trackVideoInteraction(
        video: widget.video,
        watchTime: _totalWatchTime,
        videoDuration: videoDuration > 0 ? videoDuration : 1.0,
        liked: _isLiked,
        shared: _hasShared,
        commented: _hasCommented,
        saved: _hasSaved,
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

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Center(
        child: RepaintBoundary(
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    RepaintBoundary(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: widget.controller.value.aspectRatio,
                          child: VideoPlayer(
                            widget.controller,
                            key: ValueKey(widget.video.id),
                          ),
                        ),
                      ),
                    ),
                    PageOverlay(
                      provider: widget.provider,
                      video: widget.video,
                      onLikeChanged: onLikeChanged,
                      onDislikeChanged: onDislikeChanged,
                      onShareChanged: onShareChanged,
                      onSaveChanged: onSaveChanged,
                      onCommentChanged: onCommentChanged,
                      initiallyLiked: false,
                      initiallyDisliked: false,
                      index: widget.index,
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