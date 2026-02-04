import 'package:flutter/cupertino.dart';

class PageOverlay extends StatelessWidget {
  const PageOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentGeometry.centerRight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 32,
        children: [
          Icon(CupertinoIcons.hand_thumbsup_fill),
          Icon(CupertinoIcons.hand_thumbsdown_fill),
          Icon(CupertinoIcons.ellipses_bubble),
          Icon(CupertinoIcons.share),
        ],
      ),
    );
  }
}
