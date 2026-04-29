class CopoHubCuratedItem {
  final String id;
  final int rank;
  final String owner;
  final String repo;
  final String description;
  final int stars;
  final int forks;
  final String language;
  final bool isPromoted;
  final String curatorNote;
  final String aiSummary;
  final String curatedAt;

  const CopoHubCuratedItem({
    required this.id,
    required this.rank,
    required this.owner,
    required this.repo,
    this.description = '',
    this.stars = 0,
    this.forks = 0,
    this.language = '',
    this.isPromoted = false,
    this.curatorNote = '',
    this.aiSummary = '',
    this.curatedAt = '',
  });

  /// Parse from the /api/v1/featured response (algorithm_picks or manual_picks)
  factory CopoHubCuratedItem.fromFeaturedJson(Map<String, dynamic> json) {
    final repository = json['repository'] as Map<String, dynamic>?;
    final promotionType = json['promotion_type'] as String? ?? 'free';

    return CopoHubCuratedItem(
      id: json['id']?.toString() ?? '',
      rank: json['display_order'] as int? ?? 0,
      owner: json['repo_owner'] as String? ?? '',
      repo: json['repo_name'] as String? ?? '',
      description: repository?['description'] as String? ?? '',
      stars: repository?['stars'] as int? ?? 0,
      forks: repository?['forks'] as int? ?? 0,
      language: repository?['language'] as String? ?? '',
      isPromoted: promotionType == 'paid',
      curatorNote: json['reason'] as String? ?? '',
      aiSummary: '',
      curatedAt: json['created_at'] as String? ?? '',
    );
  }

  String get fullName => '$owner/$repo';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CopoHubCuratedItem && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
