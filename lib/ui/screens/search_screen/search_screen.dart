import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:wurp/logic/feed_recommendation/search_video_result_recommender.dart';
import 'package:wurp/logic/models/user_model.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/ui/feed_view_model.dart';
import 'package:wurp/ui/screens/profile_screen.dart';
import 'package:wurp/ui/screens/search_screen/search_bar_result.dart';
import 'package:wurp/ui/short_video_player.dart';
import 'package:wurp/ui/widgets/overlays/follow_button.dart';

import '../../../base_logic.dart';
import '../../../logic/local_storage/local_seen_service.dart';
import '../../../logic/repositories/user_repository.dart';

class SearchScreen extends StatefulWidget {
  @override
  State<SearchScreen> createState() => _SearchScreenState();

  const SearchScreen({super.key});
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  SearchBarResult? _searchBarResult;

  bool _loading = false;
  bool _preloading = false;
  bool _hasSearched = false;
  int _videoCount = 0;
  int _userCount = 0;

  late TabController _tabController;

  static const _kSearchBarHeight = 56.0;
  static const _kPadding = 16.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_searchBarResult == null || _loading || _preloading) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _preloadMore();
    }
  }

  bool _preloadingGuard = false;

  Future<void> _preloadMore() async {
    if (_preloadingGuard) return;
    _preloadingGuard = true;
    setState(() => _preloading = true);

    if (_tabController.index == 0) {
      await _searchBarResult!.preloadMoreVideos();
      if (mounted) setState(() {
        _preloading = false;
        _videoCount = _searchBarResult!.videoResults.length;
      });
    } else {
      await _searchBarResult!.preloadMoreUsers();
      if (mounted) setState(() {
        _preloading = false;
        _userCount = _searchBarResult!.userResults.length;
      });
    }

    _preloadingGuard = false;
  }

  @override
  void dispose() {
    _cachedThumbnails.clear();
    _scrollController.dispose();
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search([String? val]) async {
    val ??= _controller.text;
    if (val.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _hasSearched = true;
      _loading = true;
    });
    _searchBarResult = SearchBarResult(val);
    await _searchBarResult!.complete();
    _currentSearchViewModel = FeedViewModel();
    _videoCount = _searchBarResult!.videoResults.length;
    _userCount = _searchBarResult!.userResults.length;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(backgroundColor: cs.surface, body: _hasSearched ? _buildResultsBody(cs) : _buildLandingBody(cs));
  }

  Widget _buildLandingBody(ColorScheme cs) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(colors: [cs.primary, cs.secondary]).createShader(bounds),
              child: Text(
                'Discover',
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1, color: cs.onSurface),
              ),
            ),
            const SizedBox(height: 8),
            Text('Find videos & creators', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
            const SizedBox(height: 40),
            _buildSearchField(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsBody(ColorScheme cs) {
    return ScrollConfiguration(
      behavior: _SmoothScrollBehavior(),
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            final newOffset = (_scrollController.offset + event.scrollDelta.dy * 1.8)
                .clamp(0.0, _scrollController.position.maxScrollExtent);
            _scrollController.animateTo(
              newOffset,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
            );
          }
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: cs.surface,
              pinned: true,
              floating: true,
              snap: true,
              elevation: 0,
              expandedHeight: _kSearchBarHeight + _kPadding * 2,
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(padding: const EdgeInsets.fromLTRB(_kPadding, _kPadding + 8, _kPadding, _kPadding), child: _buildSearchField(cs)),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  onTap: (_) => setState(() {}),
                  labelColor: cs.primary,
                  unselectedLabelColor: cs.onSurfaceVariant,
                  indicatorColor: cs.primary,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.5),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_circle_outline, size: 18),
                          const SizedBox(width: 6),
                          Text(_searchBarResult != null ? 'Videos (${_searchBarResult!.videoResults.length})' : 'Videos'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline, size: 18),
                          const SizedBox(width: 6),
                          Text(_searchBarResult != null ? 'Creators (${_searchBarResult!.userResults.length})' : 'Creators'),
                        ],
                      ),
                    ),
                  ],
                ),
                cs: cs,
              ),
            ),
            if (_loading)
              SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: cs.primary)),
              )
            else ...[
              if (_tabController.index == 0) _buildVideoSliver(cs) else _buildUserSliver(cs),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(ColorScheme cs) {
    return Container(
      height: _kSearchBarHeight,
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.15), blurRadius: 20)],
      ),
      child: TextField(
        controller: _controller,
        onSubmitted: _search,
        style: TextStyle(color: cs.onSurface, fontSize: 16),
        cursorColor: cs.primary,
        decoration: InputDecoration(
          hintText: 'Search videos, creators, tags…',
          hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search_rounded, color: cs.onSurfaceVariant, size: 22),
          suffixIcon: GestureDetector(
            onTap: _search,
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [cs.primary, cs.primaryContainer]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.arrow_forward_rounded, color: cs.onPrimary, size: 20),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
        ),
      ),
    );
  }

  Widget _buildVideoSliver(ColorScheme cs) {
    final videos = _searchBarResult?.videoResults ?? [];
    if (videos.isEmpty) {
      return SliverFillRemaining(
        child: _EmptyState(label: 'No videos found', cs: cs),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            if (index == _videoCount) {
              return _preloading
                  ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: LinearProgressIndicator(color: cs.primary, backgroundColor: cs.surfaceContainerHighest)),
              )
                  : const SizedBox.shrink();
            }
            return _VideoCard(video: videos[index], thumbnail: _thumbnailFor(videos[index]), onTap: () => _openVideoPlayer(index), cs: cs);
          },
          childCount: _videoCount + 1,
        ),
      ),
    );
  }

  Widget _buildUserSliver(ColorScheme cs) {
    final users = _searchBarResult?.userResults ?? [];
    if (users.isEmpty) {
      return SliverFillRemaining(
        child: _EmptyState(label: 'No creators found', cs: cs),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            if (index == _userCount) {
              return _preloading
                  ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: LinearProgressIndicator(color: cs.primary, backgroundColor: cs.surfaceContainerHighest)),
              )
                  : const SizedBox.shrink();
            }
            return _UserCard(initialUser: users[index], cs: cs, key: ValueKey(users[index].id),);
          },
          childCount: _userCount + 1,
        ),
      ),
    );
  }

  final Map<String, Future<Uint8List?>> _cachedThumbnails = {};

  // Returns the *same* Future instance for the same URL so FutureBuilder
  // does not restart on setState (e.g. after preloading more videos).
  Future<Uint8List?> _thumbnailFor(Video video) {
    if (!(defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      return Future.value(null);
    }
    return _cachedThumbnails[video.videoUrl] ??= VideoThumbnail.thumbnailData(video: video.videoUrl);
  }

  FeedViewModel? _currentSearchViewModel;

  void _openVideoPlayer(int videoIndex) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'VideoOverlay',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, __) => SafeArea(
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.95,
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                children: [
                  feedVideos(
                    this,
                    SearchVideoResultRecommender(listedVideos: _searchBarResult!.videoResults),
                    context,
                    feedModel: _currentSearchViewModel,
                    itemCount: _searchBarResult!.videoResults.length,
                    initialPage: videoIndex,
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: 0.88, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }
}

class _VideoCard extends StatefulWidget {
  const _VideoCard({required this.video, required this.thumbnail, required this.onTap, required this.cs});

  final Video video;
  final Future<Uint8List?> thumbnail;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
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
              color: _hovered ? cs.primary.withValues(alpha: 0.35) : cs.outlineVariant.withValues(alpha: 0.3),
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
                        style: TextStyle(color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w600, height: 1.35),
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
                                Text('Watch', style: TextStyle(color: cs.primary, fontSize: 11, fontWeight: FontWeight.w600)),
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
    if (!(defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
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
                  child: const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 36)),
                ),
            ],
          );
        }
        return _shimmer(cs);
      },
    );
  }

  Widget _shimmer(ColorScheme cs) => Shimmer(child: Container(color: cs.surfaceContainerHighest));
}

