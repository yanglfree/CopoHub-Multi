import 'package:copohub/api/api_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiResponse', () {
    test('can mark successful data as stale cache fallback', () {
      final response = ApiResponse.ok(
        ['cached-repo'],
        fromCache: true,
        cacheWarning: 'Refresh failed',
      );

      expect(response.isSuccess, isTrue);
      expect(response.data, ['cached-repo']);
      expect(response.fromCache, isTrue);
      expect(response.cacheWarning, 'Refresh failed');
    });
  });
}
