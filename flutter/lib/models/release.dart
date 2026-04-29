class ReleaseAsset {
  final int id;
  final String name;
  final String label;
  final String contentType;
  final int size;
  final int downloadCount;
  final String browserDownloadUrl;
  final String createdAt;

  const ReleaseAsset({
    this.id = 0,
    this.name = '',
    this.label = '',
    this.contentType = '',
    this.size = 0,
    this.downloadCount = 0,
    this.browserDownloadUrl = '',
    this.createdAt = '',
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) => ReleaseAsset(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        label: json['label'] as String? ?? '',
        contentType: json['content_type'] as String? ?? '',
        size: json['size'] as int? ?? 0,
        downloadCount: json['download_count'] as int? ?? 0,
        browserDownloadUrl: json['browser_download_url'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
      );
}

class Release {
  final int id;
  final String nodeId;
  final String tagName;
  final String name;
  final String body;
  final String htmlUrl;
  final String tarballUrl;
  final String zipballUrl;
  final bool draft;
  final bool prerelease;
  final String createdAt;
  final String publishedAt;
  final Map<String, dynamic>? author;
  final List<ReleaseAsset> assets;

  const Release({
    this.id = 0,
    this.nodeId = '',
    required this.tagName,
    this.name = '',
    this.body = '',
    this.htmlUrl = '',
    this.tarballUrl = '',
    this.zipballUrl = '',
    this.draft = false,
    this.prerelease = false,
    this.createdAt = '',
    this.publishedAt = '',
    this.author,
    this.assets = const [],
  });

  factory Release.fromJson(Map<String, dynamic> json) {
    final assetsList = json['assets'] as List<dynamic>?;
    return Release(
      id: json['id'] as int? ?? 0,
      nodeId: json['node_id'] as String? ?? '',
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      tarballUrl: json['tarball_url'] as String? ?? '',
      zipballUrl: json['zipball_url'] as String? ?? '',
      draft: json['draft'] as bool? ?? false,
      prerelease: json['prerelease'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
      publishedAt: json['published_at'] as String? ?? '',
      author: json['author'] as Map<String, dynamic>?,
      assets: assetsList
              ?.map((e) => ReleaseAsset.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Release && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
