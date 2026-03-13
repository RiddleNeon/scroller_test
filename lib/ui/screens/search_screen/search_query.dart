class SearchQuery<T> {
  String content;
  
  Future<List<T>> Function(String query, {int limit, int offset, bool withAuthor}) executeQuery;
  Future<int> Function(String searchText) countQuery;
  
  List<T> results = [];
  int totalResults = 0;
  int _offset = 0;
  bool _hasMoreContent = true;
  bool _isLoading = false;

  SearchQuery(this.content, this.executeQuery, this.countQuery);

  Future<void> complete({int limit = 20}) async {
    if (_isLoading) return;
    _isLoading = true;

    final queryResult = await executeQuery(content, limit: 20, withAuthor: true, offset: _offset);
    results = queryResult;
    print("done, results: ${queryResult}");
    _offset += queryResult.length;
    _hasMoreContent = queryResult.length == limit;

    totalResults = await countQuery(content);

    _isLoading = false;
  }

  Future<void> preloadMore({int limit = 20}) async {
    if (_isLoading || !_hasMoreContent) return;
    _isLoading = true;

    final queryResult = await executeQuery(content, limit: 20, withAuthor: true, offset: _offset);

    results.addAll(queryResult);
    _offset += queryResult.length;
    _hasMoreContent = queryResult.length == limit;

    _isLoading = false;
  }
}