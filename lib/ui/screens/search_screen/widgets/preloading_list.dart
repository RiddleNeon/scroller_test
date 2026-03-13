import 'package:flutter/material.dart';
import 'package:wurp/ui/screens/search_screen/search_query.dart';
import 'package:wurp/ui/screens/search_screen/widgets/empty_search_state.dart';
import 'package:wurp/ui/screens/search_screen/widgets/scroll_area.dart';
import 'package:wurp/ui/screens/search_screen/widgets/search_video_card.dart';


class PreloadingList<T> extends StatefulWidget {
  final SearchQuery<T> query;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String? emptyStateLabel;

  const PreloadingList({super.key, required this.query, required this.itemBuilder, this.emptyStateLabel});

  @override
  State<PreloadingList> createState() => _PreloadingListState();
}

class _PreloadingListState extends State<PreloadingList> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  bool _loading = false;
  bool _preloading = false;
  int _currentLoadedCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!mounted) return;

    final current = _scrollController.position.pixels;

    if (!_loading && !_preloading) {
      if (current >= _scrollController.position.maxScrollExtent - 300) {
        _preloadMore();
      }
    }
  }

  bool _preloadingGuard = false;

  Future<void> _preloadMore() async {
    if (_preloadingGuard) return;
    _preloadingGuard = true;
    setState(() => _preloading = true);

    await widget.query.preloadMore();
    if (mounted) {
      setState(() {
        _preloading = false;
        _currentLoadedCount = widget.query.results.length;
      });
    }

    _preloadingGuard = false;
  }

  @override
  void dispose() {
    disposeThumbnailCache();
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> init() async {
    if (widget.query.content.trim().isEmpty) return;
    setState(() => _loading = true);

    await widget.query.complete();
    _currentLoadedCount = widget.query.totalResults;

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(backgroundColor: cs.surface, body: _buildResultsBody(cs));
  }

  Widget _buildResultsBody(ColorScheme cs) {
    return ScrollConfiguration(
      behavior: SmoothScrollBehavior(),
      child: _loading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : ScrollArea(
              scrollController: _scrollController,
              child: Scrollbar(
                controller: _scrollController,
                interactive: true,
                thumbVisibility: true,
                child: CustomScrollView(controller: _scrollController, physics: const NeverScrollableScrollPhysics(), slivers: [_buildContentSliver(cs)]),
              ),
            ),
    );
  }

  Widget _buildContentSliver(ColorScheme cs) {
    final videos = widget.query.results;
    if (videos.isEmpty) {
      return SliverFillRemaining(
        child: EmptyState(label: widget.emptyStateLabel ?? 'Nothing found', cs: cs),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == _currentLoadedCount) {
            return _preloading
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: LinearProgressIndicator(color: cs.primary, backgroundColor: cs.surfaceContainerHighest),
                    ),
                  )
                : const SizedBox.shrink();
          }
          return widget.itemBuilder(context, videos[index]);
        }, childCount: _currentLoadedCount + 1),
      ),
    );
  }
}
