import 'package:copohub/pages/repository/repository_refs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RepositoryRefs', () {
    test('finds a branch commit SHA by name', () {
      final branches = [
        {
          'name': 'main',
          'commit': {'sha': 'abc123'},
        },
      ];

      expect(RepositoryRefs.commitShaFor(branches, 'main'), 'abc123');
      expect(RepositoryRefs.commitShaFor(branches, 'missing'), isNull);
    });

    test('returns a new branch list with the created branch first', () {
      final branches = [
        {
          'name': 'main',
          'commit': {'sha': 'abc123'},
        },
      ];

      final updated = RepositoryRefs.withCreatedBranch(
        branches,
        name: 'feature/readme',
        sha: 'def456',
      );

      expect(updated, isNot(same(branches)));
      expect(branches, hasLength(1));
      expect(updated.first['name'], 'feature/readme');
      expect((updated.first['commit'] as Map)['sha'], 'def456');
      expect(updated[1]['name'], 'main');
    });

    test('replaces an existing branch entry instead of duplicating it', () {
      final branches = [
        {
          'name': 'feature/readme',
          'commit': {'sha': 'old'},
        },
        {
          'name': 'main',
          'commit': {'sha': 'abc123'},
        },
      ];

      final updated = RepositoryRefs.withCreatedBranch(
        branches,
        name: 'feature/readme',
        sha: 'new',
      );

      expect(updated, hasLength(2));
      expect(updated.first['name'], 'feature/readme');
      expect((updated.first['commit'] as Map)['sha'], 'new');
    });
  });
}
