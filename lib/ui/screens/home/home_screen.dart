import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wurp/base_logic.dart';
import 'package:wurp/logic/repositories/video_repository.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/ui/screens/search_screen/search_screen.dart';
import 'package:wurp/ui/screens/search_screen/widgets/search_video_card.dart';
import 'package:wurp/ui/deep_link_builder.dart';
import 'package:wurp/ui/misc/avatar.dart';
import '../../theme/theme_ui_values.dart';

/// Home screen that aggregates primary app features: search, discover, following and quests.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<Video>? _discoverVideos;
  List<Video>? _followingVideos;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() => _loading = true);
    try {
      final discover = await videoRepo.getTrendingVideos(limit: 8);
      List<Video> following = [];
      try {
        following = await videoRepo.getFollowingFeed(currentUser.id, limit: 8);
      } catch (_) {
        following = [];
      }

      if (mounted) {
        setState(() {
        _discoverVideos = discover;
        _followingVideos = following;
        _loading = false;
      });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _discoverVideos = [];
        _followingVideos = [];
        _loading = false;
      });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadContent,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.uiSpace(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(cs),
                const SizedBox(height: 12),
                _buildSearchBar(cs),
                const SizedBox(height: 8),
                _buildSearchChips(cs),
                const SizedBox(height: 10),
                _buildLearningCard(cs),
                const SizedBox(height: 18),
                _buildSectionLabel('Discover', cs, subtitle: 'New & trending'),
                const SizedBox(height: 8),
                _buildDiscoverGrid(),
                const SizedBox(height: 12),
                _buildSectionLabel('Following', cs, subtitle: 'Latest from creators you follow'),
                const SizedBox(height: 8),
                _buildFollowingList(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    final name = currentUser.username;
    return Container(
      padding: EdgeInsets.all(context.uiSpace(12)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(context.uiRadiusLg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [BoxShadow(color: cs.scrim.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Avatar(imageUrl: currentUser.profileImageUrl, name: currentUser.username, colorScheme: cs),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(getRandomWelcomeMessageFor(name, 'Lumox'), style: TextStyle(color: cs.onSurface, fontSize: 20, fontWeight: FontWeight.w800, height: 1.05)),
                const SizedBox(height: 6),
                Text('Here’s what’s new for you', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => GoRouter.of(context).go(DeepLinkBuilder.quests()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(context.uiRadiusMd),
                boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Icon(Icons.map_outlined, size: 18, color: cs.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Text('Quests', style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme cs) {
    return GestureDetector(
      onTap: () => GoRouter.of(context).push(DeepLinkBuilder.search()),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(context.uiRadiusLg),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.9)),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: cs.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Text('Search videos, creators, tags…', style: TextStyle(color: cs.onSurfaceVariant))),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_voice_outlined, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningCard(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(context.uiRadiusMd),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Continue your learning path', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Resume quests and track your progress', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: 0.42, color: cs.primary, backgroundColor: cs.surfaceContainerHighest),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => GoRouter.of(context).go('/quests'),
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.uiRadiusSm)), elevation: 0, backgroundColor: cs.primary),
            child: const Text('Open'),
          )
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, ColorScheme cs, {String? subtitle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800, fontSize: 16)),
          if (subtitle != null) Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ]),
        TextButton(onPressed: () => GoRouter.of(context).push(DeepLinkBuilder.search()), child: Text('See all', style: TextStyle(color: cs.primary))),
      ],
    );
  }

  Widget _buildSearchChips(ColorScheme cs) {
    final chips = ['test', 'test2', 'test3', 'test4', 'test5'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips.map((c) {
        return ActionChip(
          label: Text('#$c', style: TextStyle(color: cs.onSurface)),
          onPressed: () => GoRouter.of(context).push(DeepLinkBuilder.search(query: c)),
          backgroundColor: cs.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        );
      }).toList(),
    );
  }

  Widget _buildDiscoverGrid() {
    if (_loading) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    final items = _discoverVideos ?? [];
    if (items.isEmpty) return SizedBox(height: 140, child: Center(child: Text('No discoverable videos yet', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))));

    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final v = items[index];
          return _largeVideoCard(video: v, width: MediaQuery.of(context).size.width * 0.72, ticker: this);
        },
      ),
    );
  }

  Widget _buildFollowingList() {
    if (_loading) return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
    final items = _followingVideos ?? [];
    if (items.isEmpty) return SizedBox(height: 120, child: Center(child: Text('No new videos from people you follow', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))));

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final v = items[index];
        return _RectListVideoCard(video: v, ticker: this);
      },
    );
  }

  Widget _largeVideoCard({required Video video, required double width, required TickerProvider ticker}) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () async {
        await openVideoPlayer(context: context, listedVideos: _discoverVideos ?? [video], videoIndex: _discoverVideos?.indexOf(video) ?? 0, feedModel: null, tickerProvider: ticker);
      },
      child: Container(
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.uiRadiusLg),
          color: cs.surfaceContainerHigh,
          boxShadow: [BoxShadow(color: cs.scrim.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 6))],
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FutureBuilder(
                future: thumbnailFor(video),
                builder: (context, snap) {
                  if (snap.hasData && snap.data != null) {
                    return Stack(fit: StackFit.expand, children: [Image.memory(snap.data!, fit: BoxFit.cover), Positioned(right: 12, bottom: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: cs.scrim.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(context.uiRadiusSm)), child: Text(video.duration != null ? _formatDuration(video.duration) : '', style: TextStyle(color: cs.onSurface, fontSize: 12))))]);
                  }
                  return Container(color: cs.surfaceContainerHighest);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(video.authorName, style: TextStyle(color: cs.onSurfaceVariant))]),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '';
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = duration.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Widget _RectListVideoCard({required Video video, required TickerProvider ticker}) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () async {
        final items = _followingVideos ?? [video];
        await openVideoPlayer(context: context, listedVideos: items, videoIndex: items.indexOf(video), feedModel: null, tickerProvider: ticker);
      },
      child: Container(
        decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(context.uiRadiusMd), border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)), boxShadow: [BoxShadow(color: cs.scrim.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0,4))]),
        clipBehavior: Clip.hardEdge,
        child: Row(
          children: [
            SizedBox(width: 160, height: 100, child: FutureBuilder(future: thumbnailFor(video), builder: (context, snap) { if (snap.hasData && snap.data != null) return Image.memory(snap.data!, fit: BoxFit.cover); return Container(color: cs.surfaceContainerHighest);})),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(video.authorName, style: TextStyle(color: cs.onSurfaceVariant))]),
              ),
            )
          ],
        ),
      ),
    );
  }
}

