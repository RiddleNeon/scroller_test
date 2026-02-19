import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../logic/models/user_model.dart';
import '../logic/video/video.dart';

class ActionSidebar extends StatelessWidget {
  final VideoWithAuthor videoWithAuthor;
  final VoidCallback onLike;
  final VoidCallback onFollow;
  final VoidCallback onShare;

  const ActionSidebar({
    super.key,
    required this.videoWithAuthor,
    required this.onLike,
    required this.onFollow,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final video = videoWithAuthor.video;
    final author = videoWithAuthor.author;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AvatarFollow(
          author: author,
          isFollowing: videoWithAuthor.isAuthorFollowed,
          onFollow: onFollow,
        ),
        const SizedBox(height: 20),
        _ActionButton(
          icon: videoWithAuthor.isLiked ? Icons.favorite : Icons.favorite_border,
          iconColor: videoWithAuthor.isLiked ? Colors.red : Colors.white,
          label: _fmt(video.likesCount ?? 0),
          onTap: onLike,
        ),
        const SizedBox(height: 20),
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          label: _fmt(video.commentsCount ?? 0),
          onTap: () {},
        ),
        const SizedBox(height: 20),
        _ActionButton(
          icon: Icons.reply,
          label: _fmt(video.sharesCount ?? 0),
          onTap: onShare,
        ),
        const SizedBox(height: 20),
        // ✅ Isolated StatefulWidget – only this widget rebuilds each frame
        SpinningRecord(imageUrl: author.profileImageUrl),
        const SizedBox(height: 24),
      ],
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _AvatarFollow extends StatelessWidget {
  final UserProfile author;
  final bool isFollowing;
  final VoidCallback onFollow;

  const _AvatarFollow({
    required this.author,
    required this.isFollowing,
    required this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onFollow,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: author.profileImageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                const CircularProgressIndicator(strokeWidth: 1),
                errorWidget: (_, __, ___) =>
                const Icon(Icons.person, color: Colors.white),
              )
            ),
          ),
          Positioned(
            bottom: -8,
            child: GestureDetector(
              onTap: onFollow,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isFollowing ? Colors.grey : const Color(0xFFFF0050),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFollowing ? Icons.check : Icons.add,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 36),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Fully isolated StatefulWidget with its own AnimationController.
/// Only this widget rebuilds on each animation frame – nothing above it.
class SpinningRecord extends StatefulWidget {
  final String? imageUrl;
  const SpinningRecord({super.key, this.imageUrl});

  @override
  State<SpinningRecord> createState() => _SpinningRecordState();
}

class _SpinningRecordState extends State<SpinningRecord>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 6),
          color: Colors.black,
        ),
        child: ClipOval(
          child: widget.imageUrl != null
              ? CachedNetworkImage(
            imageUrl: widget.imageUrl!,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) =>
            const Icon(Icons.music_note, color: Colors.white, size: 18),
          )
              : const Icon(Icons.music_note, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}