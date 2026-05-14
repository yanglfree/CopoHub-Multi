class RepositoryPagedList<T> {
  const RepositoryPagedList({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.isLoading,
    required this.error,
    required this.isRefreshing,
  });

  const RepositoryPagedList.initial()
      : items = const [],
        page = 1,
        hasMore = true,
        isLoading = false,
        error = '',
        isRefreshing = false;

  final List<T> items;
  final int page;
  final bool hasMore;
  final bool isLoading;
  final String error;
  final bool isRefreshing;

  RepositoryPagedList<T> startLoading({bool refresh = false}) {
    return RepositoryPagedList<T>(
      items: items,
      page: refresh ? 1 : page,
      hasMore: refresh ? true : hasMore,
      isLoading: true,
      error: '',
      isRefreshing: refresh,
    );
  }

  RepositoryPagedList<T> complete({
    required List<T> items,
    required int pageSize,
    int? rawItemCount,
  }) {
    final nextItems = isRefreshing ? items : [...this.items, ...items];
    final loadedCount = rawItemCount ?? items.length;
    return RepositoryPagedList<T>(
      items: nextItems,
      page: page + 1,
      hasMore: loadedCount >= pageSize,
      isLoading: false,
      error: '',
      isRefreshing: false,
    );
  }

  RepositoryPagedList<T> fail(String error) {
    return RepositoryPagedList<T>(
      items: items,
      page: page,
      hasMore: hasMore,
      isLoading: false,
      error: error,
      isRefreshing: false,
    );
  }

  RepositoryPagedList<T> reset() => RepositoryPagedList<T>.initial();
}
