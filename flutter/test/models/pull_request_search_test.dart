import 'package:copohub/models/pull_request_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PullRequestSearchQuery', () {
    test('builds current user authored pull request query', () {
      const query = PullRequestSearchQuery(
        scope: PullRequestSearchScope.authored,
        state: PullRequestSearchState.open,
      );

      expect(query.value, 'is:pr archived:false state:open author:@me');
    });

    test('omits state qualifier when listing all pull requests', () {
      const query = PullRequestSearchQuery(
        scope: PullRequestSearchScope.involved,
        state: PullRequestSearchState.all,
      );

      expect(query.value, 'is:pr archived:false involves:@me');
    });
  });

  group('PullRequestSearchItem', () {
    test('parses repository identity from GitHub URLs', () {
      final item = PullRequestSearchItem.fromJson({
        'id': 42,
        'number': 7,
        'title': 'Improve queue',
        'state': 'open',
        'html_url': 'https://github.com/onevcat/CopoHub/pull/7',
        'repository_url': 'https://api.github.com/repos/onevcat/CopoHub',
      });

      expect(item.owner, 'onevcat');
      expect(item.repo, 'CopoHub');
      expect(item.routePath, '/pr/onevcat/CopoHub/7');
    });
  });
}
