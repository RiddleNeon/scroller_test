import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:wurp/logic/feed_recommendation/search_video_result_recommender.dart';
import 'package:wurp/logic/models/user_model.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/main.dart';
import 'package:wurp/ui/feed_view_model.dart';
import 'package:wurp/ui/screens/search_screen/search_bar_result.dart';
import 'package:wurp/ui/short_video_player.dart';

import '../../../logic/repositories/user_repository.dart';

class SearchScreen extends StatefulWidget {
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  SearchBarResult? _searchBarResult;

  bool _loading = false;
  bool _hasSearched = false;

  late TabController _tabController;

  static const _kSearchBarHeight = 56.0;
  static const _kPadding = 16.0;

  static const _bg = Color(0xFF0A0A0F);
  static const _surface = Color(0xFF16161E);
  static const _accent = Color(0xFFFF2D55);
  static const _accentSecondary = Color(0xFF00F2EA);
  static const _textPrimary = Color(0xFFF5F5F5);
  static const _textSecondary = Color(0xFF8A8A9A);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_searchBarResult == null || _loading) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      if (_tabController.index == 0) {
        _searchBarResult!.preloadMoreVideos();
      } else {
        _searchBarResult!.preloadMoreUsers();
      }
    }
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
    _searchBarResult = SearchBarResult.fromFirestore(val);
    await _searchBarResult!.complete();
    _currentSearchViewModel = FeedViewModel();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _darkTheme(),
      child: Scaffold(
        backgroundColor: _bg,
        body: _hasSearched ? _buildResultsBody() : _buildLandingBody(),
      ),
    );
  }

  Widget _buildLandingBody() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [_accent, _accentSecondary],
              ).createShader(bounds),
              child: const Text(
                'Discover',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Find videos & creators',
              style: TextStyle(color: _textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 40),
            _buildSearchField(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsBody() {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          backgroundColor: _bg,
          pinned: true,
          floating: true,
          snap: true,
          elevation: 0,
          expandedHeight: _kSearchBarHeight + _kPadding * 2,
          flexibleSpace: FlexibleSpaceBar(
            background: Padding(
              padding: const EdgeInsets.fromLTRB(_kPadding, _kPadding + 8, _kPadding, _kPadding),
              child: _buildSearchField(),
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(
            TabBar(
              controller: _tabController,
              onTap: (_) => setState(() {}),
              labelColor: _accent,
              unselectedLabelColor: _textSecondary,
              indicatorColor: _accent,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
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
            backgroundColor: _bg,
          ),
        ),
        if (_loading)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: _accent),
            ),
          )
        else ...[
          if (_tabController.index == 0) _buildVideoSliver() else _buildUserSliver(),
        ],
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: _kSearchBarHeight,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        onSubmitted: _search,
        style: const TextStyle(color: _textPrimary, fontSize: 16),
        cursorColor: _accent,
        decoration: InputDecoration(
          hintText: 'Search videos, creators, tags…',
          hintStyle: const TextStyle(color: _textSecondary, fontSize: 15),
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search_rounded, color: _textSecondary, size: 22),
          suffixIcon: GestureDetector(
            onTap: _search,
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_accent, Color(0xFFFF6B35)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
        ),
      ),
    );
  }

  Widget _buildVideoSliver() {
    final videos = _searchBarResult?.videoResults ?? [];
    if (videos.isEmpty) {
      return const SliverFillRemaining(child: _EmptyState(label: 'No videos found'));
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _VideoCard(
            video: videos[index],
            thumbnail: _thumbnailFor(videos[index]),
            onTap: () => _openVideoPlayer(index),
          ),
          childCount: videos.length,
        ),
      ),
    );
  }

  Widget _buildUserSliver() {
    final users = _searchBarResult?.userResults ?? [];
    if (users.isEmpty) {
      return const SliverFillRemaining(child: _EmptyState(label: 'No creators found'));
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _UserCard(user: users[index]),
          childCount: users.length,
        ),
      ),
    );
  }

  final Map<String, Future<Uint8List?>> _cachedThumbnails = {};

  Future<Uint8List?> _thumbnailFor(Video video) {
    _cachedThumbnails[video.videoUrl] ??= VideoThumbnail.thumbnailData(video: video.videoUrl);
    return _cachedThumbnails[video.videoUrl]!;
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
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                children: [
                  feedVideos(
                    this,
                    SearchVideoResultRecommender(
                      listedVideos: _searchBarResult!.videoResults,
                    ),
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
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
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
          child: ScaleTransition(
            scale: Tween(begin: 0.88, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  ThemeData _darkTheme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: _bg,
      colorScheme: const ColorScheme.dark(
        primary: _accent,
        secondary: _accentSecondary,
        surface: _surface,
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: _accent,
      ),
    );
  }
}


class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.video,
    required this.thumbnail,
    required this.onTap,
  });

  final Video video;
  final Future<Uint8List?> thumbnail;
  final VoidCallback onTap;

  static const _accent = Color(0xFFFF2D55);
  static const _surface = Color(0xFF16161E);
  static const _textPrimary = Color(0xFFF5F5F5);
  static const _textSecondary = Color(0xFF8A8A9A);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
              child: SizedBox(
                width: 140,
                height: 84,
                child: _buildThumbnail(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.play_arrow_rounded, color: _accent, size: 14),
                              SizedBox(width: 2),
                              Text('Watch', style: TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
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
    );
  }

  Widget _buildThumbnail() {
    if (!(defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      return _shimmer();
    }
    return FutureBuilder<Uint8List?>(
      future: thumbnail,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        }
        return _shimmer();
      },
    );
  }

  Widget _shimmer() => Shimmer(
        child: Container(color: const Color(0xFF1E1E28)),
      );
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final UserProfile user;

  static const _surface = Color(0xFF16161E);
  static const _accent = Color(0xFFFF2D55);
  static const _accentSecondary = Color(0xFF00F2EA);
  static const _textPrimary = Color(0xFFF5F5F5);
  static const _textSecondary = Color(0xFF8A8A9A);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_accent, _accentSecondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              radius: 26,
              backgroundColor: _surface,
              backgroundImage: (user.profileImageUrl.isNotEmpty) ? NetworkImage(user.profileImageUrl) : NetworkImage(createUserProfileImageUrl(user.username)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                ...[
                  const SizedBox(height: 2),
                  Text(
                    '@${user.username}',
                    style: const TextStyle(color: _textSecondary, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              userRepository.followUser(currentUser.id, user.id);
            },
            style: TextButton.styleFrom(
              backgroundColor: _accent.withValues(alpha: 0.12),
              foregroundColor: _accent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            child: const Text('Follow'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 52, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: Color(0xFF8A8A9A), fontSize: 15)),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar, {required this.backgroundColor});

  final TabBar tabBar;
  final Color backgroundColor;

  @override
  double get minExtent => tabBar.preferredSize.height + 1;

  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: Column(
        children: [
          tabBar,
          Divider(height: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.07)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => tabBar != oldDelegate.tabBar;
}
