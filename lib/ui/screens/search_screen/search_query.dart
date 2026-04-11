class SearchQuery<T> {
  Future<List<T>> Function(int limit, int offset) executeQuery;
  Future<int> Function() countQuery;

  List<T> results = [];
  int totalResults = 0;
  int _offset = 0;
  bool _hasMoreContent = true;
  bool _didLoadTotalCount = false;

  bool get isCompleted => currentLoadingTask == null;

  SearchQuery(this.executeQuery, this.countQuery);

  Future<void>? currentLoadingTask;

  Future<void> preloadMore({int limit = 20}) async {
    if (currentLoadingTask != null) {
      return currentLoadingTask;
    }
    if (!_hasMoreContent) {
      return Future.value();
    }
    currentLoadingTask = _preloadMore(limit: limit).whenComplete(() {
      currentLoadingTask = null;
    });
    return currentLoadingTask;
  }

  Future<void> _preloadMore({int limit = 20}) async {
    final queryResult = await executeQuery(limit, _offset);
    results.addAll(queryResult);
    _offset += queryResult.length;
    _hasMoreContent = queryResult.length == limit;

    if (!_didLoadTotalCount) {
      totalResults = await countQuery();
      _didLoadTotalCount = true;
    }
  }
}
