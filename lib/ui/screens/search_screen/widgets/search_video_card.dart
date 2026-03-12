import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:wurp/logic/video/video.dart';

class VideoCard extends StatefulWidget {
  const VideoCard({
    super.key,
    required this.video,
    required this.thumbnail,
    required this.onTap,
    required this.cs,
  });

  final Video video;
  final Future<Uint8List?> thumbnail;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: _hovered ? cs.surfaceContainerHigh : cs.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered
                  ? cs.primary.withValues(alpha: 0.35)
                  : cs.outlineVariant.withValues(alpha: 0.3),
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: cs.primary.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))]
                : [],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                child: SizedBox(width: 160, height: 96, child: _buildThumbnail(cs)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.35),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_arrow_rounded, color: cs.primary, size: 13),
                                const SizedBox(width: 3),
                                Text('Watch',
                                    style: TextStyle(
                                        color: cs.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: _hovered ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.4),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(ColorScheme cs) {
    if (!(defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS)) {
      return _shimmer(cs);
    }
    return FutureBuilder<Uint8List?>(
      future: widget.thumbnail,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(snapshot.data!, fit: BoxFit.cover),
              if (_hovered)
                Container(
                  color: Colors.black.withValues(alpha: 0.2),
                  child: const Center(
                      child: Icon(Icons.play_circle_fill_rounded,
                          color: Colors.white, size: 36)),
                ),
            ],
          );
        }
        return _shimmer(cs);
      },
    );
  }

  Widget _shimmer(ColorScheme cs) =>
      Shimmer(child: Container(color: cs.surfaceContainerHighest));
}