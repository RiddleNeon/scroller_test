import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../logic/video/video_provider.dart';
import '../feed_view_model.dart';
import '../short_video_player.dart';

class FeedHost extends StatefulWidget {
  final VideoProvider provider;
  final int initialPage;

  const FeedHost({super.key, required this.provider, required this.initialPage});

  @override
  State<FeedHost> createState() => _FeedHostState();
}

class _FeedHostState extends State<FeedHost> with TickerProviderStateMixin {
  late final FeedViewModel model;

  @override
  void initState() {
    super.initState();
    model = FeedViewModel(widget.provider);
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return feedVideos(this, widget.provider, feedModel: model, initialPage: widget.initialPage);
  }
}