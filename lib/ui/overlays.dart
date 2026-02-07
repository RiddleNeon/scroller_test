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
    print("Created overlay for index $index");
  }
  late final Align content = Align(
    alignment: AlignmentGeometry.centerRight,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 8,
      children: [
        LikeButton(provider: provider, key: GlobalObjectKey("like_$index")),
        DislikeButton(key: GlobalObjectKey("dislike_$index"),),
        Icon(CupertinoIcons.ellipses_bubble),
        Icon(CupertinoIcons.share),
      ],
    ),
  );
}