class RepoOwner {
  final String login;
  final int id;
  final String avatarUrl;
  final String type;

  const RepoOwner({
    required this.login,
    required this.id,
    required this.avatarUrl,
    this.type = 'User',
  });

  factory RepoOwner.fromJson(Map<String, dynamic> json) => RepoOwner(
        login: json['login'] as String? ?? '',
        id: json['id'] as int? ?? 0,
        avatarUrl: json['avatar_url'] as String? ?? '',
        type: json['type'] as String? ?? 'User',
      );

  Map<String, dynamic> toJson() => {
        'login': login,
        'id': id,
        'avatar_url': avatarUrl,
        'type': type,
      };
}

class RepoLicense {
  final String key;
  final String name;
  final String spdxId;
  final String url;

  const RepoLicense({
    required this.key,
    required this.name,
    this.spdxId = '',
    this.url = '',
  });

  factory RepoLicense.fromJson(Map<String, dynamic> json) => RepoLicense(
        key: json['key'] as String? ?? '',
        name: json['name'] as String? ?? '',
        spdxId: json['spdx_id'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'spdx_id': spdxId,
        'url': url,
      };
}

class RepoPermissions {
  final bool admin;
  final bool push;
  final bool pull;

  const RepoPermissions(
      {this.admin = false, this.push = false, this.pull = false});

  factory RepoPermissions.fromJson(Map<String, dynamic> json) =>
      RepoPermissions(
        admin: json['admin'] as bool? ?? false,
        push: json['push'] as bool? ?? false,
        pull: json['pull'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'admin': admin,
        'push': push,
        'pull': pull,
      };
}

class Repository {
  final int id;
  final String nodeId;
  final String name;
  final String fullName;
  final bool private;
  final RepoOwner? owner;
  final String htmlUrl;
  final String description;
  final bool fork;
  final String url;
  final String cloneUrl;
  final String sshUrl;
  final String homepage;
  final String language;
  final int stargazersCount;
  final int watchersCount;
  final int forksCount;
  final int openIssuesCount;
  final int size;
  final bool archived;
  final bool disabled;
  final bool hasIssues;
  final bool hasProjects;
  final bool hasWiki;
  final bool hasPages;
  final bool hasDiscussions;
  final bool allowForking;
  final bool isTemplate;
  final List<String> topics;
  final String visibility;
  final String defaultBranch;
  final String createdAt;
  final String updatedAt;
  final String pushedAt;
  final RepoLicense? license;
  final RepoPermissions? permissions;
  final Repository? parent; // source repo when forked

  const Repository({
    required this.id,
    this.nodeId = '',
    required this.name,
    required this.fullName,
    this.private = false,
    this.owner,
    this.htmlUrl = '',
    this.description = '',
    this.fork = false,
    this.url = '',
    this.cloneUrl = '',
    this.sshUrl = '',
    this.homepage = '',
    this.language = '',
    this.stargazersCount = 0,
    this.watchersCount = 0,
    this.forksCount = 0,
    this.openIssuesCount = 0,
    this.size = 0,
    this.archived = false,
    this.disabled = false,
    this.hasIssues = false,
    this.hasProjects = false,
    this.hasWiki = false,
    this.hasPages = false,
    this.hasDiscussions = false,
    this.allowForking = false,
    this.isTemplate = false,
    this.topics = const [],
    this.visibility = '',
    this.defaultBranch = 'main',
    this.createdAt = '',
    this.updatedAt = '',
    this.pushedAt = '',
    this.license,
    this.permissions,
    this.parent,
  });

  factory Repository.fromJson(Map<String, dynamic> json) {
    final ownerJson = json['owner'] as Map<String, dynamic>?;
    final licenseJson = json['license'] as Map<String, dynamic>?;
    final permissionsJson = json['permissions'] as Map<String, dynamic>?;
    final parentJson = json['parent'] as Map<String, dynamic>?;
    final topicsList = json['topics'] as List<dynamic>?;

    return Repository(
      id: json['id'] as int? ?? 0,
      nodeId: json['node_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      private: json['private'] as bool? ?? false,
      owner: ownerJson != null ? RepoOwner.fromJson(ownerJson) : null,
      htmlUrl: json['html_url'] as String? ?? '',
      description: json['description'] as String? ?? '',
      fork: json['fork'] as bool? ?? false,
      url: json['url'] as String? ?? '',
      cloneUrl: json['clone_url'] as String? ?? '',
      sshUrl: json['ssh_url'] as String? ?? '',
      homepage: json['homepage'] as String? ?? '',
      language: json['language'] as String? ?? '',
      stargazersCount: json['stargazers_count'] as int? ?? 0,
      watchersCount: json['watchers_count'] as int? ?? 0,
      forksCount: json['forks_count'] as int? ?? 0,
      openIssuesCount: json['open_issues_count'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      archived: json['archived'] as bool? ?? false,
      disabled: json['disabled'] as bool? ?? false,
      hasIssues: json['has_issues'] as bool? ?? false,
      hasProjects: json['has_projects'] as bool? ?? false,
      hasWiki: json['has_wiki'] as bool? ?? false,
      hasPages: json['has_pages'] as bool? ?? false,
      hasDiscussions: json['has_discussions'] as bool? ?? false,
      allowForking: json['allow_forking'] as bool? ?? false,
      isTemplate: json['is_template'] as bool? ?? false,
      topics:
          topicsList?.map((e) => e as String).toList() ?? const [],
      visibility: json['visibility'] as String? ?? '',
      defaultBranch: json['default_branch'] as String? ?? 'main',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      pushedAt: json['pushed_at'] as String? ?? '',
      license: licenseJson != null ? RepoLicense.fromJson(licenseJson) : null,
      permissions: permissionsJson != null
          ? RepoPermissions.fromJson(permissionsJson)
          : null,
      parent: parentJson != null ? Repository.fromJson(parentJson) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'node_id': nodeId,
        'name': name,
        'full_name': fullName,
        'private': private,
        'owner': owner?.toJson(),
        'html_url': htmlUrl,
        'description': description,
        'fork': fork,
        'url': url,
        'clone_url': cloneUrl,
        'ssh_url': sshUrl,
        'homepage': homepage,
        'language': language,
        'stargazers_count': stargazersCount,
        'watchers_count': watchersCount,
        'forks_count': forksCount,
        'open_issues_count': openIssuesCount,
        'size': size,
        'archived': archived,
        'disabled': disabled,
        'has_issues': hasIssues,
        'has_projects': hasProjects,
        'has_wiki': hasWiki,
        'has_pages': hasPages,
        'has_discussions': hasDiscussions,
        'allow_forking': allowForking,
        'is_template': isTemplate,
        'topics': topics,
        'visibility': visibility,
        'default_branch': defaultBranch,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'pushed_at': pushedAt,
        'license': license?.toJson(),
        'permissions': permissions?.toJson(),
        'parent': parent?.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Repository && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
