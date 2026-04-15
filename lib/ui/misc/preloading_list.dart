import 'package:flutter/material.dart';
import 'package:wurp/ui/screens/search_screen/search_query.dart';
import 'package:wurp/ui/screens/search_screen/widgets/empty_search_state.dart';
import 'package:wurp/ui/screens/search_screen/widgets/scroll_area.dart';

class PreloadingList<T> extends StatefulWidget {
  final SearchQuery<T> query;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String? emptyStateLabel;

  const PreloadingList({super.key, required this.query, required this.itemBuilder, this.emptyStateLabel});

  @override
  State<PreloadingList<T>> createState() => _PreloadingListState<T>();
}

class PreloadingSliverList<T> extends PreloadingList<T> {
  const PreloadingSliverList({super.key, required super.query, required super.itemBuilder, super.emptyStateLabel});

  @override
  State<PreloadingList<T>> createState() => _SliverPreloadingListState<T>();
}

class _PreloadingListState<T> extends State<PreloadingList<T>> {
  late ScrollController _scrollController;
  bool _ownsScrollController = false;

  bool _loading = false;
  bool _preloading = false;
  bool _preloadingGuard = false;
  int _currentLoadedCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Prefer the PrimaryScrollController (provided by NestedScrollView) so
    // the inner list scrolls are coordinated with the outer sliver app bar.
    // Use the PrimaryScrollController provided by the surrounding
    // NestedScrollView / Scaffold when available so scrolling is coordinated.
    _scrollController = PrimaryScrollController.of(context);
    _ownsScrollController = false;

    _scrollController.addListener(_onScroll);
    // initialize loading once we've got the correct controller/context
    _init();
  }

  Future<void> _init() async {
    if (widget.query.isCompleted) {
      setState(() => _currentLoadedCount = widget.query.results.length);
      return;
    }

    setState(() => _loading = true);
    await widget.query.preloadMore();
    if (mounted) {
      setState(() {
        _currentLoadedCount = widget.query.results.length;
        _loading = false;
      });
    }
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
    _scrollController.removeListener(_onScroll);
    if (_ownsScrollController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const SizedBox.shrink();
    }

    return ScrollConfiguration(
      behavior: SmoothScrollBehavior(),
      child: ScrollArea(
        scrollController: _scrollController,
        child: Scrollbar(
          controller: _scrollController,
          interactive: true,
          thumbVisibility: true,
          child: ListView.builder(
            controller: _scrollController,
            itemCount: widget.query.results.length,
            itemBuilder: (context, index) {
              if (widget.query.results.isEmpty) return EmptyState(label: widget.emptyStateLabel ?? 'Nothing found', cs: cs);
              if (index == _currentLoadedCount) {
                return const SizedBox.shrink();
              }
              if (index < widget.query.results.length) {
                return widget.itemBuilder(context, widget.query.results[index]);
              }
              return null;
            },
          ),
        ),
      ),
    );
  }
}

class _SliverPreloadingListState<T> extends _PreloadingListState<T> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const SizedBox.shrink();
    }

    return ScrollConfiguration(
      behavior: SmoothScrollBehavior(),
      child: ScrollArea(
        scrollController: _scrollController,
        child: Scrollbar(
          controller: _scrollController,
          interactive: true,
          thumbVisibility: true,
          child: CustomScrollView(controller: _scrollController, slivers: [_buildSliver(cs)]),
        ),
      ),
    );
  }

  Widget _buildSliver(ColorScheme cs) {
    final items = widget.query.results;
    if (items.isEmpty) {
      return SliverFillRemaining(
        child: EmptyState(label: widget.emptyStateLabel ?? 'Nothing found', cs: cs),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == _currentLoadedCount) {
            return const SizedBox.shrink();
          }
          return widget.itemBuilder(context, items[index]);
        }, childCount: _currentLoadedCount + 1),
      ),
    );
  }
}

typedef AnimatedItemBuilder<T> = Widget Function(BuildContext context, T item, Animation<double> animation, int index);

class AnimatedPreloadingList<T> extends StatefulWidget {
  final SearchQuery<T> query;
  final Widget Function(BuildContext context, T item, Animation<double> animation, int index, List<T?> allKnownValues) itemBuilder;
  final String? emptyStateLabel;
  final Duration animationDuration;
  final Widget? notFoundWidget;

  const AnimatedPreloadingList({
    super.key,
    required this.query,
    required this.itemBuilder,
    this.emptyStateLabel,
    this.animationDuration = const Duration(milliseconds: 350),
    this.notFoundWidget,
  });

  @override
  AnimatedPreloadingListState<T> createState() => AnimatedPreloadingListState<T>();
}

class AnimatedPreloadingListState<T> extends State<AnimatedPreloadingList<T>> with AutomaticKeepAliveClientMixin {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late ScrollController _scrollController;
  bool _ownsScrollController = false;

  final List<T> items = [];

  bool _loading = false;
  bool _preloading = false;
  bool _guard = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Use the PrimaryScrollController so inner scrolls coordinate with the
    // outer sliver app bar. We don't own this controller in typical cases.
    _scrollController = PrimaryScrollController.of(context);
    _ownsScrollController = false;

    _scrollController.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (_ownsScrollController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _loading = true);

    await widget.query.preloadMore();
    _syncItems(widget.query.results);

    setState(() => _loading = false);
  }

  void _syncItems(List<T> newItems) {
    final startIndex = items.length;

    for (int i = startIndex; i < newItems.length; i++) {
      items.add(newItems[i]);
      _listKey.currentState?.insertItem(i, duration: widget.animationDuration);
    }
  }

  Future<void> preloadMore({int limit = 20}) async {
    if (_guard) return;
    _guard = true;

    setState(() => _preloading = true);

    await widget.query.preloadMore(limit: limit);
    _syncItems(widget.query.results);

    setState(() => _preloading = false);
    _guard = false;
  }

  void _onScroll() {
    if (_loading || _preloading) return;

    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      preloadMore();
    }
  }

  @override
  bool get wantKeepAlive => true;

  void removeItem(int index, Widget Function(BuildContext, Animation<double>) removedBuilder) {
    if (index < 0 || index >= items.length) return;

    items.removeAt(index);

    _listKey.currentState?.removeItem(index, (context, animation) => removedBuilder(context, animation), duration: widget.animationDuration);
  }

  void addItem(T item) {
    setState(() {
      items.add(item);
      final int insertIndex = items.indexOf(item);
      _listKey.currentState?.insertItem(insertIndex, duration: widget.animationDuration);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const SizedBox.shrink();
    }

    if (items.isEmpty) {
      return widget.notFoundWidget ?? Center(child: Text(widget.emptyStateLabel ?? 'Nothing found'));
    }

    return AnimatedList(
      key: _listKey,
      controller: _scrollController,
      initialItemCount: items.length,
      itemBuilder: (context, index, animation) {
        if (index == items.length) {
          return const SizedBox.shrink();
        }

        return widget.itemBuilder(context, items[index], animation, index, items);
      },
    );
  }
}
