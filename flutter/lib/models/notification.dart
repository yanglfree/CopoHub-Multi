class NotificationSubject {
  final String title;
  final String? url;
  final String? latestCommentUrl;
  final String type;

  const NotificationSubject({
    this.title = '',
    this.url,
    this.latestCommentUrl,
    this.type = '',
  });

  factory NotificationSubject.fromJson(Map<String, dynamic> json) =>
      NotificationSubject(
        title: json['title'] as String? ?? '',
        url: json['url'] as String?,
        latestCommentUrl: json['latest_comment_url'] as String?,
        type: json['type'] as String? ?? '',
      );
}

class NotificationRepository {
  final int id;
  final String name;
  final String fullName;
  final String htmlUrl;
  final String description;
  final bool private;
  final String ownerLogin;
  final String ownerAvatarUrl;

  const NotificationRepository({
    this.id = 0,
    this.name = '',
    this.fullName = '',
    this.htmlUrl = '',
    this.description = '',
    this.private = false,
    this.ownerLogin = '',
    this.ownerAvatarUrl = '',
  });

  factory NotificationRepository.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'] as Map<String, dynamic>?;
    return NotificationRepository(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      description: json['description'] as String? ?? '',
      private: json['private'] as bool? ?? false,
      ownerLogin: owner?['login'] as String? ?? '',
      ownerAvatarUrl: owner?['avatar_url'] as String? ?? '',
    );
  }
}

class GithubNotification {
  final String id;
  final bool unread;
  final String reason;
  final String updatedAt;
  final String? lastReadAt;
  final NotificationSubject subject;
  final NotificationRepository? repository;

  const GithubNotification({
    required this.id,
    this.unread = true,
    this.reason = '',
    this.updatedAt = '',
    this.lastReadAt,
    this.subject = const NotificationSubject(),
    this.repository,
  });

  factory GithubNotification.fromJson(Map<String, dynamic> json) {
    final subjectMap = json['subject'] as Map<String, dynamic>?;
    final repoMap = json['repository'] as Map<String, dynamic>?;
    return GithubNotification(
      id: json['id'] as String? ?? '',
      unread: json['unread'] as bool? ?? true,
      reason: json['reason'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      lastReadAt: json['last_read_at'] as String?,
      subject: subjectMap != null
          ? NotificationSubject.fromJson(subjectMap)
          : const NotificationSubject(),
      repository:
          repoMap != null ? NotificationRepository.fromJson(repoMap) : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is GithubNotification && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
