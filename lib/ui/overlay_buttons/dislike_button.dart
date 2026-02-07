import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/scheduler/ticker.dart';
import 'package:lottie/lottie.dart';

class DislikeButton extends StatefulWidget {
  final TickerProvider provider;

  const DislikeButton({super.key, required this.provider});

  @override
  State<DislikeButton> createState() => _DislikeButtonState();
}

class _DislikeButtonState extends State<DislikeButton> {
  bool liked = false;
  @override
  Widget build(BuildContext context) {
    AnimationController controller = AnimationController(vsync: widget.provider, upperBound: 0.5);
    LottieBuilder builder = Lottie.asset("assets/like.json", width: 64, controller: controller,
        height: 32, onLoaded: (p0) => (controller..duration = p0.duration), fit: BoxFit.cover, filterQuality: FilterQuality.low);


    return Padding(
      padding: EdgeInsetsGeometry.all(1),
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
