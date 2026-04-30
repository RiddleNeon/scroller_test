import 'package:flutter/material.dart';
import 'package:lumox/logic/repositories/user_repository.dart';

class Avatar extends StatefulWidget {
  final ColorScheme colorScheme;
  final String? imageUrl;
  final String name;

  const Avatar({super.key, required this.imageUrl, required this.name, required this.colorScheme});

  @override
  State<Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<Avatar> {
  bool hasError = false;

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.imageUrl?.isNotEmpty ?? false;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.colorScheme.surfaceContainerHigh,
        border: Border.all(color: widget.colorScheme.outlineVariant.withValues(alpha: 0.9)),
      ),
      child: CircleAvatar(
        radius: 26,
        backgroundColor: widget.colorScheme.surfaceContainer,
        foregroundImage: hasImage && !hasError ? NetworkImage(widget.imageUrl!) : NetworkImage(createUserProfileImageUrl(widget.name)),
        onForegroundImageError: (_, _) {
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            if(mounted) setState(() => hasError = true);
          });
        },
      ),
    );
  }
}
