import 'package:flutter/material.dart';
import 'package:wurp/logic/local_storage/local_seen_service.dart';
import 'package:wurp/logic/models/user_model.dart';

import '../../../base_logic.dart';

enum FollowButtonDesign { floating, docked }

class FollowButton extends StatefulWidget {
  final bool initialSubscribed;
  final UserProfile user;
  final Future<void> Function(bool)? onChanged;
  final FollowButtonDesign design;

  const FollowButton({super.key, this.initialSubscribed = false, this.onChanged, this.design = .floating, required this.user});

  @override
  State<FollowButton> createState() => FollowButtonState();
}

class FollowButtonState extends State<FollowButton> with SingleTickerProviderStateMixin {
  late bool _subscribed = widget.initialSubscribed;
  bool _isLoading = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(CurvedAnimation(parent: _controller, curve: Curves.bounceInOut));

    _checkAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
  }

  void _toggle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    await _controller.forward();
    _controller.reverse();

    _subscribed = await userRepository.toggleFollowUser(widget.user.id);
    if (_subscribed)
      localSeenService.followUser(widget.user.id);
    else
      localSeenService.unfollowUser(widget.user.id);
    await widget.onChanged?.call(_subscribed);
    setState(() {
      _isLoading = false;
    });
  }

  void setFollowed(bool followed) {
    setState(() {
      _subscribed = followed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final backgroundColor = _subscribed ? theme.colorScheme.secondaryContainer : theme.colorScheme.primary;

    final foregroundColor = _subscribed ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onPrimary;

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedScale(
        scale: _scaleAnimation.value,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: widget.design == FollowButtonDesign.floating
                ? BorderRadius.circular(16)
                : const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(animation),
                  child: child,
                ),
              );
            },
            child: Row(
              key: ValueKey(_subscribed),
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _checkAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _subscribed ? 1 - _checkAnimation.value : 1 - _checkAnimation.value,
                      child: Icon(_subscribed ? Icons.check_circle : Icons.notifications, color: foregroundColor),
                    );
                  },
                ),
                const SizedBox(width: 10),
                Text(
                  _subscribed ? "Followed" : "Follow",
                  style: theme.textTheme.labelLarge?.copyWith(color: foregroundColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
