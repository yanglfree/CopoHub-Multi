import 'package:copohub/api/api_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiCache', () {
    test('formats cache byte sizes for settings display', () {
      expect(ApiCache.formatByteSize(0), '0 B');
      expect(ApiCache.formatByteSize(512), '512 B');
      expect(ApiCache.formatByteSize(1536), '1.50 KB');
      expect(ApiCache.formatByteSize(2 * 1024 * 1024), '2.00 MB');
    });
  });
}
