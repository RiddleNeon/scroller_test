import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/scheduler/ticker.dart';
import 'package:lottie/lottie.dart';

class LikeButton extends StatefulWidget {
  final TickerProvider provider;

  const LikeButton({super.key, required this.provider});

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  bool liked = false;
  @override
  Widget build(BuildContext context) {
    AnimationController controller = AnimationController(vsync: widget.provider, upperBound: 0.5);
    LottieBuilder builder = Lottie.asset("assets/like.json", width: 64, controller: controller,
        height: 64, onLoaded: (p0) => (controller..duration = p0.duration));


    return Padding(
      padding: EdgeInsetsGeometry.all(5),
      child: InkWell(
          onTap: () {
            if (kDebugMode) {
              print("like!");
            }
            controller.animateTo(liked ? controller.lowerBound : controller.upperBound, duration: Duration(milliseconds: 600));
            liked = !liked;
          },
          child: builder
      ),
    );
  }
}
