import 'package:flutter/cupertino.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/main.dart';

import 'overlay_buttons/dislike_button.dart';
import 'overlay_buttons/like_button.dart';

class PageOverlay extends StatefulWidget {
  final TickerProvider provider;
  final int index;
  final Video video;

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
    required this.index,
    required this.video,
    required this.onLikeChanged,
    required this.onDislikeChanged,
    required this.onShareChanged,
    required this.onSaveChanged,
    required this.onCommentChanged,
    required this.child, required this.initiallyLiked, required this.initiallyDisliked,
  });

  @override
  State<PageOverlay> createState() => _PageOverlayState();
}

class _PageOverlayState extends State<PageOverlay> {
  late PageOverlayController controller;

  @override
  void initState() {
    super.initState();
    pageOverlays.remove(widget.index - 10); //clear cache for videos that are far away

    controller = pageOverlays[widget.index] ?? PageOverlayController(widget.index, provider: widget.provider, videoId: widget.video.id);
    controller.addListener(_onControllerUpdate);
  }

  late bool lastLiked = widget.initiallyLiked;
  late bool lastDisliked = widget.initiallyDisliked;

  void _onControllerUpdate() {
    print("like or dislike changed");
    if (mounted && controller.switched) {
      setState(() {});
    }
    if(lastLiked != controller.liked){
      lastLiked = controller.liked;
      widget.onLikeChanged(controller.liked);
    }    
    if(lastDisliked != controller.disliked){
      lastDisliked = controller.disliked;
      widget.onDislikeChanged(controller.disliked);
    }
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
        controller.content,
      ],
    );
  }
}

Map<int, PageOverlayController> pageOverlays = {};

class PageOverlayController extends ChangeNotifier {
  final TickerProvider provider;
  final int index;
  final String videoId;

  PageOverlayController(this.index, {required this.provider, required this.videoId}) {
    pageOverlays[index] = this;
    buildContent();
  }

  bool liked = false;
  bool disliked = false;
  bool switched = false; //if the user switched like to dislike or the other way around, used to trigger the correct animation on the buttons

  late Widget content;

  void buildContent() {
    LikeButton likeButton = liked
        ? getPressedLikeButton(provider, initiallyPlayingAnimation: switched)
        : getUnpressedLikeButton(provider, initiallyPlayingAnimation: switched);
    DislikeButton dislikeButton = disliked
        ? getPressedDislikeButton(initiallyPlayingAnimation: switched)
        : getUnpressedDislikeButton(initiallyPlayingAnimation: switched);

    content = Align(
      alignment: Alignment.centerRight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [likeButton, dislikeButton, Icon(CupertinoIcons.ellipses_bubble), Icon(CupertinoIcons.share)],
      ),
    );
  }

  void onLikeChanged(bool newLiked) {
    liked = newLiked;
    if (disliked && newLiked) {
      disliked = false;
      // Reset button instances to force rebuild with correct state
      pressedDislikeButton = null;
      unPressedDislikeButton = null;
      switched = true;
      buildContent();
    }
    notifyListeners();
    switched = false;
  }

  void onDislikeChanged(bool newDisliked) {
    disliked = newDisliked;
    if (liked && newDisliked) {
      liked = false;
      // Reset button instances to force rebuild with correct state
      pressedLikeButton = null;
      unPressedLikeButton = null;
      switched = true;
      buildContent();
    }
    notifyListeners();
    switched = false;
  }

  DislikeButton? pressedDislikeButton;
  DislikeButton? unPressedDislikeButton;

  LikeButton? pressedLikeButton;
  LikeButton? unPressedLikeButton;

  LikeButton getPressedLikeButton(TickerProvider provider, {bool initiallyPlayingAnimation = false}) {
    pressedLikeButton ??= LikeButton(
      userId: auth!.currentUser!.uid,
      videoId: videoId,
      provider: provider,
      key: GlobalObjectKey("pressed_like_${index % 4}"),
      initiallyLiked: true,
      onLikeChanged: onLikeChanged,
      initiallyPlayingAnimation: initiallyPlayingAnimation,
    );
    return pressedLikeButton!;
  }

  LikeButton getUnpressedLikeButton(TickerProvider provider, {bool initiallyPlayingAnimation = false}) {
    unPressedLikeButton ??= LikeButton(
      provider: provider,
      key: GlobalObjectKey("unpressed_like_${index % 4}"),
      initiallyLiked: false,
      onLikeChanged: onLikeChanged,
      initiallyPlayingAnimation: initiallyPlayingAnimation,
      videoId: videoId,
      userId: auth!.currentUser!.uid,
    );
    return unPressedLikeButton!;
  }

  DislikeButton getPressedDislikeButton({bool initiallyPlayingAnimation = false}) {
    pressedDislikeButton ??= DislikeButton(
      key: GlobalObjectKey("pressed_dislike_${index % 4}"),
      initiallyDisliked: true,
      onDislikeChanged: onDislikeChanged,
      initiallyPlayingAnimation: initiallyPlayingAnimation,
      videoId: videoId,
      userId: auth!.currentUser!.uid,
    );
    return pressedDislikeButton!;
  }

  DislikeButton getUnpressedDislikeButton({bool initiallyPlayingAnimation = false}) {
    unPressedDislikeButton ??= DislikeButton(
      key: GlobalObjectKey("unpressed_dislike_${index % 4}"),
      initiallyDisliked: false,
      onDislikeChanged: onDislikeChanged,
      initiallyPlayingAnimation: initiallyPlayingAnimation,
      videoId: videoId,
      userId: auth!.currentUser!.uid,
    );
    return unPressedDislikeButton!;
  }
}
