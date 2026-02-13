import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../logic/batches/batch_service.dart';

class DislikeButton extends StatefulWidget {
  final bool initiallyDisliked;
  final void Function(bool)? onDislikeChanged;
  final bool initiallyPlayingAnimation;
  final String videoId;
  final String userId;

  const DislikeButton({
    super.key,
    this.initiallyDisliked = false,
    this.onDislikeChanged,
    this.initiallyPlayingAnimation = false,
    required this.videoId,
    required this.userId,
  });

  @override
  State<DislikeButton> createState() => _DislikeButtonState();
}

class _DislikeButtonState extends State<DislikeButton>
    with SingleTickerProviderStateMixin {
  late bool disliked = widget.initiallyDisliked;
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInBack)),
        weight: 60,
      ),
    ]).animate(_ctrl);

    _rotate = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -0.15)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.15, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_ctrl);

    if (widget.initiallyPlayingAnimation) {
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() {
    setState(() {
      disliked = !disliked;
    });

    _ctrl.forward(from: 0.0);

    // Notify parent widget (VideoItem) about dislike state change
    widget.onDislikeChanged?.call(disliked);

    // Update Firestore immediately for UI consistency
    // But DON'T create interaction document here - that's handled by VideoItem
    _updateDislikeInFirestore(disliked);
  }

  /// Only update dislike count and user's disliked_videos collection
  /// The interaction tracking is handled centrally in VideoItem
  void _updateDislikeInFirestore(bool isDisliked) {
    final firestore = FirebaseFirestore.instance;
    final batchQueue = FirestoreBatchQueue.instance;

    // Update video dislike count
    final videoRef = firestore.collection('videos').doc(widget.videoId);
    batchQueue.update(videoRef, {
      'dislikes': FieldValue.increment(isDisliked ? 1 : -1),
    });

    // Update user's disliked videos collection
    final userDislikeRef = firestore
        .collection('users')
        .doc(widget.userId)
        .collection('disliked_videos')
        .doc(widget.videoId);

    if (isDisliked) {
      batchQueue.set(userDislikeRef, {
        'videoId': widget.videoId,
        'dislikedAt': FieldValue.serverTimestamp(),
      });
    } else {
      batchQueue.delete(userDislikeRef);
    }

    // NO interaction document here - VideoItem handles this
    // This prevents duplicate interaction entries

    // NOTE: Dislike is handled as a negative signal in the recommender
    // by NOT including this video's tags/author in preference calculation
  }

  @override
  Widget build(BuildContext context) {
    final Color iconColor =
    disliked ? Colors.redAccent : Colors.grey.shade700;
    final IconData iconData =
    disliked ? Icons.thumb_down : Icons.thumb_down_outlined;

    return Padding(
      padding: const EdgeInsets.all(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _onTap,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotate.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Icon(iconData, size: 32, color: iconColor),
              ),
            );
          },
        ),
      ),
    );
  }
}