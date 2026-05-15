enum PullRequestSearchScope {
  authored,
  reviewRequested,
  involved,
}

enum PullRequestSearchState {
  open,
  closed,
  all,
}

class PullRequestSearchQuery {
  const PullRequestSearchQuery({
    required this.scope,
    required this.state,
  });

  final PullRequestSearchScope scope;
  final PullRequestSearchState state;

  String get value {
    final qualifiers = <String>[
      'is:pr',
      'archived:false',
      if (state != PullRequestSearchState.all) 'state:${state.name}',
      switch (scope) {
        PullRequestSearchScope.authored => 'author:@me',
        PullRequestSearchScope.reviewRequested => 'user-review-requested:@me',
        PullRequestSearchScope.involved => 'involves:@me',
      },
    ];
    return qualifiers.join(' ');
  }
}

class PullRequestSearchResult {
  const PullRequestSearchResult({
    required this.totalCount,
    required this.incompleteResults,
    required this.items,
  });

  final int totalCount;
  final bool incompleteResults;
  final List<PullRequestSearchItem> items;

  factory PullRequestSearchResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return PullRequestSearchResult(
      totalCount: json['total_count'] as int? ?? 0,
      incompleteResults: json['incomplete_results'] as bool? ?? false,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(PullRequestSearchItem.fromJson)
          .toList(),
    );
  }
}

class PullRequestSearchItem {
  const PullRequestSearchItem({
    required this.id,
    required this.number,
    required this.title,
    required this.state,
    required this.htmlUrl,
    required this.repositoryUrl,
    required this.comments,
    required this.createdAt,
    required this.updatedAt,
    required this.labels,
    this.userLogin = '',
    this.userAvatarUrl = '',
  });

  final int id;
  final int number;
  final String title;
  final String state;
  final String htmlUrl;
  final String repositoryUrl;
  final int comments;
  final String createdAt;
  final String updatedAt;
  final List<Map<String, dynamic>> labels;
  final String userLogin;
  final String userAvatarUrl;

  bool get isOpen => state == 'open';

  String get owner => _repositoryParts.$1;
  String get repo => _repositoryParts.$2;

  String get routePath {
    if (owner.isEmpty || repo.isEmpty || number <= 0) return '';
    return '/pr/$owner/$repo/$number';
  }

  (String, String) get _repositoryParts {
    final fromApi = _parseRepositoryApiUrl(repositoryUrl);
    if (fromApi != null) return fromApi;

    final fromHtml = _parsePullRequestHtmlUrl(htmlUrl);
    if (fromHtml != null) return fromHtml;

    return ('', '');
  }

  factory PullRequestSearchItem.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final labels = json['labels'] as List<dynamic>? ?? const [];
    return PullRequestSearchItem(
      id: json['id'] as int? ?? 0,
      number: json['number'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      state: json['state'] as String? ?? 'open',
      htmlUrl: json['html_url'] as String? ?? '',
      repositoryUrl: json['repository_url'] as String? ?? '',
      comments: json['comments'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      labels: labels.whereType<Map<String, dynamic>>().toList(),
      userLogin: user?['login'] as String? ?? '',
      userAvatarUrl: user?['avatar_url'] as String? ?? '',
    );
  }

  static (String, String)? _parseRepositoryApiUrl(String url) {
    final uri = Uri.tryParse(url);
    final segments = uri?.pathSegments ?? const <String>[];
    final reposIndex = segments.indexOf('repos');
    if (reposIndex < 0 || segments.length <= reposIndex + 2) return null;
    return (segments[reposIndex + 1], segments[reposIndex + 2]);
  }

  static (String, String)? _parsePullRequestHtmlUrl(String url) {
    final uri = Uri.tryParse(url);
    final segments = uri?.pathSegments ?? const <String>[];
    if (segments.length < 4 || segments[2] != 'pull') return null;
    return (segments[0], segments[1]);
  }
}
