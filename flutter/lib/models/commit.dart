class CommitAuthorInfo {
  final String name;
  final String email;
  final String date;

  const CommitAuthorInfo({
    this.name = '',
    this.email = '',
    this.date = '',
  });

  factory CommitAuthorInfo.fromJson(Map<String, dynamic> json) =>
      CommitAuthorInfo(
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        date: json['date'] as String? ?? '',
      );
}

class CommitStats {
  final int total;
  final int additions;
  final int deletions;

  const CommitStats({this.total = 0, this.additions = 0, this.deletions = 0});

  factory CommitStats.fromJson(Map<String, dynamic> json) => CommitStats(
        total: json['total'] as int? ?? 0,
        additions: json['additions'] as int? ?? 0,
        deletions: json['deletions'] as int? ?? 0,
      );
}

class CommitFile {
  final String filename;
  final String status;
  final int additions;
  final int deletions;
  final int changes;
  final String patch;
  final String rawUrl;
  final String blobUrl;

  const CommitFile({
    this.filename = '',
    this.status = '',
    this.additions = 0,
    this.deletions = 0,
    this.changes = 0,
    this.patch = '',
    this.rawUrl = '',
    this.blobUrl = '',
  });

  factory CommitFile.fromJson(Map<String, dynamic> json) => CommitFile(
        filename: json['filename'] as String? ?? '',
        status: json['status'] as String? ?? '',
        additions: json['additions'] as int? ?? 0,
        deletions: json['deletions'] as int? ?? 0,
        changes: json['changes'] as int? ?? 0,
        patch: json['patch'] as String? ?? '',
        rawUrl: json['raw_url'] as String? ?? '',
        blobUrl: json['blob_url'] as String? ?? '',
      );
}

class Commit {
  final String sha;
  final String nodeId;
  final String htmlUrl;
  final String message;
  final CommitAuthorInfo commitAuthor;
  final CommitAuthorInfo commitCommitter;
  final Map<String, dynamic>? author;
  final Map<String, dynamic>? committer;
  final CommitStats? stats;
  final List<CommitFile> files;

  const Commit({
    required this.sha,
    this.nodeId = '',
    this.htmlUrl = '',
    this.message = '',
    this.commitAuthor = const CommitAuthorInfo(),
    this.commitCommitter = const CommitAuthorInfo(),
    this.author,
    this.committer,
    this.stats,
    this.files = const [],
  });

  String get shortSha => sha.length >= 7 ? sha.substring(0, 7) : sha;

  factory Commit.fromJson(Map<String, dynamic> json) {
    final commitMap = json['commit'] as Map<String, dynamic>?;
    final statsMap = json['stats'] as Map<String, dynamic>?;
    final filesList = json['files'] as List<dynamic>?;

    return Commit(
      sha: json['sha'] as String? ?? '',
      nodeId: json['node_id'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      message: commitMap?['message'] as String? ?? '',
      commitAuthor: commitMap?['author'] != null
          ? CommitAuthorInfo.fromJson(
              commitMap!['author'] as Map<String, dynamic>)
          : const CommitAuthorInfo(),
      commitCommitter: commitMap?['committer'] != null
          ? CommitAuthorInfo.fromJson(
              commitMap!['committer'] as Map<String, dynamic>)
          : const CommitAuthorInfo(),
      author: json['author'] as Map<String, dynamic>?,
      committer: json['committer'] as Map<String, dynamic>?,
      stats: statsMap != null ? CommitStats.fromJson(statsMap) : null,
      files: filesList
              ?.map((e) => CommitFile.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Commit && other.sha == sha);

  @override
  int get hashCode => sha.hashCode;
}
