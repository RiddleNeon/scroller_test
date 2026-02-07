import 'package:flutter/cupertino.dart';

import 'overlay_buttons/dislike_button.dart';
import 'overlay_buttons/like_button.dart';

class PageOverlay extends StatelessWidget {
  final TickerProvider provider;
  const PageOverlay({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentGeometry.centerRight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          LikeButton(provider: provider),
          LikeButton(provider: provider),
          Icon(CupertinoIcons.ellipses_bubble),
          Icon(CupertinoIcons.share),
        ],
      ),
    );
  }
}
