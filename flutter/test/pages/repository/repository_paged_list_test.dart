import 'package:copohub/pages/repository/repository_paged_list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RepositoryPagedList', () {
    test('starts loading the current page without clearing existing items', () {
      final state = const RepositoryPagedList<int>.initial()
          .complete(items: [1, 2], pageSize: 2);

      final loading = state.startLoading();

      expect(loading.items, [1, 2]);
      expect(loading.page, 2);
      expect(loading.isLoading, isTrue);
      expect(loading.error, isEmpty);
    });

    test('refresh starts from page one and replaces items on completion', () {
      final state = const RepositoryPagedList<int>.initial()
          .complete(items: [1, 2], pageSize: 2);

      final refreshed =
          state.startLoading(refresh: true).complete(items: [3], pageSize: 2);

      expect(refreshed.items, [3]);
      expect(refreshed.page, 2);
      expect(refreshed.hasMore, isFalse);
    });

    test('appends next page and advances page when page is full', () {
      final state = const RepositoryPagedList<int>.initial()
          .startLoading()
          .complete(items: [1, 2], pageSize: 2)
          .startLoading()
          .complete(items: [3, 4], pageSize: 2);

      expect(state.items, [1, 2, 3, 4]);
      expect(state.page, 3);
      expect(state.hasMore, isTrue);
      expect(state.isLoading, isFalse);
    });

    test('can use raw page length for hasMore after client-side filtering', () {
      final state = const RepositoryPagedList<int>.initial()
          .startLoading()
          .complete(items: [1], pageSize: 2, rawItemCount: 2);

      expect(state.items, [1]);
      expect(state.hasMore, isTrue);
    });

    test('reset clears items and failure keeps existing items visible', () {
      final state = const RepositoryPagedList<int>.initial()
          .complete(items: [1, 2], pageSize: 2)
          .startLoading()
          .fail('Network failed');

      expect(state.items, [1, 2]);
      expect(state.error, 'Network failed');
      expect(state.isLoading, isFalse);
      expect(state.reset().items, isEmpty);
      expect(state.reset().page, 1);
    });
  });
}
