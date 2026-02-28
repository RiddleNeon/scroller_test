import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
// ignore: deprecated_member_use
import 'dart:html' as html;

class YouTubePlayerWidget extends StatefulWidget {
  final String? videoUrl;
  final String? videoId;
  final bool autoPlay;
  final bool showControls;
  final double aspectRatio;

  const YouTubePlayerWidget({
    super.key,
    this.videoUrl,
    this.videoId,
    this.autoPlay = false,
    this.showControls = true,
    this.aspectRatio = 16 / 9,
  }) : assert(
  (videoUrl != null) != (videoId != null),
  'Either a video id or a video url has to be set!',
  );

  static String? extractVideoId(String url) {
    final patterns = [
      RegExp(r'youtube\.com/watch\?.*v=([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) return match.group(1);
    }
    return null;
  }

  @override
  State<YouTubePlayerWidget> createState() => YouTubePlayerWidgetState();
}

class YouTubePlayerWidgetState extends State<YouTubePlayerWidget> {
  late final String _viewId;
  late final String _videoId;
  late final html.IFrameElement _iframe;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    if (widget.videoId != null) {
      _videoId = widget.videoId!;
    } else {
      final extracted = YouTubePlayerWidget.extractVideoId(widget.videoUrl!);
      if (extracted == null) {
        _hasError = true;
        _videoId = '';
        return;
      }
      _videoId = extracted;
    }

    _viewId =
    'youtube-player-$_videoId-${DateTime.now().microsecondsSinceEpoch}';

    final autoplay = widget.autoPlay ? 1 : 0;
    final controls = widget.showControls ? 1 : 0;

    // enablejsapi=1 ist notwendig, damit postMessage funktioniert
    _iframe = html.IFrameElement()
      ..src =
          'https://www.youtube.com/embed/$_videoId?autoplay=$autoplay&controls=$controls&playsinline=1&rel=0&enablejsapi=1'
      ..allow =
          'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen'
      ..allowFullscreen = true
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';

    _iframe.style.pointerEvents = 'none';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
          (int viewId) => _iframe,
    );
  }

  /// Pausiert den YouTube-Player über die IFrame API via postMessage.
  void stopPlayback() {
    _iframe.contentWindow?.postMessage(
      '{"event":"command","func":"pauseVideo","args":""}',
      '*',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(
                'Invalid YouTube-URL:\n${widget.videoUrl ?? ''}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: HtmlElementView(viewType: _viewId),
      ),
    );
  }
}

Future<void> showRickDialog(BuildContext context) {
  return showDialog(
      context: context,
      builder: (context) {
        return
          Card(
            margin: const EdgeInsetsGeometry.all(120),
            child: YouTubePlayerWidget(
              autoPlay: true,
              showControls: false,
              videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
              key: _youtubePlayerWidgetKey,
            ),
          );
      }).then(
        (value) {
      _youtubePlayerWidgetKey.currentState?.stopPlayback();
      _youtubePlayerWidgetKey = GlobalObjectKey(DateTime.now());
    },
  );
}
GlobalObjectKey<YouTubePlayerWidgetState> _youtubePlayerWidgetKey = GlobalObjectKey(DateTime.now());