import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LikeButton extends StatefulWidget {
  final TickerProvider provider;
  final bool initiallyLiked;
  final void Function(bool)? onLikeChanged;

  const LikeButton({super.key, required this.provider, this.initiallyLiked = false, this.onLikeChanged});

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  late bool liked = widget.initiallyLiked;
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: widget.provider, upperBound: 0.5);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    LottieBuilder builder = Lottie.asset(
      "assets/like.json",
      controller: controller,
      onLoaded: (composition) {
        controller.duration = composition.duration;
      },
      fit: BoxFit.contain,
      filterQuality: FilterQuality.low,
    );

    return InkWell(
      onTap: () {
        controller.animateTo(liked ? controller.lowerBound : controller.upperBound, duration: const Duration(milliseconds: 600));
        setState(() {
          liked = !liked;
          widget.onLikeChanged?.call(liked);
        });
      },
      child: Transform.scale(scale: 2, child: SizedBox(width: 32, height: 32, child: builder)),
    );
  }
}
