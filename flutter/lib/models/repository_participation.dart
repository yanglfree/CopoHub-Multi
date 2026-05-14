class RepositoryParticipation {
  const RepositoryParticipation({
    required this.allCommits,
    required this.ownerCommits,
  });

  static const empty = RepositoryParticipation(
    allCommits: [],
    ownerCommits: [],
  );

  final List<int> allCommits;
  final List<int> ownerCommits;

  factory RepositoryParticipation.fromJson(Map<String, dynamic> json) {
    return RepositoryParticipation(
      allCommits: _parseSeries(json['all']),
      ownerCommits: _parseSeries(json['owner']),
    );
  }

  List<int> get preferredSeries =>
      allCommits.isNotEmpty ? allCommits : ownerCommits;

  bool get hasActivity => preferredSeries.any((value) => value > 0);

  static List<int> _parseSeries(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<num>()
        .map((number) => number.toInt())
        .where((number) => number >= 0)
        .toList(growable: false);
  }
}
