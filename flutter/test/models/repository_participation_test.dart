import 'package:copohub/models/repository_participation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses weekly repository participation values', () {
    final data = RepositoryParticipation.fromJson({
      'all': [0, 2, 5],
      'owner': [0, 1, 3],
    });

    expect(data.allCommits, [0, 2, 5]);
    expect(data.ownerCommits, [0, 1, 3]);
    expect(data.hasActivity, isTrue);
    expect(data.preferredSeries, [0, 2, 5]);
  });

  test('ignores malformed participation entries', () {
    final data = RepositoryParticipation.fromJson({
      'all': [0, 'bad', 4],
      'owner': null,
    });

    expect(data.allCommits, [0, 4]);
    expect(data.ownerCommits, isEmpty);
    expect(data.hasActivity, isTrue);
    expect(data.preferredSeries, [0, 4]);
  });

  test('reports no activity when both series are empty or zero', () {
    final data = RepositoryParticipation.fromJson({
      'all': [0, 0],
      'owner': [0],
    });

    expect(data.hasActivity, isFalse);
    expect(data.preferredSeries, [0, 0]);
  });
}
