import 'package:flutter/cupertino.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/main.dart';

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
  late PageOverlayController controller;

  @override
  void initState() {
    super.initState();

    final oldController = pageOverlays[widget.index - 10];
    if (oldController != null) {
      oldController.dispose();
      pageOverlays.remove(widget.index - 10);
    }

    controller = pageOverlays[widget.index] ??
        PageOverlayController(
          widget.index,
          provider: widget.provider,
          videoId: widget.video.id,
          initiallyLiked: widget.initiallyLiked,
          initiallyDisliked: widget.initiallyDisliked,
        );
    controller.addListener(_onControllerUpdate);
  }

  late bool lastLiked = widget.initiallyLiked;
  late bool lastDisliked = widget.initiallyDisliked;

  void _onControllerUpdate() {
    if (!mounted) return;

    if (lastLiked != controller.liked) {
      lastLiked = controller.liked;
      widget.onLikeChanged(controller.liked);
    }
    if (lastDisliked != controller.disliked) {
      lastDisliked = controller.disliked;
      widget.onDislikeChanged(controller.disliked);
    }

    setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

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
              controller.likeButton,
              controller.dislikeButton,
              const Icon(CupertinoIcons.ellipses_bubble),
              const Icon(CupertinoIcons.share),
            ],
          ),
        ),
      ],
    );
  }
}

Map<int, PageOverlayController> pageOverlays = {};

class PageOverlayController extends ChangeNotifier {
  final TickerProvider provider;
  final int index;
  final String videoId;

  bool liked;
  bool disliked;

  late LikeButton likeButton;
  late DislikeButton dislikeButton;

  PageOverlayController(
      this.index, {
        required this.provider,
        required this.videoId,
        bool initiallyLiked = false,
        bool initiallyDisliked = false,
      })  : liked = initiallyLiked,
        disliked = initiallyDisliked {
    pageOverlays[index] = this;
    _buildButtons();
  }

  void _onLikeChanged(bool newLiked) {
    final wasDisliked = disliked;
    liked = newLiked;

    if (wasDisliked && newLiked) {
      disliked = false;
      _rebuildDislikeButton(playAnimation: false);
    }

    notifyListeners();
  }

  void _onDislikeChanged(bool newDisliked) {
    final wasLiked = liked;
    disliked = newDisliked;

    if (wasLiked && newDisliked) {
      liked = false;
      _rebuildLikeButton(playAnimation: false);
    }

    notifyListeners();
  }

  void _buildButtons() {
    likeButton = LikeButton(
      key: ValueKey('like_$index'),
      provider: provider,
      videoId: videoId,
      userId: auth!.currentUser!.uid,
      initiallyLiked: liked,
      initiallyPlayingAnimation: false,
      onLikeChanged: _onLikeChanged,
    );

    dislikeButton = DislikeButton(
      key: ValueKey('dislike_$index'),
      videoId: videoId,
      userId: auth!.currentUser!.uid,
      initiallyDisliked: disliked,
      initiallyPlayingAnimation: false,
      onDislikeChanged: _onDislikeChanged,
    );
  }

  void _rebuildLikeButton({bool playAnimation = false}) {
    likeButton = LikeButton(
      key: ValueKey('like_${index}_${liked ? 'on' : 'off'}'),
      provider: provider,
      videoId: videoId,
      userId: auth!.currentUser!.uid,
      initiallyLiked: liked,
      initiallyPlayingAnimation: playAnimation,
      onLikeChanged: _onLikeChanged,
    );
  }

  void _rebuildDislikeButton({bool playAnimation = false}) {
    dislikeButton = DislikeButton(
      key: ValueKey('dislike_${index}_${disliked ? 'on' : 'off'}'),
      videoId: videoId,
      userId: auth!.currentUser!.uid,
      initiallyDisliked: disliked,
      initiallyPlayingAnimation: playAnimation,
      onDislikeChanged: _onDislikeChanged,
    );
  }
}