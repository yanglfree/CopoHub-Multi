class DeduplicatedRepoItem {
  final int repoId;
  final String owner;
  final String name;
  final String description;
  final String url;
  final String language;
  final int stars;
  final int forks;
  final String coverImage;
  final DateTime lastSeenDate;
  final int totalOccurrences;

  const DeduplicatedRepoItem({
    required this.repoId,
    required this.owner,
    required this.name,
    this.description = '',
    this.url = '',
    this.language = '',
    this.stars = 0,
    this.forks = 0,
    this.coverImage = '',
    required this.lastSeenDate,
    required this.totalOccurrences,
  });

  factory DeduplicatedRepoItem.fromJson(Map<String, dynamic> json) {
    return DeduplicatedRepoItem(
      repoId: json['repo_id'] as int? ?? 0,
      owner: json['owner'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      url: json['url'] as String? ?? '',
      language: json['language'] as String? ?? '',
      stars: json['stars'] as int? ?? 0,
      forks: json['forks'] as int? ?? 0,
      coverImage: json['cover_image'] as String? ?? '',
      lastSeenDate: DateTime.tryParse(
              json['last_seen_date'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      totalOccurrences: json['total_occurrences'] as int? ?? 0,
    );
  }

  String get fullName => '$owner/$name';
}
