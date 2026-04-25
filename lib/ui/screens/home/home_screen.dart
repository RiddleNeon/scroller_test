import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:wurp/base_logic.dart';
import 'package:wurp/logic/repositories/video_repository.dart';
import 'package:wurp/logic/users/user_model.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/ui/video/view_models/feed_view_model.dart';
import 'package:wurp/ui/misc/avatar.dart';

import '../../theme/theme_ui_values.dart';
import '../../video/view_models/video_feed_view_model.dart';
import '../search_screen/search_screen.dart';
import '../search_screen/widgets/search_video_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<Video>? _discoverVideos;

  List<UserProfile> _followedCreators = [];
  final Map<String, List<Video>> _creatorVideos = {};

  late PageController _followingPageController;
  int _currentCreatorIndex = 0;

  bool _loading = true;
  late String _welcomeMessage;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _rawWelcomeMessages = [
    "Ready to dive into something new today?",
    "Your next favorite video is waiting.",
    "Let's learn something awesome, {username}.",
    "Welcome back! Pick up right where you left off.",
    "Hey {username}, great to see you again.",
    "Time to discover some fresh content.",
    "What are we learning today, {username}?",
    "Keep that learning momentum going!",
  ];

  @override
  void initState() {
    super.initState();
    _followingPageController = PageController(viewportFraction: 0.92);
    _setupWelcomeMessage();
    _loadContent();
  }

  @override
  void dispose() {
    _followingPageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _setupWelcomeMessage() {
    final msg = _rawWelcomeMessages[Random().nextInt(_rawWelcomeMessages.length)];
    _welcomeMessage = msg.replaceAll('{username}', currentUser.username);
  }

  Future<void> _loadContent() async {
    setState(() => _loading = true);
    try {
      final discover = await videoRepo.getTrendingVideos(limit: 28);

      _followedCreators = await userRepository.getFollowing(currentUser.id, limit: 5);

      if (mounted) {
        setState(() {
          _discoverVideos = discover;
          _loading = false;
        });

        if (_followedCreators.isNotEmpty) {
          _loadVideosForCreator(_followedCreators.first.id);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _discoverVideos = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadVideosForCreator(String creatorId) async {
    if (_creatorVideos.containsKey(creatorId)) return;

    try {
      final videos = await userRepository.getPublishedVideos(creatorId, limit: 3);

      if (mounted) {
        setState(() {
          _creatorVideos[creatorId] = videos;
        });
      }
    } catch (e) {
      print("Error loading videos for $creatorId: $e");
      if (mounted) {
        setState(() {
          _creatorVideos[creatorId] = [];
        });
      }
    }
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty) return;
    final uri = Uri(path: '/search', queryParameters: {'q': query.trim()});
    GoRouter.of(context).push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadContent,
          color: cs.primary,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              _buildSliverAppBar(cs),

              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: context.uiSpace(16), vertical: context.uiSpace(8)),
                  child: _buildSearchBar(cs),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: context.uiSpace(24), bottom: context.uiSpace(8), left: 14),
                  child: _buildSectionTitle(cs, 'Your Path', ' Keep progressing'),
                ),
              ),
              SliverToBoxAdapter(child: _buildHorizontalQuestsList(cs)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: context.uiSpace(32), bottom: context.uiSpace(16), left: 14),
                  child: _buildSectionTitle(cs, 'Following', ' Latest from your creators'),
                ),
              ),
              SliverToBoxAdapter(child: _buildFollowingCarousel(cs)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: context.uiSpace(32), bottom: context.uiSpace(16), left: 14),
                  child: _buildSectionTitle(cs, 'Discover', ' Trending right now', onSeeAll: () => GoRouter.of(context).push('/feed')),
                ),
              ),
              SliverToBoxAdapter(child: _buildDiscoverCarouselGrid(cs)),

              SliverToBoxAdapter(child: SizedBox(height: context.uiSpace(60))),
            ],
          ),
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
              SizedBox(width: context.uiSpace(12)),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _welcomeMessage,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      currentUser.username,
                      style: TextStyle(color: cs.onSurface, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme cs) {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: _onSearchSubmitted,
      decoration: InputDecoration(
        hintText: 'Search videos, creators or tags...',
        hintStyle: TextStyle(color: cs.onSurfaceVariant),
        prefixIcon: Icon(Icons.search_rounded, color: cs.onSurfaceVariant),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        contentPadding: EdgeInsets.symmetric(horizontal: context.uiSpace(16), vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.uiRadiusLg), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildFollowingCarousel(ColorScheme cs) {
    if (_loading && _followedCreators.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }

    if (_followedCreators.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.uiSpace(32)),
          child: Text('Follow more creators to see their content here.', style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: context.uiSpace(16)),
            itemCount: _followedCreators.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final creator = _followedCreators[index];
              final isSelected = _currentCreatorIndex == index;

              return GestureDetector(
                onTap: () {
                  _followingPageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.all(isSelected ? 3 : 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? cs.primary : Colors.transparent, width: 2),
                  ),
                  child: Avatar(imageUrl: creator.profileImageUrl, name: creator.displayName, colorScheme: cs),
                ),
              );
            },
          ),
        ),

        SizedBox(height: context.uiSpace(16)),

        SizedBox(
          height: 340,
          child: PageView.builder(
            controller: _followingPageController,
            onPageChanged: (index) {
              setState(() => _currentCreatorIndex = index);
              _loadVideosForCreator(_followedCreators[index].id);
            },
            itemCount: _followedCreators.length,
            itemBuilder: (context, index) {
              final creator = _followedCreators[index];
              final videos = _creatorVideos[creator.id];

              return Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: _buildCreatorColumn(cs, creator, videos));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCreatorColumn(ColorScheme cs, dynamic creator, List<Video>? videos) {
    if (videos == null) {
      return Container(
        decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(context.uiRadiusLg)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (videos.isEmpty) {
      return Container(
        decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(context.uiRadiusLg)),
        child: Center(
          child: Text('No videos yet', style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      );
    }

    return Column(
      children: videos
          .take(3)
          .map(
            (v) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _FeedListVideoCard(video: v, videos: videos, ticker: this),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSectionTitle(ColorScheme cs, String title, String subtitle, {VoidCallback? onSeeAll}) {
    return Row(
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
            Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
          ],
        ),
        if (onSeeAll != null)
          InkWell(
            onTap: onSeeAll,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4.0, top: 4.0, right: 12.0),
              child: Text(
                '  See all',
                style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHorizontalQuestsList(ColorScheme cs) {
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
            subtitle: 'PLACEHOLDER',
            progress: 0.65,
            icon: Icons.play_arrow_rounded,
            color: cs.primaryContainer,
            onColor: cs.onPrimaryContainer,
            width: MediaQuery.of(context).size.width * 0.75,
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
            width: MediaQuery.of(context).size.width * 0.75,
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
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(context.uiRadiusLg)),
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
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(color: onColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: onColor, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    Text(subtitle, style: TextStyle(color: onColor.withValues(alpha: 0.8), fontSize: 13)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(context.uiRadiusSm),
                      child: LinearProgressIndicator(value: progress, minHeight: 6, color: onColor, backgroundColor: onColor.withValues(alpha: 0.2)),
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

  Widget _buildDiscoverCarouselGrid(ColorScheme cs) {
    if (_loading) {
      return const SizedBox(height: 280, child: Center(child: CircularProgressIndicator()));
    }

    final items = _discoverVideos ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    //a third of all of the videos
    final itemsRow1 = items.sublist(0, (items.length / 3).ceil());
    final itemsRow2 = items.sublist(itemsRow1.length, itemsRow1.length + (items.length / 3).floor());
    final itemsRow3 = items.sublist(itemsRow1.length + itemsRow2.length, itemsRow1.length + itemsRow2.length + (items.length / 3).floor());
    
    
    return SizedBox(
      height: 800,
      child: Column(
        children: [
          _AutoScrollRow(videos: itemsRow1, speed: 15, ticker: this),
          const SizedBox(height: 16),
          _AutoScrollRow(videos: itemsRow2, speed: 45, ticker: this),
          const SizedBox(height: 16),
          _AutoScrollRow(videos: itemsRow3, speed: 25, ticker: this),
        ],
      ),
    );
  }
}

class _AutoScrollRow extends StatefulWidget {
  final List<Video> videos;
  final double speed;
  final TickerProvider ticker;

  const _AutoScrollRow({required this.videos, required this.speed, required this.ticker});

  @override
  State<_AutoScrollRow> createState() => _AutoScrollRowState();
}

class _AutoScrollRowState extends State<_AutoScrollRow> {
  late final ScrollController _controller;
  late final Ticker _ticker;

  late AnimationController _hoverController;
  late Animation<double> _speedFactor;

  @override
  void initState() {
    super.initState();

    _controller = ScrollController();

    _hoverController = AnimationController(vsync: widget.ticker, duration: const Duration(milliseconds: 1800));

    _speedFactor = Tween<double>(begin: 1.0, end: 0).animate(CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));

    _ticker = widget.ticker.createTicker((elapsed) {
      if (!_controller.hasClients) return;

      final effectiveSpeed = widget.speed * _speedFactor.value;
      final offset = _controller.offset + effectiveSpeed * 0.016;

      if (offset >= _controller.position.maxScrollExtent) {
        _controller.jumpTo(0);
      } else {
        _controller.jumpTo(offset);
      }
    });

    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        onEnter: (_) => _hoverController.forward(),
        onExit: (_) => _hoverController.reverse(),
        child: ListView.builder(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.videos.length * 3000,
          itemBuilder: (context, index) {
            final video = widget.videos[index % widget.videos.length];

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 140,
                child: _VerticalVideoCard(video: video, videos: widget.videos, ticker: widget.ticker),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VerticalVideoCard extends StatefulWidget {
  final Video video;
  final List<Video> videos;
  final TickerProvider ticker;

  const _VerticalVideoCard({required this.video, required this.videos, required this.ticker});

  @override
  State<_VerticalVideoCard> createState() => _VerticalVideoCardState();
}

class _VerticalVideoCardState extends State<_VerticalVideoCard> {
  FeedViewModel? _feedVM;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(context.uiRadiusLg)),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: () async {
            _feedVM ??= VideoFeedViewModel();
            await openVideoPlayer(
              context: context,
              listedVideos: widget.videos,
              videoIndex: widget.videos.indexOf(widget.video),
              feedModel: _feedVM,
              tickerProvider: widget.ticker,
            );
            Future.delayed(const Duration(milliseconds: 800), () => _feedVM!.dispose());
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: FutureBuilder(
                  future: thumbnailFor(widget.video),
                  builder: (context, snap) {
                    if (snap.hasData) {
                      return Image.memory(snap.data!, fit: BoxFit.cover, width: double.infinity);
                    }
                    return Container(color: cs.surfaceContainerHighest);
                  },
                ),
              ),

              Expanded(
                flex: 3,
                child: Padding(
                  padding: EdgeInsets.all(context.uiSpace(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 13, height: 1.2),
                      ),

                      SizedBox(height: context.uiSpace(4)),

                      Text(
                        widget.video.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
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
}

class LargeCarouselVideoCard extends StatelessWidget {
  final Video video;
  final List<Video> videos;
  final TickerProvider ticker;

  const LargeCarouselVideoCard({super.key, required this.video, required this.videos, required this.ticker});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(context.uiRadiusLg)),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () async =>
            await openVideoPlayer(context: context, listedVideos: videos, videoIndex: videos.indexOf(video), feedModel: null, tickerProvider: ticker),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: FutureBuilder(
                future: thumbnailFor(video),
                builder: (context, snap) {
                  if (snap.hasData) return Image.memory(snap.data!, fit: BoxFit.cover, width: double.infinity);
                  return Container(color: cs.surfaceContainerHighest);
                },
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(video.authorName, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      height: 100,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(context.uiRadiusMd),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () async =>
            await openVideoPlayer(context: context, listedVideos: videos, videoIndex: videos.indexOf(video), feedModel: null, tickerProvider: ticker),
        child: Row(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: FutureBuilder(
                future: thumbnailFor(video),
                builder: (context, snap) {
                  if (snap.hasData) return Image.memory(snap.data!, fit: BoxFit.cover);
                  return Container(color: cs.surfaceContainerHighest);
                },
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
