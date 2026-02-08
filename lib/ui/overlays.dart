import 'package:flutter/cupertino.dart';

import 'overlay_buttons/dislike_button.dart';
import 'overlay_buttons/like_button.dart';

class PageOverlay extends StatelessWidget {
  final TickerProvider provider;
  final int index;

  //late final void Function() onLike;
  //late final void Function() onDislike;
  //late final void Function(String comment) onComment;
  const PageOverlay({super.key, required this.provider, required this.index});

  @override
  Widget build(BuildContext context) {
    PageOverlayController? cachedController = pageOverlays[index];
    pageOverlays.remove(index - 10); //clear cache for videos that are far away
    cachedController ??= PageOverlayController(index, provider: provider);
    return cachedController.content;
  }
}

Map<int, PageOverlayController> pageOverlays = {};

class PageOverlayController {
  final TickerProvider provider;
  final int index;

  PageOverlayController(this.index, {required this.provider}) {
    pageOverlays[index] = this;
    buildContent();
  }

  bool liked = false;
  bool disliked = false;

  late final Widget content;

  void buildContent() {
    content = Align(
      alignment: AlignmentGeometry.centerRight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          liked ? getPressedLikeButton(provider) : getUnpressedLikeButton(provider),
          disliked ? getPressedDislikeButton() : getUnpressedDislikeButton(),
          Icon(CupertinoIcons.ellipses_bubble),
          Icon(CupertinoIcons.share),
        ],
      ),
    );
  }

  void onLikeChanged(bool newLiked) {
    liked = newLiked;
  }

  DislikeButton? pressedDislikeButton;
  DislikeButton? unPressedDislikeButton;

  LikeButton? pressedLikeButton;
  LikeButton? unPressedLikeButton;

  LikeButton getPressedLikeButton(TickerProvider provider) {
    pressedLikeButton ??= LikeButton(
      provider: provider,
      key: GlobalObjectKey("pressed_like_$index"),
      initiallyLiked: true,
      onLikeChanged: (value) {
        liked = value;
      },
    );
    return pressedLikeButton!;
  }

  LikeButton getUnpressedLikeButton(TickerProvider provider) {
    unPressedLikeButton ??= LikeButton(
      provider: provider,
      key: GlobalObjectKey("unpressed_like_$index"),
      initiallyLiked: false,
      onLikeChanged: (value) {
        disliked = value;
      },
    );
    return unPressedLikeButton!;
  }

  DislikeButton getPressedDislikeButton() {
    pressedDislikeButton ??= DislikeButton(
      key: GlobalObjectKey("pressed_dislike_$index"),
      initiallyDisliked: true,
      onDislikeChanged: (value) {
        liked = value;
      },
    );
    return pressedDislikeButton!;
  }

  DislikeButton getUnpressedDislikeButton() {
    unPressedDislikeButton ??= DislikeButton(
      key: GlobalObjectKey("unpressed_dislike_$index"),
      initiallyDisliked: false,
      onDislikeChanged: (value) {
        disliked = value;
      },
    );
    return unPressedDislikeButton!;
  }
}
