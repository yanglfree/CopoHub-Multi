class GithubOrg {
  final int id;
  final String login;
  final String avatarUrl;
  final String description;

  const GithubOrg({
    required this.id,
    required this.login,
    required this.avatarUrl,
    this.description = '',
  });

  factory GithubOrg.fromJson(Map<String, dynamic> json) => GithubOrg(
        id: json['id'] as int? ?? 0,
        login: json['login'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );
}
