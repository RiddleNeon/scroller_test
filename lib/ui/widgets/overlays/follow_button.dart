import 'package:flutter/material.dart';

class FollowButton extends StatefulWidget {
  final bool initialSubscribed;
  final ValueChanged<bool>? onChanged;

  const FollowButton({
    super.key,
    this.initialSubscribed = false,
    this.onChanged,
  });

  @override
  State<FollowButton> createState() =>
      _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton>
    with SingleTickerProviderStateMixin {
  late bool _followed;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _followed = widget.initialSubscribed;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _checkAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    );
  }

  void _toggle() async {
    await _controller.forward();
    _controller.reverse();

    setState(() {
      _followed = !_followed;
    });

    widget.onChanged?.call(_followed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final backgroundColor = _followed
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.primary;

    final foregroundColor = _followed
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onPrimary;

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedScale(
        scale: _scaleAnimation.value,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.3),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Row(
              key: ValueKey(_followed),
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _checkAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _followed
                          ? 1-_checkAnimation.value
                          : 1-_checkAnimation.value,
                      child: Icon(
                        _followed
                            ? Icons.check_circle
                            : Icons.notifications,
                        color: foregroundColor,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                Text(
                  _followed ? "Followed" : "Follow",
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.bold,
                  ),
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