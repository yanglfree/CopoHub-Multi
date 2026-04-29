class Comment {
  final int id;
  final String nodeId;
  final String htmlUrl;
  final String body;
  final String authorAssociation;
  final String createdAt;
  final String updatedAt;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? reactions;

  const Comment({
    this.id = 0,
    this.nodeId = '',
    this.htmlUrl = '',
    this.body = '',
    this.authorAssociation = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.user,
    this.reactions,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] as int? ?? 0,
        nodeId: json['node_id'] as String? ?? '',
        htmlUrl: json['html_url'] as String? ?? '',
        body: json['body'] as String? ?? '',
        authorAssociation: json['author_association'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        updatedAt: json['updated_at'] as String? ?? '',
        user: json['user'] as Map<String, dynamic>?,
        reactions: json['reactions'] as Map<String, dynamic>?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Comment && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
