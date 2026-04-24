import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wurp/base_logic.dart';
import 'package:wurp/logic/feed_recommendation/search_video_result_recommender.dart';
import 'package:wurp/logic/repositories/video_repository.dart';
import 'package:wurp/logic/users/user_model.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/ui/animations/slide_morph_transitions.dart';
import 'package:wurp/ui/deep_link_builder.dart';
import 'package:wurp/ui/feed_view_model.dart';
import 'package:wurp/ui/misc/preloading_list.dart';
import 'package:wurp/ui/screens/search_screen/search_query.dart';
import 'package:wurp/ui/screens/search_screen/widgets/animated_search_bar.dart';
import 'package:wurp/ui/screens/search_screen/widgets/search_user_card.dart';
import 'package:wurp/ui/screens/search_screen/widgets/search_video_card.dart';
import 'package:wurp/ui/short_video_player.dart';

import '../../theme/theme_ui_values.dart';

enum SearchScope { videos, profiles, all }

enum SearchMode { text, tags }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery, this.initialScope = SearchScope.all, this.initialMode = SearchMode.text});

  final String? initialQuery;
  final SearchScope initialScope;
  final SearchMode initialMode;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();

  late TabController _tabController;

  bool _hasSearched = false;
  bool _loading = false;

  SearchQuery<Video>? _videoQuery;
  SearchQuery<UserProfile>? _userQuery;

  FeedViewModel? _currentSearchViewModel;
  int _searchRequestId = 0;

  static const _kSearchBarHeight = 56.0;
  static const _kPadding = 16.0;
  static const _kSearchBarSlotHeight = _kSearchBarHeight + _kPadding * 2;

  double _searchBarVisibility = 1.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _applyDeepLinkState(triggerSearch: true);
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery == widget.initialQuery && oldWidget.initialScope == widget.initialScope && oldWidget.initialMode == widget.initialMode) {
      return;
    }
    _applyDeepLinkState(triggerSearch: true);
  }

  void _applyDeepLinkState({required bool triggerSearch}) {
    if (widget.initialScope == SearchScope.videos) {
      _tabController.index = 0;
    } else if (widget.initialScope == SearchScope.profiles) {
      _tabController.index = 1;
    }

    final initialQuery = widget.initialQuery?.trim();
    if (initialQuery == null || initialQuery.isEmpty) return;

    _controller.text = initialQuery;
    if (!triggerSearch) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _search(initialQuery);
    });
  }

  @override
  void dispose() {
    disposeThumbnailCache();
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search([String? val]) async {
    val ??= _controller.text;
    final trimmedQuery = val.trim();
    if (trimmedQuery.isEmpty) return;

    final scope = widget.initialScope == SearchScope.all
        ? DeepLinkSearchScope.all
        : (_tabController.index == 0 ? DeepLinkSearchScope.videos : DeepLinkSearchScope.profiles);

    final targetUrl = DeepLinkBuilder.search(
      query: trimmedQuery,
      scope: scope,
      mode: widget.initialMode == SearchMode.tags ? DeepLinkSearchMode.tags : DeepLinkSearchMode.text,
    );
    final currentUri = GoRouterState.of(context).uri.toString();
    if (currentUri != targetUrl) {
      context.replace(targetUrl);
    }

    final requestId = ++_searchRequestId;
    FocusScope.of(context).unfocus();

    setState(() {
      _hasSearched = true;
      _loading = true;
      _searchBarVisibility = 1.0;
    });

    SearchQuery<UserProfile>? nextUserQuery;
    SearchQuery<Video>? nextVideoQuery;

    if (widget.initialScope != SearchScope.profiles) {
      nextVideoQuery = SearchQuery<Video>((limit, offset) async {
        final videos = widget.initialMode == SearchMode.tags
            ? await videoRepo.searchVideosByTagSupabase(trimmedQuery, limit: limit, offset: offset)
            : (await videoRepo.searchVideos(trimmedQuery, limit: limit, offset: offset, withAuthor: true)).videos;
        return videos;
      }, () => videoRepo.countSearchVideos(trimmedQuery));
    }

    if (widget.initialScope != SearchScope.videos) {
      nextUserQuery = SearchQuery<UserProfile>((limit, offset) async {
        final result = await userRepository.searchUsers(trimmedQuery, limit: limit, offset: offset);
        return result.users;
      }, () => userRepository.countSearchUsers(trimmedQuery));
    }

    await Future.wait([if (nextVideoQuery != null) nextVideoQuery.preloadMore(), if (nextUserQuery != null) nextUserQuery.preloadMore()]);
    if (requestId != _searchRequestId) return;
    if (!mounted) return;

    setState(() {
      _videoQuery = nextVideoQuery;
      _userQuery = nextUserQuery;
      _currentSearchViewModel = FeedViewModel();
      _loading = false;
    });
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
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1, color: cs.secondary),
              ),
            ),
            const SizedBox(height: 8),
            Text('Find videos & creators', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
            const SizedBox(height: 256),
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
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(key: ValueKey('tab_${_tabController.index}'), child: _buildTabContent()),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(context.uiRadiusLg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SearchSegmentButton(
              selected: _tabController.index == 0,
              onTap: () => _tabController.animateTo(0),
              icon: Icons.play_circle_outline,
              label: _videoQuery?.totalResults != null ? 'Videos (${_videoQuery!.totalResults})' : 'Videos',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SearchSegmentButton(
              selected: _tabController.index == 1,
              onTap: () => _tabController.animateTo(1),
              icon: Icons.person_outline,
              label: _userQuery?.totalResults != null ? 'Creators (${_userQuery!.totalResults})' : 'Creators',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    if (_tabController.index == 0 && _videoQuery != null) {
      final query = _videoQuery!;
      return PreloadingSliverList<Video>(
        key: ValueKey(query),
        query: query,
        emptyStateLabel: 'No videos found',
        itemBuilder: (context, video) {
          final videos = List<Video>.unmodifiable(query.results);
          final index = videos.indexOf(video);
          if (index < 0) return const SizedBox.shrink();
          return VideoCard(
            video: video,
            cs: Theme.of(context).colorScheme,
            onTap: () async {
              await openVideoPlayer(context: context, listedVideos: videos, videoIndex: index, feedModel: _currentSearchViewModel, tickerProvider: this);
              Future.delayed(const Duration(milliseconds: 800), () async => await _currentSearchViewModel?.dispose());  
            },
          );
        },
      );
    }

    if (_tabController.index == 1 && _userQuery != null) {
      final query = _userQuery!;
      return PreloadingSliverList<UserProfile>(
        key: ValueKey(query),
        query: query,
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
        borderRadius: BorderRadius.circular(context.uiRadiusLg),
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
              decoration: BoxDecoration(color: cs.tertiaryContainer, borderRadius: BorderRadius.circular(context.uiRadiusMd)),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 180),
                scale: _loading ? 0.92 : 1,
                child: Icon(Icons.arrow_forward_rounded, color: cs.onTertiaryContainer, size: 20),
              ),
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
              borderRadius: BorderRadius.circular(context.uiRadiusLg),
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
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.inverseSurface.withValues(alpha: 0.85), shape: BoxShape.circle),
                      child: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.onInverseSurface, size: 20),
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
      return SlideMorphTransitions.build(animation, child, beginOffset: const Offset(0, 0.08), beginScale: 0.88);
    },
  );
  return likes;
}

class _SearchSegmentButton extends StatelessWidget {
  const _SearchSegmentButton({required this.selected, required this.onTap, required this.icon, required this.label});

  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.uiRadiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.uiRadiusMd),
          color: selected ? cs.secondaryContainer.withValues(alpha: 0.75) : Colors.transparent,
          border: selected ? Border.all(color: cs.outlineVariant.withValues(alpha: 0.65)) : null,
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13,
            color: selected ? cs.onSecondaryContainer : cs.onSurfaceVariant,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? cs.onSecondaryContainer : cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}
