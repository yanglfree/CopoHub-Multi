class RepositoryRefs {
  const RepositoryRefs._();

  static String? commitShaFor(
    List<Map<String, dynamic>> branches,
    String branchName,
  ) {
    for (final branch in branches) {
      if (branch['name'] != branchName) continue;
      final commit = branch['commit'];
      if (commit is Map) {
        return commit['sha'] as String?;
      }
      return null;
    }
    return null;
  }

  static List<Map<String, dynamic>> withCreatedBranch(
    List<Map<String, dynamic>> branches, {
    required String name,
    required String sha,
  }) {
    return [
      {
        'name': name,
        'commit': {'sha': sha},
      },
      for (final branch in branches)
        if (branch['name'] != name) Map<String, dynamic>.from(branch),
    ];
  }
}
