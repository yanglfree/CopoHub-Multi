class TrendingItem {
  final int id;
  final int repoId;
  final String date;
  final String type; // daily | weekly | monthly
  final String language;
  final int rank;
  final int stars;
  final int forks;
  final int starsDelta;
  final int forksDelta;
  final String owner;
  final String name;
  final String description;
  final String url;
  final int rankDiff;
  final int starsDiff;

  const TrendingItem({
    required this.id,
    this.repoId = 0,
    required this.date,
    this.type = 'daily',
    this.language = '',
    required this.rank,
    this.stars = 0,
    this.forks = 0,
    this.starsDelta = 0,
    this.forksDelta = 0,
    required this.owner,
    required this.name,
    this.description = '',
    this.url = '',
    this.rankDiff = 0,
    this.starsDiff = 0,
  });

  factory TrendingItem.fromJson(Map<String, dynamic> json) => TrendingItem(
        id: json['id'] as int? ?? 0,
        repoId: json['repo_id'] as int? ?? 0,
        date: json['date'] as String? ?? '',
        type: json['type'] as String? ?? 'daily',
        language: json['language'] as String? ?? '',
        rank: json['rank'] as int? ?? 0,
        stars: json['stars'] as int? ?? 0,
        forks: json['forks'] as int? ?? 0,
        starsDelta: json['stars_delta'] as int? ?? 0,
        forksDelta: json['forks_delta'] as int? ?? 0,
        owner: json['owner'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        url: json['url'] as String? ?? '',
        rankDiff: json['rank_diff'] as int? ?? 0,
        starsDiff: json['stars_diff'] as int? ?? 0,
      );

  String get fullName => '$owner/$name';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is TrendingItem && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
