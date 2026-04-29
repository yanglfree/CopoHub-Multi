class IssueLabel {
  final int id;
  final String name;
  final String color;
  final bool isDefault;
  final String description;

  const IssueLabel({
    this.id = 0,
    required this.name,
    this.color = '',
    this.isDefault = false,
    this.description = '',
  });

  factory IssueLabel.fromJson(Map<String, dynamic> json) => IssueLabel(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        color: json['color'] as String? ?? '',
        isDefault: json['default'] as bool? ?? false,
        description: json['description'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'default': isDefault,
        'description': description,
      };
}

class Issue {
  final int id;
  final String nodeId;
  final int number;
  final String title;
  final String body;
  final String htmlUrl;
  final String state;
  final bool locked;
  final bool draft;
  final int comments;
  final String createdAt;
  final String updatedAt;
  final String closedAt;
  final String authorAssociation;
  final String stateReason;
  final List<IssueLabel> labels;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? assignee;
  final Map<String, dynamic>? pullRequest;

  const Issue({
    this.id = 0,
    this.nodeId = '',
    required this.number,
    required this.title,
    this.body = '',
    this.htmlUrl = '',
    this.state = 'open',
    this.locked = false,
    this.draft = false,
    this.comments = 0,
    this.createdAt = '',
    this.updatedAt = '',
    this.closedAt = '',
    this.authorAssociation = '',
    this.stateReason = '',
    this.labels = const [],
    this.user,
    this.assignee,
    this.pullRequest,
  });

  bool get isPullRequest => pullRequest != null;
  bool get isOpen => state == 'open';

  factory Issue.fromJson(Map<String, dynamic> json) {
    final labelsList = json['labels'] as List<dynamic>?;
    return Issue(
      id: json['id'] as int? ?? 0,
      nodeId: json['node_id'] as String? ?? '',
      number: json['number'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      state: json['state'] as String? ?? 'open',
      locked: json['locked'] as bool? ?? false,
      draft: json['draft'] as bool? ?? false,
      comments: json['comments'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      closedAt: json['closed_at'] as String? ?? '',
      authorAssociation: json['author_association'] as String? ?? '',
      stateReason: json['state_reason'] as String? ?? '',
      labels: labelsList
              ?.map((e) => IssueLabel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      user: json['user'] as Map<String, dynamic>?,
      assignee: json['assignee'] as Map<String, dynamic>?,
      pullRequest: json['pull_request'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Issue && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
