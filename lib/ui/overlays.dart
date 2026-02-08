import 'package:flutter/cupertino.dart';

import 'overlay_buttons/dislike_button.dart';
import 'overlay_buttons/like_button.dart';

class PageOverlay extends StatefulWidget {
  final TickerProvider provider;
  final int index;

  const PageOverlay({super.key, required this.provider, required this.index});

  @override
  State<PageOverlay> createState() => _PageOverlayState();
}

class _PageOverlayState extends State<PageOverlay> {
  late PageOverlayController controller;

  @override
  void initState() {
    super.initState();
    pageOverlays.remove(widget.index - 10); //clear cache for videos that are far away

    controller = pageOverlays[widget.index] ?? PageOverlayController(widget.index, provider: widget.provider);
    controller.addListener(_onControllerUpdate);
    
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return controller.content;
  }
}

Map<int, PageOverlayController> pageOverlays = {};

class PageOverlayController extends ChangeNotifier {
  final TickerProvider provider;
  final int index;

  PageOverlayController(this.index, {required this.provider}) {
    pageOverlays[index] = this;
    buildContent();
    print("created controller for video $index");
  }

  bool liked = false;
  bool disliked = false;
  bool switched = false; //if the user switched like to dislike or the other way around, used to trigger the correct animation on the buttons

  late Widget content;

  void buildContent() {
    LikeButton likeButton = liked ? getPressedLikeButton(provider, initiallyPlayingAnimation: switched) : getUnpressedLikeButton(provider, initiallyPlayingAnimation: switched);
    DislikeButton dislikeButton = disliked ? getPressedDislikeButton(initiallyPlayingAnimation: switched) : getUnpressedDislikeButton(initiallyPlayingAnimation: switched);
    
    content = Align(
      alignment: Alignment.centerRight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          likeButton,
          dislikeButton,
          Icon(CupertinoIcons.ellipses_bubble),
          Icon(CupertinoIcons.share),
        ],
      ),
    );
  }

  void onLikeChanged(bool newLiked) {
    liked = newLiked;
    if(disliked && newLiked) {
      disliked = false;
      // Reset button instances to force rebuild with correct state
      pressedDislikeButton = null;
      unPressedDislikeButton = null;
      switched = true;
      buildContent();
      notifyListeners();
      switched = false;
      print("Liked video $index, reset dislike");
    }
  }

  void onDislikeChanged(bool newDisliked) {
    disliked = newDisliked;
    if(liked && newDisliked) {
      liked = false;
      // Reset button instances to force rebuild with correct state
      pressedLikeButton = null;
      unPressedLikeButton = null;
      switched = true;
      buildContent();
      notifyListeners();
      switched = false;
      print("Disliked video $index, reset like");
    }
  }

  DislikeButton? pressedDislikeButton;
  DislikeButton? unPressedDislikeButton;

  LikeButton? pressedLikeButton;
  LikeButton? unPressedLikeButton;

  LikeButton getPressedLikeButton(TickerProvider provider, {bool initiallyPlayingAnimation = false}) {
    pressedLikeButton ??= LikeButton(
      provider: provider,
      key: GlobalObjectKey("pressed_like_$index"),
      initiallyLiked: true,
      onLikeChanged: onLikeChanged,
      initiallyPlayingAnimation: initiallyPlayingAnimation,
    );
    return pressedLikeButton!;
  }

  LikeButton getUnpressedLikeButton(TickerProvider provider, {bool initiallyPlayingAnimation = false}) {
    unPressedLikeButton ??= LikeButton(
      provider: provider,
      key: GlobalObjectKey("unpressed_like_$index"),
      initiallyLiked: false,
      onLikeChanged: onLikeChanged,
      initiallyPlayingAnimation: initiallyPlayingAnimation,
    );
    return unPressedLikeButton!;
  }

  DislikeButton getPressedDislikeButton({bool initiallyPlayingAnimation = false}) {
    pressedDislikeButton ??= DislikeButton(
      key: GlobalObjectKey("pressed_dislike_$index"),
      initiallyDisliked: true,
      onDislikeChanged: onDislikeChanged,
      initiallyPlayingAnimation: initiallyPlayingAnimation,
    );
    return pressedDislikeButton!;
  }

  DislikeButton getUnpressedDislikeButton({bool initiallyPlayingAnimation = false}) {
    unPressedDislikeButton ??= DislikeButton(
      key: GlobalObjectKey("unpressed_dislike_$index"),
      initiallyDisliked: false,
      onDislikeChanged: onDislikeChanged,
      initiallyPlayingAnimation: initiallyPlayingAnimation,
    );
    return unPressedDislikeButton!;
  }
}