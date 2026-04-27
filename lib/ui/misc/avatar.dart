import 'package:flutter/material.dart';
import 'package:wurp/logic/repositories/user_repository.dart';

class Avatar extends StatelessWidget {
  final ColorScheme colorScheme;
  final String? imageUrl;
  final String name;

  const Avatar({super.key, required this.imageUrl, required this.name, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.surfaceContainerHigh,
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.9)),
      ),
      child: CircleAvatar(
        radius: 26,
        backgroundColor: colorScheme.surfaceContainer,
        foregroundImage: (imageUrl?.isNotEmpty ?? false)
            ? NetworkImage(imageUrl!)
            : null,
        backgroundImage: NetworkImage(createUserProfileImageUrl(name)),
      )
    );
  }
}
