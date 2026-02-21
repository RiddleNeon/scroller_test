import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../logic/batches/batch_service.dart';
import '../../main.dart';

class LikeButton extends StatefulWidget {
  final TickerProvider provider;
  final bool initiallyLiked;
  final bool initiallyPlayingAnimation;
  final void Function(bool)? onLikeChanged;
  final String videoId;
  final String userId;

  const LikeButton({
    super.key,
    required this.provider,
    this.initiallyLiked = false,
    this.onLikeChanged,
    this.initiallyPlayingAnimation = false,
    required this.videoId,
    required this.userId,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  late bool liked = widget.initiallyLiked;
  late bool isInitiallyAnimating = widget.initiallyPlayingAnimation;
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: widget.provider, upperBound: 0.5);
    if (widget.initiallyLiked) {
      controller.value = controller.upperBound;
    }
    if (isInitiallyAnimating) {
      controller.value = widget.initiallyLiked ? 0.1 : 0.4;
      controller.animateTo(
        widget.initiallyLiked ? 0.5 : 0,
        duration: Duration(milliseconds: 600),
      );
    }
  }

  @override
  void didUpdateWidget(LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyLiked != oldWidget.initiallyLiked) {
      if (mounted) {
        liked = widget.initiallyLiked;
        controller.animateTo(
          liked ? controller.upperBound : controller.lowerBound,
          duration: const Duration(milliseconds: 600),
        );
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    LottieBuilder builder = Lottie.asset(
      "assets/like.json",
      controller: controller,
      onLoaded: (composition) {
        controller.duration = composition.duration;
      },
      fit: BoxFit.contain,
      filterQuality: FilterQuality.low,
    );

    return InkWell(
      onTap: () {
        if (!mounted) return;

        double upperBound = liked ? 0 : 0.5;
        controller.animateTo(
          upperBound,
          duration: Duration(milliseconds: (liked ? 400 : 600)),
        );
        

        setState(() {
          liked = !liked;
        });

        widget.onLikeChanged?.call(liked);


        _updateLikeInFirestore(liked);
      },
      child: Transform.scale(
        scale: 2,
        child: SizedBox(width: 32, height: 32, child: builder),
      ),
    );
  }

  /// Only update like count and user's liked_videos collection
  /// The interaction tracking is handled centrally in VideoItem
  void _updateLikeInFirestore(bool isLiked) {
    final batchQueue = FirestoreBatchQueue.instance;

    // Update video like count
    final videoRef = firestore.collection('videos').doc(widget.videoId);
    batchQueue.update(videoRef, {
      'likes': FieldValue.increment(isLiked ? 1 : -1),
    });

    // Update user's liked videos collection
    final userLikeRef = firestore
        .collection('users')
        .doc(widget.userId)
        .collection('liked_videos')
        .doc(widget.videoId);

    if (isLiked) {
      batchQueue.set(userLikeRef, {
        'videoId': widget.videoId,
        'likedAt': FieldValue.serverTimestamp(),
      });
    } else {
      batchQueue.delete(userLikeRef);
    }

    // NO interaction document here - VideoItem handles this
    // This prevents duplicate interaction entries
  }
}