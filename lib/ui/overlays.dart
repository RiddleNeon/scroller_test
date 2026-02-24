import 'package:flutter/cupertino.dart';
import 'package:wurp/logic/repositories/video_repository.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/ui/overlay_buttons/comment_button.dart';
import 'package:wurp/ui/screens/comment_overlay.dart';

import '../main.dart';
import 'overlay_buttons/dislike_button.dart';
import 'overlay_buttons/like_button.dart';

class PageOverlay extends StatefulWidget {
  final TickerProvider provider;
  final Video video;
  final int index;

  final Widget child;
  final bool initiallyLiked;
  final bool initiallyDisliked;

  final void Function(bool isDisliked) onDislikeChanged;
  final void Function(bool isLiked) onLikeChanged;
  final void Function(bool hasShared) onShareChanged;
  final void Function(bool hasSaved) onSaveChanged;
  final void Function(bool hasCommented) onCommentChanged;

  const PageOverlay({
    super.key,
    required this.provider,
    required this.video,
    required this.index,
    required this.onLikeChanged,
    required this.onDislikeChanged,
    required this.onShareChanged,
    required this.onSaveChanged,
    required this.onCommentChanged,
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
              LikeButton(provider: widget.provider, videoId: widget.video.id, initiallyLiked: liked, onLikeChanged: _onLikeChanged),
              DislikeButton(videoId: widget.video.id, initiallyDisliked: disliked, onDislikeChanged: _onDislikeChanged),
              CommentButton(videoId: widget.video.id, onComment: _onCommentButtonPressed),
              const Icon(CupertinoIcons.share),
            ],
          ),
        ),
      ],
    );
  }

  void _onLikeChanged(bool newLiked) {
    liked = newLiked;
    if (disliked && newLiked) {
      print("switch to undisliked");
      setState(() {
        disliked = false;
      });
    }
    _updateLikeInFirestore(newLiked);
    widget.onLikeChanged(newLiked);
  }

  void _onDislikeChanged(bool newDisliked) {
    disliked = newDisliked;
    if (liked && newDisliked) {
      print("switch to unliked");
      setState(() {
        liked = false;
      });
    }
    _updateDislikeInFirestore(newDisliked);
    widget.onDislikeChanged(newDisliked);
  }
  
  void _onCommentButtonPressed(){
    openCommentsForVideo(widget.video, context);
  }

  void _updateDislikeInFirestore(bool isDisliked) {
    if(isDisliked) {
      videoRepo.dislikeVideo(auth!.currentUser!.uid, widget.video.id);
    } else {
      videoRepo.undislikeVideo(auth!.currentUser!.uid, widget.video.id);
    }
  }
  void _updateLikeInFirestore(bool isLiked) {
    if(isLiked) {
      videoRepo.likeVideo(auth!.currentUser!.uid, widget.video.id, widget.video.authorId);
    } else {
      videoRepo.unlikeVideo(auth!.currentUser!.uid, widget.video.id, widget.video.authorId);
    }
  }
}
