class SearchQuery<T> {
  Future<List<T>> Function(int limit, int offset) executeQuery;
  Future<int> Function() countQuery;

  List<T> results = [];
  int totalResults = 0;
  int _offset = 0;
  bool _hasMoreContent = true;
  bool _isLoading = false;
  bool isCompleted = false;

  SearchQuery(this.executeQuery, this.countQuery);

  Future<void> complete({int limit = 20}) async {
    if (_isLoading) return;
    _isLoading = true;

    final queryResult = await executeQuery(limit, _offset);
    results = queryResult;
    _offset += queryResult.length;
    _hasMoreContent = queryResult.length == limit;

    totalResults = await countQuery();

    _isLoading = false;
    isCompleted = true;
  }

  Future<void> preloadMore({int limit = 20}) async {
    if (_isLoading || !_hasMoreContent) return;
    _isLoading = true;

    final queryResult = await executeQuery(limit, _offset);

    results.addAll(queryResult);
    _offset += queryResult.length;
    _hasMoreContent = queryResult.length == limit;

    _isLoading = false;
  }
}