List<String> rawWelcomeMessages = [
  'Welcome back, {username}! Ready to dive into some new videos?',
  'Hey {username}, great to see you again! Let\'s find something awesome to watch.',
  'Welcome back, {username}! Your next favorite video is just a tap away.',
  'Hi {username}, welcome back! Explore the latest trending videos and creators.',
  'Welcome back, {username}! Let\'s continue your learning journey with some new content.',
  'Hey {username}, great to have you back! Check out what\'s new and trending today.',
  'Welcome back, {username}! How is your learning path going? Let\'s find some videos to help you progress.',
  'Hi {username}, welcome back to {appName}! Discover new videos and creators to fuel your passion.',
  'Welcome back, {username}! Your personalized video feed is waiting for you. Let\'s explore together.',
  'Hey {username}, great to see you again! Dive into the latest videos and continue your learning adventure on {appName}.',
  'Welcome back, {username}! Let\'s find some inspiring videos to keep your learning momentum going.',
  'Hi {username}, welcome back! Explore the latest content and continue your journey of discovery on {appName}.',
  'Welcome back, {username}! Your next learning breakthrough is just a video away. Let\'s find it together.',
  'Hey {username}, great to have you back! Check out the latest videos and keep progressing on your learning path with {appName}.',
  'Welcome back, {username}! Let\'s continue your learning adventure with some new and exciting videos on {appName}.',
  'Hi {username}, welcome back! Your personalized video feed is ready to help you discover new content and keep your learning journey going on {appName}.',
  'Welcome back, {username}! Let\'s find some amazing videos to fuel your passion and keep your learning momentum going on {appName}.',
  'Hey {username}, great to see you again! Explore the latest videos and continue your learning adventure on {appName}. Your next breakthrough is just a tap away.',
  'Welcome back, {username}! What are you in the mood for today? Let\'s find some videos!',
];

String getRandomWelcomeMessageFor(String username, String appName){
  final randomIndex = DateTime.now().millisecondsSinceEpoch % rawWelcomeMessages.length;
  return rawWelcomeMessages[randomIndex].replaceAll('{username}', username).replaceAll('{appName}', appName);
}