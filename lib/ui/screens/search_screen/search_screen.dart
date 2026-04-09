import 'package:flutter/material.dart';
import 'package:wurp/base_logic.dart';
import 'package:wurp/logic/feed_recommendation/search_video_result_recommender.dart';
import 'package:wurp/logic/users/user_model.dart';
import 'package:wurp/logic/repositories/video_repository.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/ui/feed_view_model.dart';
import 'package:wurp/ui/screens/search_screen/search_query.dart';
import 'package:wurp/ui/screens/search_screen/widgets/animated_search_bar.dart';
import 'package:wurp/ui/screens/search_screen/widgets/preloading_list.dart';
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
  
  late TabController _tabController;
  
  bool _hasSearched = false;
  bool _loading = false;
  
  SearchQuery<Video>? _videoQuery;
  SearchQuery<UserProfile>? _userQuery;
  
  FeedViewModel? _currentSearchViewModel;
  
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

  @override
  void dispose() {
    disposeThumbnailCache();
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

    _userQuery = SearchQuery<UserProfile>((limit, offset) async {
      final result = await userRepository.searchUsers(val!, limit: limit, offset: offset);
      return result.users;
    }, () => userRepository.countSearchUsers(val!));

    _videoQuery = SearchQuery<Video>((limit, offset) async {
      final result = await videoRepo.searchVideos(val!, limit: limit, offset: offset, withAuthor: true);
      return result.videos;
    }, () => videoRepo.countSearchVideos(val!));

    await Future.wait([_videoQuery!.preloadMore(), _userQuery!.preloadMore()]);

    _currentSearchViewModel = FeedViewModel();

    if (mounted) setState(() => _loading = false);
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
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 560),
              tween: Tween(begin: 0.94, end: 1),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Text(
                'Discover',
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1, color: cs.primary),
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
    return Column(
      children: [
        AnimatedSearchBar(
          visibility: _searchBarVisibility,
          slotHeight: _kSearchBarSlotHeight,
          child: Padding(padding: const EdgeInsets.fromLTRB(_kPadding, _kPadding + 8, _kPadding, _kPadding), child: _buildSearchField(cs)),
        ),
        _buildTabBar(cs),
        Divider(height: 1, thickness: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
        Expanded(
          child: _loading ? Center(child: CircularProgressIndicator(color: cs.primary)) : _buildTabContent(),
        ),
      ],
    );
  }

  Widget _buildTabBar(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (_) => setState(() {}),
        labelColor: cs.primary,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: cs.surface,
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.5),
        tabs: [
          _buildTab(icon: Icons.play_circle_outline, label: 'Videos', count: _videoQuery?.totalResults),
          _buildTab(icon: Icons.person_outline, label: 'Creators', count: _userQuery?.totalResults),
        ],
      ),
    );
  }

  Tab _buildTab({required IconData icon, required String label, int? count}) {
    return Tab(
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18), const SizedBox(width: 6), Text(count != null ? '$label ($count)' : label)]),
    );
  }

  Widget _buildTabContent() {
    if (_tabController.index == 0 && _videoQuery != null) {
      return PreloadingSliverList<Video>(
        key: ValueKey('videos_${_videoQuery!.toString()}'),
        query: _videoQuery!,
        emptyStateLabel: 'No videos found',
        itemBuilder: (context, video) {
          final videos = _videoQuery!.results;
          final index = videos.indexOf(video);
          return VideoCard(
            video: video,
            cs: Theme.of(context).colorScheme,
            onTap: () => openVideoPlayer(context: context, listedVideos: videos, videoIndex: index, feedModel: _currentSearchViewModel, tickerProvider: this),
          );
        },
      );
    }

    if (_tabController.index == 1 && _userQuery != null) {
      return PreloadingSliverList<UserProfile>(
        key: ValueKey('users_${_userQuery!.toString()}'),
        query: _userQuery!,
        emptyStateLabel: 'No creators found',
        itemBuilder: (context, user) => UserCard(initialUser: user, cs: Theme.of(context).colorScheme, key: ValueKey(user.id)),
      );
    }

    return const SizedBox.shrink();
  }
  
  Widget _buildSearchField(ColorScheme cs) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      height: _kSearchBarHeight,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.9)),
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
                color: cs.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.arrow_forward_rounded, color: cs.onPrimary, size: 20),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
        ),
      ),
    );
  }
}

/// Returns the number of likes added (can be negative if user unliked videos)
Future<int> openVideoPlayer({
  required BuildContext context,
  required List<Video> listedVideos,
  required int videoIndex,
  required FeedViewModel? feedModel,
  required TickerProvider tickerProvider,
}) async {
  int likes = 0;
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'VideoOverlay',
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, _, _) => SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              children: [
                feedVideos(
                  tickerProvider,
                  SearchVideoResultRecommender(listedVideos: listedVideos),
                  context,
                  feedModel: feedModel,
                  itemCount: listedVideos.length,
                  initialPage: videoIndex,
                  onLikeChanged: (liked) => likes += liked ? 1 : -1,
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9), shape: BoxShape.circle),
                      child: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.onSurface, size: 20),
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
  return likes;
}
