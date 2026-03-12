import 'package:flutter/cupertino.dart';
import 'package:wurp/logic/local_storage/local_seen_service.dart';
import 'package:wurp/logic/repositories/video_repository.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/ui/screens/comment_overlay.dart';
import 'package:wurp/ui/widgets/overlays/video_info_overlay.dart';

import 'comment_button.dart';
import 'dislike_button.dart';
import 'like_button.dart';

class PageOverlay extends StatefulWidget {
  final TickerProvider provider;
  final Video video;
  final int index;

  final Widget child;
  final bool initiallyLiked;
  final bool initiallyDisliked;

  final void Function(bool isDisliked)? onDislikeChanged;
  final void Function(bool isLiked)? onLikeChanged;
  final void Function(bool hasShared)? onShareChanged;
  final void Function(bool hasSaved)? onSaveChanged;
  final void Function(bool hasCommented)? onCommentChanged;

  const PageOverlay({
    super.key,
    required this.provider,
    required this.video,
    required this.index,
    this.onLikeChanged,
    this.onDislikeChanged,
    this.onShareChanged,
    this.onSaveChanged,
    this.onCommentChanged,
    required this.child,
    required this.initiallyLiked,
    required this.initiallyDisliked,
  });

  @override
  State<PageOverlay> createState() => _PageOverlayState();
}

class _PageOverlayState extends State<PageOverlay> {
  late bool lastLiked = widget.initiallyLiked;
  late bool lastDisliked = widget.initiallyDisliked;
  late bool liked = widget.initiallyLiked;
  late bool disliked = widget.initiallyDisliked;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        Align(
          alignment: Alignment.centerRight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 8,
            children: [
              LikeButton(provider: widget.provider, initiallyLiked: liked, onLikeChanged: _onLikeChanged),
              DislikeButton(initiallyDisliked: disliked, onDislikeChanged: _onDislikeChanged),
              CommentButton(onComment: _onCommentButtonPressed),
              const Icon(CupertinoIcons.share),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, 0),
          child: Transform.scale(
            scaleX: 1.005,
            child: Align(
              alignment: AlignmentGeometry.bottomCenter,
              child: VideoInfoOverlay(video: widget.video),
            ),
          ),
        ),
      ],
    );
  }

  void _onLikeChanged(bool newLiked) async {
    liked = newLiked;
    if (disliked && newLiked) {
      print("switch to undisliked");
      setState(() {
        disliked = false;
      });
    }
    bool toggleResult = await videoRepo.toggleLike(widget.video.id);
    if(toggleResult != newLiked) {
      print("Error toggling like: expected $newLiked but got $toggleResult");
      setState(() {
        liked = toggleResult;
      });
    } else {
      print("Successfully toggled like of ${widget.video.id} to $toggleResult");
    }
    widget.onLikeChanged?.call(toggleResult);

    if (toggleResult) {
      localSeenService.saveLike(widget.video.id);
    } else {
      localSeenService.removeLike(widget.video.id);
    }
  }

  void _onDislikeChanged(bool newDisliked) async {
    disliked = newDisliked;
    if (liked && newDisliked) {
      print("switch to unliked");
      setState(() {
        liked = false;
      });
    }
    bool toggleResult = await videoRepo.toggleDislike(widget.video.id);
    
    if(toggleResult != newDisliked) {
      print("Error toggling dislike: expected $newDisliked but got $toggleResult");
      setState(() {
        disliked = toggleResult;
      });
    } else {
      print("Successfully toggled dislike to $toggleResult");
    }
    widget.onDislikeChanged?.call(toggleResult);

    if (toggleResult) {
      localSeenService.saveDislike(widget.video.id);
    } else {
      localSeenService.removeDislike(widget.video.id);
    }
  }

  void _onCommentButtonPressed() {
    openCommentsForVideo(widget.video, context);
  }
}
