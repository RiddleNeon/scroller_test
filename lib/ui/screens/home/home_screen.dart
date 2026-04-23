import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wurp/base_logic.dart';
import 'package:wurp/logic/repositories/video_repository.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/ui/deep_link_builder.dart';
import 'package:wurp/ui/misc/avatar.dart';

import '../../theme/theme_ui_values.dart';
import '../search_screen/search_screen.dart';
import '../search_screen/widgets/search_video_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<Video>? _discoverVideos;
  List<Video>? _followingVideos;

  // TODO
  // List<Quest>? _activeQuests; 

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
        following = await videoRepo.getFollowingFeed(currentUser.id, limit: 12);
      } catch (_) {
        following = [];
      }

      // TODO: _activeQuests = await questRepo.getActiveQuests(currentUser.id);

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth > 600;

            return RefreshIndicator(
              onRefresh: _loadContent,
              color: cs.primary,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  _buildSliverAppBar(cs),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: context.uiSpace(16),
                          vertical: context.uiSpace(8)
                      ),
                      child: _buildInteractiveSearchBar(cs),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: context.uiSpace(24), bottom: context.uiSpace(8)),
                      child: _buildSectionTitle(cs, 'Your Path', 'Keep progressing'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildHorizontalQuestsList(cs, isTablet),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: context.uiSpace(32), bottom: context.uiSpace(16)),
                      child: _buildSectionTitle(cs, 'Discover', 'Trending right now',
                          onSeeAll: () => GoRouter.of(context).push(DeepLinkBuilder.search()) // TODO: Route to full trending page
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildDiscoverCarousel(cs),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: context.uiSpace(32), bottom: context.uiSpace(16)),
                      child: _buildSectionTitle(cs, 'Following', 'Latest from your creators'),
                    ),
                  ),
                  _buildFollowingGrid(cs, isTablet),

                  SliverToBoxAdapter(child: SizedBox(height: context.uiSpace(40))),
                ],
              ),
            );
          },
        ),
      ),
    );
  }


  SliverAppBar _buildSliverAppBar(ColorScheme cs) {
    return SliverAppBar(
      floating: true,
      backgroundColor: cs.surface,
      elevation: 0,
      expandedHeight: 80,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.uiSpace(16)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Avatar(imageUrl: currentUser.profileImageUrl, name: currentUser.username, colorScheme: cs),
              SizedBox(width: context.uiSpace(16)),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back,', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
                    Text(
                      currentUser.username,
                      style: TextStyle(color: cs.onSurface, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Material(
                color: cs.surfaceContainerHigh,
                shape: const CircleBorder(),
                clipBehavior: Clip.hardEdge,
                child: InkWell(
                  onTap: () => GoRouter.of(context).go(DeepLinkBuilder.quests()),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Icon(Icons.map_outlined, color: cs.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildInteractiveSearchBar(ColorScheme cs) {
    return Hero(
      tag: 'search_bar', // TODO: Add matching Hero tag to SearchScreen
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(context.uiRadiusLg),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: () => GoRouter.of(context).push(DeepLinkBuilder.search()),
          child: Container(
            height: 56,
            padding: EdgeInsets.symmetric(horizontal: context.uiSpace(16)),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: cs.onSurfaceVariant),
                SizedBox(width: context.uiSpace(12)),
                Expanded(
                  child: Text(
                    'Search videos, creators or tags...',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(ColorScheme cs, String title, String subtitle, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.uiSpace(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              ),
            ],
          ),
          if (onSeeAll != null)
            InkWell(
              onTap: onSeeAll,
              borderRadius: BorderRadius.circular(context.uiRadiusSm),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text('See all', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildHorizontalQuestsList(ColorScheme cs, bool isTablet) {
    return SizedBox(
      height: 140,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: context.uiSpace(16)),
        children: [
          _buildQuestCard(
            cs: cs,
            title: 'Continue learning',
            subtitle: 'Basics of Flutter',
            progress: 0.65,
            icon: Icons.play_arrow_rounded,
            color: cs.primaryContainer,
            onColor: cs.onPrimaryContainer,
            width: isTablet ? 300 : MediaQuery.of(context).size.width * 0.75,
          ),
          SizedBox(width: context.uiSpace(12)),
          _buildQuestCard(
            cs: cs,
            title: 'Daily Goal',
            subtitle: 'Watch 3 videos',
            progress: 0.33,
            icon: Icons.local_fire_department_rounded,
            color: cs.tertiaryContainer,
            onColor: cs.onTertiaryContainer,
            width: isTablet ? 300 : MediaQuery.of(context).size.width * 0.75,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestCard({
    required ColorScheme cs,
    required String title,
    required String subtitle,
    required double progress,
    required IconData icon,
    required Color color,
    required Color onColor,
    required double width,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(context.uiRadiusLg),
      ),
      clipBehavior: Clip.hardEdge,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => GoRouter.of(context).go('/quests'),
          child: Padding(
            padding: EdgeInsets.all(context.uiSpace(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: onColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(icon, color: onColor),
                    ),
                    Text('${(progress * 100).toInt()}%', style: TextStyle(color: onColor, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: onColor, fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(subtitle, style: TextStyle(color: onColor.withValues(alpha: 0.8), fontSize: 13)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(context.uiRadiusSm),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        color: onColor,
                        backgroundColor: onColor.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildDiscoverCarousel(ColorScheme cs) {
    if (_loading) {
      return const SizedBox(height: 280, child: Center(child: CircularProgressIndicator()));
    }

    final items = _discoverVideos ?? [];
    if (items.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text('Nothing trending right now.', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }

    return SizedBox(
      height: 280, 
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: context.uiSpace(16)),
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(width: context.uiSpace(16)),
        itemBuilder: (context, index) {
          final video = items[index];
          return _LargeCarouselVideoCard(video: video, ticker: this, videos: items);
        },
      ),
    );
  }


  Widget _buildFollowingGrid(ColorScheme cs, bool isTablet) {
    if (_loading) {
      return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
    }

    final items = _followingVideos ?? [];
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(context.uiSpace(32)),
            child: Text('Follow more creators to see their content here.', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: context.uiSpace(16)),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isTablet ? 2 : 1,
          mainAxisSpacing: context.uiSpace(16),
          crossAxisSpacing: context.uiSpace(16),
          childAspectRatio: isTablet ? 2.5 : 3.0,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) => _FeedListVideoCard(video: items[index], ticker: this, videos: items),
          childCount: items.length,
        ),
      ),
    );
  }
}

class _LargeCarouselVideoCard extends StatelessWidget {
  final Video video;
  final List<Video> videos;
  final TickerProvider ticker;

  const _LargeCarouselVideoCard({required this.video, required this.videos, required this.ticker});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Container(
      width: isTablet ? 360 : MediaQuery.of(context).size.width * 0.8,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(context.uiRadiusLg),
        boxShadow: [
          BoxShadow(color: cs.shadow.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            // TODO: Ensure your openVideoPlayer handles context and logic correctly
            await openVideoPlayer(
              context: context,
              listedVideos: videos,
              videoIndex: videos.indexOf(video),
              feedModel: null,
              tickerProvider: ticker,
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: FutureBuilder(
                  future: thumbnailFor(video),
                  builder: (context, snap) {
                    Widget imageWidget = Container(color: cs.surfaceContainerHighest);
                    if (snap.hasData && snap.data != null) {
                      imageWidget = Image.memory(snap.data!, fit: BoxFit.cover, width: double.infinity);
                    }
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        imageWidget,
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.4)],
                                stops: const [0.7, 1.0],
                              ),
                            ),
                          ),
                        ),
                        if (video.duration != null)
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(context.uiRadiusSm),
                              ),
                              child: Text(
                                _formatDuration(video.duration!),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.all(context.uiSpace(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800, fontSize: 16, height: 1.2),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: cs.primary),
                          const SizedBox(width: 4),
                          Text(
                            video.authorName,
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = duration.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _FeedListVideoCard extends StatelessWidget {
  final Video video;
  final List<Video> videos;
  final TickerProvider ticker;

  const _FeedListVideoCard({required this.video, required this.videos, required this.ticker});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(context.uiRadiusMd),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await openVideoPlayer(
              context: context,
              listedVideos: videos,
              videoIndex: videos.indexOf(video),
              feedModel: null,
              tickerProvider: ticker,
            );
          },
          child: Row(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: FutureBuilder(
                  future: thumbnailFor(video),
                  builder: (context, snap) {
                    if (snap.hasData && snap.data != null) {
                      return Image.memory(snap.data!, fit: BoxFit.cover);
                    }
                    return Container(color: cs.surfaceContainerHighest, child: const Icon(Icons.image_outlined, color: Colors.grey));
                  },
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(context.uiSpace(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const Spacer(),
                      Text(
                        video.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                      ),
                      if (video.tags.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '#${video.tags.first}',
                          style: TextStyle(color: cs.primary, fontSize: 11, fontWeight: FontWeight.bold),
                        )
                      ]
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}