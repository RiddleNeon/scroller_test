import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wurp/next_try/video_feed_state.dart';
import 'package:wurp/next_try/video_widget.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late final PageController _pageController;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // context.read() must NOT be called directly in initState –
    // the widget isn't fully mounted yet and the call would be silently
    // ignored, meaning initialize() would never run.
    // addPostFrameCallback guarantees the widget is in the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    // mounted check before every async gap
    if (!mounted) return;
    await context.read<VideoFeedState>().initialize();
    if (mounted) setState(() => _initializing = false);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF0050)),
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: 100000,
      onPageChanged: (index) {
        context.read<VideoFeedState>().onPageChanged(index);
      },
      itemBuilder: (context, index) {
        return VideoPage(key: ValueKey(index), index: index);
      },
    );
  }
}