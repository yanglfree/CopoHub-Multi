class GithubUser {
  final String login;
  final int id;
  final String nodeId;
  final String avatarUrl;
  final String gravatarId;
  final String url;
  final String htmlUrl;
  final String type;
  final bool siteAdmin;
  final String name;
  final String company;
  final String blog;
  final String location;
  final String email;
  final String bio;
  final int publicRepos;
  final int publicGists;
  final int followers;
  final int following;
  final String createdAt;
  final String updatedAt;

  const GithubUser({
    required this.login,
    required this.id,
    this.nodeId = '',
    required this.avatarUrl,
    this.gravatarId = '',
    this.url = '',
    this.htmlUrl = '',
    this.type = 'User',
    this.siteAdmin = false,
    this.name = '',
    this.company = '',
    this.blog = '',
    this.location = '',
    this.email = '',
    this.bio = '',
    this.publicRepos = 0,
    this.publicGists = 0,
    this.followers = 0,
    this.following = 0,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory GithubUser.fromJson(Map<String, dynamic> json) {
    return GithubUser(
      login: json['login'] as String? ?? '',
      id: json['id'] as int? ?? 0,
      nodeId: json['node_id'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      gravatarId: json['gravatar_id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      type: json['type'] as String? ?? 'User',
      siteAdmin: json['site_admin'] as bool? ?? false,
      name: json['name'] as String? ?? '',
      company: json['company'] as String? ?? '',
      blog: json['blog'] as String? ?? '',
      location: json['location'] as String? ?? '',
      email: json['email'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      publicRepos: json['public_repos'] as int? ?? 0,
      publicGists: json['public_gists'] as int? ?? 0,
      followers: json['followers'] as int? ?? 0,
      following: json['following'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'login': login,
        'id': id,
        'node_id': nodeId,
        'avatar_url': avatarUrl,
        'gravatar_id': gravatarId,
        'url': url,
        'html_url': htmlUrl,
        'type': type,
        'site_admin': siteAdmin,
        'name': name,
        'company': company,
        'blog': blog,
        'location': location,
        'email': email,
        'bio': bio,
        'public_repos': publicRepos,
        'public_gists': publicGists,
        'followers': followers,
        'following': following,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  GithubUser copyWith({
    String? login,
    int? id,
    String? nodeId,
    String? avatarUrl,
    String? gravatarId,
    String? url,
    String? htmlUrl,
    String? type,
    bool? siteAdmin,
    String? name,
    String? company,
    String? blog,
    String? location,
    String? email,
    String? bio,
    int? publicRepos,
    int? publicGists,
    int? followers,
    int? following,
    String? createdAt,
    String? updatedAt,
  }) {
    return GithubUser(
      login: login ?? this.login,
      id: id ?? this.id,
      nodeId: nodeId ?? this.nodeId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      gravatarId: gravatarId ?? this.gravatarId,
      url: url ?? this.url,
      htmlUrl: htmlUrl ?? this.htmlUrl,
      type: type ?? this.type,
      siteAdmin: siteAdmin ?? this.siteAdmin,
      name: name ?? this.name,
      company: company ?? this.company,
      blog: blog ?? this.blog,
      location: location ?? this.location,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      publicRepos: publicRepos ?? this.publicRepos,
      publicGists: publicGists ?? this.publicGists,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is GithubUser && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
