class GithubUserStatus {
  final String emoji;
  final String message;
  final bool indicatesLimitedAvailability;
  final String expiresAt;
  final String updatedAt;
  final String organizationLogin;

  const GithubUserStatus({
    this.emoji = '',
    this.message = '',
    this.indicatesLimitedAvailability = false,
    this.expiresAt = '',
    this.updatedAt = '',
    this.organizationLogin = '',
  });

  bool get isEmpty => emoji.isEmpty && message.isEmpty;
  bool get isNotEmpty => !isEmpty;

  factory GithubUserStatus.fromJson(Map<String, dynamic> json) {
    final organization = json['organization'] as Map<String, dynamic>?;
    return GithubUserStatus(
      emoji: json['emoji'] as String? ?? '',
      message: json['message'] as String? ?? '',
      indicatesLimitedAvailability:
          json['indicatesLimitedAvailability'] as bool? ?? false,
      expiresAt: json['expiresAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      organizationLogin: organization?['login'] as String? ?? '',
    );
  }
}
