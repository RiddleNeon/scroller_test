import 'package:flutter/cupertino.dart';

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
        spacing: 32,
        children: [
          LikeButton(provider: provider),
          Icon(CupertinoIcons.hand_thumbsdown_fill),
          Icon(CupertinoIcons.ellipses_bubble),
          Icon(CupertinoIcons.share),
        ],
      ),
    );
  }
}
