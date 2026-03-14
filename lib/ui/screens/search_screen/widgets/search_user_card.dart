import 'package:flutter/material.dart';
import 'package:wurp/logic/models/user_model.dart';
import 'package:wurp/logic/repositories/user_repository.dart';
import 'package:wurp/ui/screens/profile_screen.dart';
import 'package:wurp/ui/widgets/overlays/follow_button.dart';

import '../../../../base_logic.dart';
import '../../../../logic/local_storage/local_seen_service.dart';

class UserCard extends StatefulWidget {
  const UserCard({super.key, required this.initialUser, required this.cs, this.onFollowChange});
  
  final void Function(bool)? onFollowChange;
  final UserProfile initialUser;
  final ColorScheme cs;

  @override
  State<UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> {
  late UserProfile user = widget.initialUser;
  late final GlobalKey<FollowButtonState> _followButtonState = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: widget.cs.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) {
                return ProfileScreen(
                  initialProfile: user,
                  ownProfile: user.id == currentUser.id,
                  hasBackButton: true,
                  initialFollowed: localSeenService.isFollowing(user.id),
                  onFollowChange: (bool followed) {
                    if(mounted) {
                      setState(() {
                        user = user.copyWith(followersCount: user.followersCount + (followed ? 1 : -1));
                        _followButtonState.currentState?.setFollowed(followed);
                        widget.onFollowChange?.call(followed);
                      });
                    }
                  },
                );
              },
            ),
          );
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [widget.cs.primary, widget.cs.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: widget.cs.surfaceContainer,
                backgroundImage: (user.profileImageUrl.isNotEmpty)
                    ? NetworkImage(user.profileImageUrl)
                    : NetworkImage(createUserProfileImageUrl(user.username)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: TextStyle(color: widget.cs.onSurface, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text('@${user.username}', style: TextStyle(color: widget.cs.onSurfaceVariant, fontSize: 13)),
                ],
              ),
            ),
            if (user.id != currentUser.id)
              FollowButton(
                key: _followButtonState,
                onChanged: (followed) async {
                  if(mounted) {
                    setState(() {
                      user = user.copyWith(followersCount: user.followersCount + (followed ? 1 : -1));
                      widget.onFollowChange?.call(followed);
                    });
                  }
                },
                initialSubscribed: localSeenService.isFollowing(user.id),
                user: user,
              ),
          ],
        ),
      ),
    );
  }
}
