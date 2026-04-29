class UserActivitySummary {
  final int commitCount;
  final int repoCount;
  final int prCount;

  const UserActivitySummary({
    required this.commitCount,
    required this.repoCount,
    required this.prCount,
  });
}
