import 'package:flutter/material.dart';

import '../../logic/repositories/user_repository.dart';

class Avatar extends StatelessWidget {
  final ColorScheme colorScheme;
  final String? imageUrl;
  final String name;
  const Avatar({super.key, required this.imageUrl, required this.name, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [colorScheme.primary, colorScheme.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: CircleAvatar(
        radius: 26,
        backgroundColor: colorScheme.surfaceContainer,
        backgroundImage: (imageUrl?.isNotEmpty ?? false)
            ? NetworkImage(imageUrl!)
            : NetworkImage(createUserProfileImageUrl(name)),
      ),
    );
  }
}
