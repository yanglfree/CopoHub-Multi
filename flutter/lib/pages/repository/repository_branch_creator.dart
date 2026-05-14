import '../../api/api_response.dart';
import 'repository_refs.dart';

typedef CreateRepositoryBranch = Future<ApiResponse<void>> Function({
  required String owner,
  required String repo,
  required String newBranchName,
  required String baseSha,
});

class RepositoryBranchCreationResult {
  const RepositoryBranchCreationResult._({
    required this.isSuccess,
    required this.message,
    this.baseSha,
  });

  factory RepositoryBranchCreationResult.success({required String baseSha}) =>
      RepositoryBranchCreationResult._(
        isSuccess: true,
        message: '',
        baseSha: baseSha,
      );

  factory RepositoryBranchCreationResult.failure({
    required String message,
    String? baseSha,
  }) =>
      RepositoryBranchCreationResult._(
        isSuccess: false,
        message: message,
        baseSha: baseSha,
      );

  final bool isSuccess;
  final String message;
  final String? baseSha;
}

class RepositoryBranchCreator {
  const RepositoryBranchCreator({
    required CreateRepositoryBranch createBranch,
  }) : _createBranch = createBranch;

  final CreateRepositoryBranch _createBranch;

  Future<RepositoryBranchCreationResult> create({
    required String owner,
    required String repo,
    required String newBranchName,
    required String sourceRef,
    required List<Map<String, dynamic>> branches,
    required String fallbackErrorMessage,
  }) async {
    final baseSha = RepositoryRefs.commitShaFor(branches, sourceRef);
    if (baseSha == null) {
      return RepositoryBranchCreationResult.failure(
        message: fallbackErrorMessage,
      );
    }

    final response = await _createBranch(
      owner: owner,
      repo: repo,
      newBranchName: newBranchName,
      baseSha: baseSha,
    );

    if (response.success) {
      return RepositoryBranchCreationResult.success(baseSha: baseSha);
    }

    return RepositoryBranchCreationResult.failure(
      message: response.message ?? fallbackErrorMessage,
      baseSha: baseSha,
    );
  }
}
