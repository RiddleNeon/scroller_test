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
  final ScrollController _scrollController = ScrollController();

  bool _loading = false;
  bool _preloading = false;
  bool _preloadingGuard = false;
  int _currentLoadedCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _init();
  }

  Future<void> _init() async {
    if (widget.query.isCompleted) {
      setState(() => _currentLoadedCount = widget.query.results.length);
      return;
    }

    setState(() => _loading = true);
    await widget.query.complete();
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
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
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
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.query.results.length,
            itemBuilder: (context, index) {
              if (widget.query.results.isEmpty) return EmptyState(label: widget.emptyStateLabel ?? 'Nothing found', cs: cs);
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
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    return ScrollConfiguration(
      behavior: SmoothScrollBehavior(),
      child: ScrollArea(
        scrollController: _scrollController,
        child: Scrollbar(
          controller: _scrollController,
          interactive: true,
          thumbVisibility: true,
          child: CustomScrollView(controller: _scrollController, physics: const NeverScrollableScrollPhysics(), slivers: [_buildSliver(cs)]),
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
            return _preloading
                ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: LinearProgressIndicator(color: cs.primary, backgroundColor: cs.surfaceContainerHighest),
              ),
            )
                : const SizedBox.shrink();
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
  final Widget Function(BuildContext context, T item, Animation<double> animation, int index) itemBuilder;
  final String? emptyStateLabel;
  final Duration animationDuration;

  const AnimatedPreloadingList({
    super.key,
    required this.query,
    required this.itemBuilder,
    this.emptyStateLabel,
    this.animationDuration = const Duration(milliseconds: 350),
  });

  @override
  AnimatedPreloadingListState<T> createState() => AnimatedPreloadingListState<T>();
}

class AnimatedPreloadingListState<T> extends State<AnimatedPreloadingList<T>> with AutomaticKeepAliveClientMixin {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<T?> items = [];
  bool _loading = false;
  bool _preloading = false;
  bool _preloadingGuard = false;

  @override
  bool get wantKeepAlive => true;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _init();
  }

  void _onScroll() {
    if (!mounted || _preloading || widget.query.isCompleted) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      _preloadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (widget.query.results.isNotEmpty) {
      setState(() => items.addAll(widget.query.results));
      return;
    }

    setState(() => _loading = true);
    await widget.query.complete();
    if (mounted) {
      setState(() => _loading = false);
      _addItemsWithAnimation(widget.query.results);
    }
  }

  void _addItemsWithAnimation(List<T> newItems) {
    for (final item in newItems) {
      final int insertIndex = items.whereType<T>().length;
      items.add(item);
      _listKey.currentState?.insertItem(insertIndex, duration: widget.animationDuration);
    }
  }

  void removeItem(int index, Widget Function(BuildContext, Animation<double>) removedBuilder) {
    if (index < 0 || index >= items.length) return;
    
    items.removeAt(index);

    _listKey.currentState?.removeItem(
      index,
          (context, animation) => removedBuilder(context, animation),
      duration: widget.animationDuration,
    );
  }

  Future<void> _preloadMore() async {
    if (_preloadingGuard || widget.query.isCompleted) return;
    _preloadingGuard = true;
    setState(() => _preloading = true);

    final int oldLength = widget.query.results.length;
    await widget.query.preloadMore();

    if (mounted) {
      final newItems = widget.query.results.sublist(oldLength);
      _addItemsWithAnimation(newItems);
      Future.delayed(const Duration(milliseconds: 20), () {
        if (mounted) setState(() => _preloading = false);
      });
    }

    _preloadingGuard = false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    return ScrollConfiguration(
      behavior: SmoothScrollBehavior(),
      child: ScrollArea(
        scrollController: _scrollController,
        child: Scrollbar(
          controller: _scrollController,
          interactive: true,
          thumbVisibility: true,
          child: AnimatedList(
            key: _listKey,
            controller: _scrollController,
            initialItemCount: items.length,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index, animation) {
              final item = items[index];
              if (item == null) return const SizedBox.shrink();
              return widget.itemBuilder(context, item, animation, index);
            },
          ),
        ),
      ),
    );
  }
}