class _UserCard extends StatefulWidget {
  const _UserCard({required this.initialUser, required this.cs, super.key});

  final UserProfile initialUser;
  final ColorScheme cs;

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  late UserProfile user = widget.initialUser;
  late final GlobalObjectKey<FollowButtonState> _followButtonState = GlobalObjectKey('followButton${user.id}');

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
                    setState(() {
                      user = user.copyWith(followersCount: user.followersCount + (followed ? 1 : -1));
                      _followButtonState.currentState?.setFollowed(followed);
                    });
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
                  ...[const SizedBox(height: 2), Text('@${user.username}', style: TextStyle(color: widget.cs.onSurfaceVariant, fontSize: 13))],
                ],
              ),
            ),
            if (user.id != currentUser.id)
              FollowButton(
                key: _followButtonState,
                onChanged: (_) async {
                  bool followed = await userRepository.toggleFollowUser(currentUser.id, user.id);
                  setState(() {
                    user = user.copyWith(followersCount: user.followersCount + (followed ? 1 : -1));
                  });
                  return followed;
                },
                initialSubscribed: localSeenService.isFollowing(user.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 52, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
        ],
      ),
    );
  }
}

class _SmoothScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar, {required this.cs});

  final TabBar tabBar;
  final ColorScheme cs;

  @override
  double get minExtent => tabBar.preferredSize.height + 1;

  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: cs.surface,
      child: Column(
        children: [
          tabBar,
          Divider(height: 1, thickness: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => tabBar != oldDelegate.tabBar;
}