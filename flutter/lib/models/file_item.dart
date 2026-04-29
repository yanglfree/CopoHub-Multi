class FileItem {
  final String name;
  final String path;
  final String type; // 'file' | 'dir'
  final int size;
  final String sha;
  final String url;
  final String htmlUrl;
  final String downloadUrl;

  const FileItem({
    required this.name,
    required this.path,
    this.type = 'file',
    this.size = 0,
    this.sha = '',
    this.url = '',
    this.htmlUrl = '',
    this.downloadUrl = '',
  });

  bool get isDirectory => type == 'dir';

  String get extension {
    if (isDirectory) return '';
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  String get formattedSize {
    if (isDirectory || size == 0) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory FileItem.fromJson(Map<String, dynamic> json) => FileItem(
        name: json['name'] as String? ?? '',
        path: json['path'] as String? ?? '',
        type: json['type'] as String? ?? 'file',
        size: json['size'] as int? ?? 0,
        sha: json['sha'] as String? ?? '',
        url: json['url'] as String? ?? '',
        htmlUrl: json['html_url'] as String? ?? '',
        downloadUrl: json['download_url'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is FileItem && other.path == path);

  @override
  int get hashCode => path.hashCode;
}
