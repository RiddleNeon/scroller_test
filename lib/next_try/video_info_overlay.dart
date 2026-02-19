import 'package:flutter/material.dart';
import '../logic/video/video.dart';

class VideoInfoOverlay extends StatelessWidget {
  final VideoWithAuthor videoWithAuthor;

  const VideoInfoOverlay({super.key, required this.videoWithAuthor});

  @override
  Widget build(BuildContext context) {
    final video = videoWithAuthor.video;
    final author = videoWithAuthor.author;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 60, 16, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '@${author.username}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),
          if (video.title.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              video.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
          ],
          if (video.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              video.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
          ],
          if (video.tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: video.tags.take(4).map((tag) => Text(
                '#$tag',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              )).toList(),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.music_note, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              // ✅ Isolated StatefulWidget – only this widget rebuilds per frame
              Expanded(
                child: ScrollingAudioText(
                  text: 'Original Sound – @${author.username}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Fully isolated StatefulWidget with its own AnimationController.
/// Only this widget rebuilds on each animation frame – nothing above it.
class ScrollingAudioText extends StatefulWidget {
  final String text;
  const ScrollingAudioText({super.key, required this.text});

  @override
  State<ScrollingAudioText> createState() => _ScrollingAudioTextState();
}

class _ScrollingAudioTextState extends State<ScrollingAudioText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _offset = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: const Offset(-1.0, 0),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.linear));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SlideTransition(
        position: _offset,
        child: Text(
          widget.text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
          ),
          maxLines: 1,
          overflow: TextOverflow.visible,
          softWrap: false,
        ),
      ),
    );
  }
}