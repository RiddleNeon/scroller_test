import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:wurp/logic/feed_recommendation/search_video_result_recommender.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/ui/feed_view_model.dart';
import 'package:wurp/ui/screens/search_screen/search_bar_result.dart';
import 'package:wurp/ui/screens/search_screen/widgets/animated_search_bar.dart';
import 'package:wurp/ui/screens/search_screen/widgets/empty_search_state.dart';
import 'package:wurp/ui/screens/search_screen/widgets/scroll_area.dart';
import 'package:wurp/ui/screens/search_screen/widgets/search_user_card.dart';
import 'package:wurp/ui/screens/search_screen/widgets/search_video_card.dart';
import 'package:wurp/ui/short_video_player.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
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
  static const _kSearchBarSlotHeight = _kSearchBarHeight + _kPadding * 2;

  double _lastScrollOffset = 0.0;
  double _searchBarVisibility = 1.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!mounted) return;

    final current = _scrollController.position.pixels;
    final delta = current - _lastScrollOffset;
    _lastScrollOffset = current;

    if (_searchBarResult != null && !_loading && !_preloading) {
      if (current >= _scrollController.position.maxScrollExtent - 300) {
        _preloadMore();
      }
    }

    double newVisibility = _searchBarVisibility;
    if (current <= 0) {
      newVisibility = 1.0;
    } else if (delta != 0) {
      newVisibility = (_searchBarVisibility - delta / _kSearchBarSlotHeight).clamp(0.0, 1.0);
    }

    if (newVisibility != _searchBarVisibility) {
      setState(() => _searchBarVisibility = newVisibility);
    }
  }

  bool _preloadingGuard = false;

  Future<void> _preloadMore() async {
    if (_preloadingGuard) return;
    _preloadingGuard = true;
    setState(() => _preloading = true);

    if (_tabController.index == 0) {
      await _searchBarResult!.preloadMoreVideos();
      if (mounted) {
        setState(() {
          _preloading = false;
          _videoCount = _searchBarResult!.videoResults.length;
        });
      }
    } else {
      await _searchBarResult!.preloadMoreUsers();
      if (mounted) {
        setState(() {
          _preloading = false;
          _userCount = _searchBarResult!.userResults.length;
        });
      }
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
      _searchBarVisibility = 1.0;
      _lastScrollOffset = 0.0;
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
      behavior: SmoothScrollBehavior(),
      child: Column(
        children: [
          AnimatedSearchBar(
            visibility: _searchBarVisibility,
            slotHeight: _kSearchBarSlotHeight,
            child: Padding(padding: const EdgeInsets.fromLTRB(_kPadding, _kPadding + 8, _kPadding, _kPadding), child: _buildSearchField(cs)),
          ),
          Container(
            color: cs.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                Divider(height: 1, thickness: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: cs.primary))
                : ScrollArea(
                    scrollController: _scrollController,
                    child: Scrollbar(
                      controller: _scrollController,
                      interactive: true,
                      thumbVisibility: true,
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: const NeverScrollableScrollPhysics(),
                        slivers: [if (_tabController.index == 0) _buildVideoSliver(cs) else _buildUserSliver(cs)],
                      ),
                    ),
                  ),
          ),
        ],
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
        child: EmptyState(label: 'No videos found', cs: cs),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == _videoCount) {
            return _preloading
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: LinearProgressIndicator(color: cs.primary, backgroundColor: cs.surfaceContainerHighest),
                    ),
                  )
                : const SizedBox.shrink();
          }
          return VideoCard(video: videos[index], thumbnail: _thumbnailFor(videos[index]), onTap: () => _openVideoPlayer(index), cs: cs);
        }, childCount: _videoCount + 1),
      ),
    );
  }

  Widget _buildUserSliver(ColorScheme cs) {
    final users = _searchBarResult?.userResults ?? [];
    if (users.isEmpty) {
      return SliverFillRemaining(
        child: EmptyState(label: 'No creators found', cs: cs),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == _userCount) {
            return _preloading
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: LinearProgressIndicator(color: cs.primary, backgroundColor: cs.surfaceContainerHighest),
                    ),
                  )
                : const SizedBox.shrink();
          }
          return UserCard(initialUser: users[index], cs: cs, key: ValueKey(users[index].id));
        }, childCount: _userCount + 1),
      ),
    );
  }

  final Map<String, Future<Uint8List?>> _cachedThumbnails = {};

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
