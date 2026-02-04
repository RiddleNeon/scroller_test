import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/scheduler/ticker.dart';
import 'package:lottie/lottie.dart';

class LikeButton extends StatelessWidget {
  final TickerProvider provider;

  const LikeButton({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    AnimationController controller = AnimationController(vsync: provider, upperBound: 0.5);
    LottieBuilder builder = Lottie.asset("assets/like.json", width: 64, controller: controller,
        height: 64, onLoaded: (p0) => (controller..duration = p0.duration));
    
    
    return Padding(
      padding: EdgeInsetsGeometry.all(5),
      child: InkWell(
          onTap: () {
            if (kDebugMode) {
              print("like!");
            }
            controller.animateTo(controller.upperBound, duration: Duration(milliseconds: 600));
          },
          child: builder
      ),
    );
  }
}
