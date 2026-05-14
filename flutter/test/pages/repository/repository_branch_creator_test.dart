import 'package:flutter_test/flutter_test.dart';

import 'package:copohub/api/api_response.dart';
import 'package:copohub/pages/repository/repository_branch_creator.dart';

void main() {
  group('RepositoryBranchCreator', () {
    test('fails without calling API when source branch has no commit SHA',
        () async {
      var didCallApi = false;
      final creator = RepositoryBranchCreator(
        createBranch: ({
          required owner,
          required repo,
          required newBranchName,
          required baseSha,
        }) async {
          didCallApi = true;
          return ApiResponse.ok(null);
        },
      );

      final result = await creator.create(
        owner: 'onevcat',
        repo: 'CopoHub',
        newBranchName: 'feature',
        sourceRef: 'main',
        branches: const [],
        fallbackErrorMessage: 'failed',
      );

      expect(didCallApi, isFalse);
      expect(result.isSuccess, isFalse);
      expect(result.message, 'failed');
    });

    test('creates branch from source branch commit SHA', () async {
      late String capturedOwner;
      late String capturedRepo;
      late String capturedNewBranchName;
      late String capturedBaseSha;

      final creator = RepositoryBranchCreator(
        createBranch: ({
          required owner,
          required repo,
          required newBranchName,
          required baseSha,
        }) async {
          capturedOwner = owner;
          capturedRepo = repo;
          capturedNewBranchName = newBranchName;
          capturedBaseSha = baseSha;
          return ApiResponse.ok(null);
        },
      );

      final result = await creator.create(
        owner: 'onevcat',
        repo: 'CopoHub',
        newBranchName: 'feature',
        sourceRef: 'main',
        branches: const [
          {
            'name': 'main',
            'commit': {'sha': 'abc123'},
          },
        ],
        fallbackErrorMessage: 'failed',
      );

      expect(result.isSuccess, isTrue);
      expect(result.baseSha, 'abc123');
      expect(capturedOwner, 'onevcat');
      expect(capturedRepo, 'CopoHub');
      expect(capturedNewBranchName, 'feature');
      expect(capturedBaseSha, 'abc123');
    });

    test('uses API failure message when create request fails', () async {
      final creator = RepositoryBranchCreator(
        createBranch: ({
          required owner,
          required repo,
          required newBranchName,
          required baseSha,
        }) async {
          return const ApiResponse<void>(
            success: false,
            message: 'already exists',
          );
        },
      );

      final result = await creator.create(
        owner: 'onevcat',
        repo: 'CopoHub',
        newBranchName: 'main',
        sourceRef: 'main',
        branches: const [
          {
            'name': 'main',
            'commit': {'sha': 'abc123'},
          },
        ],
        fallbackErrorMessage: 'failed',
      );

      expect(result.isSuccess, isFalse);
      expect(result.baseSha, 'abc123');
      expect(result.message, 'already exists');
    });
  });
}
