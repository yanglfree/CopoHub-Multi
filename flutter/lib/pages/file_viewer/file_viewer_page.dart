import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api/github_api_client.dart';

/// File viewer page — mirrors HarmonyOS FileViewerPage.
/// Displays raw file content with syntax-aware coloring for code files,
/// and a plain text view for other files.
class FileViewerPage extends StatefulWidget {
  const FileViewerPage({
    super.key,
    required this.owner,
    required this.repo,
    required this.path,
    this.branch = 'main',
    this.fileName,
  });
  final String owner;
  final String repo;
  final String path;
  final String branch;
  final String? fileName;

  @override
  State<FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends State<FileViewerPage> {
  final _api = GitHubApiClient.instance;

  String _content = '';
  bool _loading = true;
  String _error = '';
  bool _isImage = false;
  String _imageUrl = '';
  int _fileSize = 0;
  bool _isTooLarge = false;

  static const _imageSuffixes = [
    '.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.bmp', '.ico'
  ];

  String get _displayName =>
      widget.fileName ?? widget.path.split('/').last;

  String get _ext =>
      _displayName.contains('.') ? '.${_displayName.split('.').last.toLowerCase()}' : '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
      _content = '';
      _isImage = false;
    });

    // Check if this is an image file
    if (_imageSuffixes.contains(_ext)) {
      setState(() {
        _isImage = true;
        _imageUrl =
            'https://raw.githubusercontent.com/${widget.owner}/${widget.repo}/${widget.branch}/${widget.path}';
        _loading = false;
      });
      return;
    }

    final result = await _api.getFileContents(
      widget.owner,
      widget.repo,
      widget.path,
      ref: widget.branch,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final data = result.data;
      if (data is Map<String, dynamic>) {
        _fileSize = data['size'] as int? ?? 0;
        if (_fileSize > 200 * 1024) {
          // > 200 KB — too large to display comfortably
          setState(() {
            _isTooLarge = true;
            _loading = false;
          });
          return;
        }
        final encoded = data['content'] as String? ?? '';
        final encoding = data['encoding'] as String? ?? '';
        String decoded = '';
        if (encoding == 'base64') {
          try {
            decoded =
                utf8.decode(base64.decode(encoded.replaceAll('\n', '')));
          } catch (_) {
            decoded = '(无法解码文件内容)';
          }
        } else {
          decoded = encoded;
        }
        setState(() {
          _content = decoded;
          _loading = false;
        });
      } else {
        setState(() {
          _error = '无法解析文件内容';
          _loading = false;
        });
      }
    } else {
      setState(() {
        _error = result.message ?? '加载文件失败';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_displayName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
            Text(
              '${widget.owner}/${widget.repo}',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          if (!_loading && !_error.isNotEmpty && !_isImage && _content.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: '复制内容',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _content));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制到剪贴板')));
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _ErrorRetry(message: _error, onRetry: _load)
              : _isTooLarge
                  ? _TooLargeView(fileSize: _fileSize)
                  : _isImage
                      ? _ImageView(url: _imageUrl, name: _displayName)
                      : _CodeView(content: _content, ext: _ext),
    );
  }
}

// ── Image view ────────────────────────────────────────────────────────────────

class _ImageView extends StatelessWidget {
  const _ImageView({required this.url, required this.name});
  final String url;
  final String name;

  @override
  Widget build(BuildContext context) => InteractiveViewer(
        child: Center(
          child: Image.network(
            url,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (_, __, ___) => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, size: 48),
                  SizedBox(height: 8),
                  Text('无法加载图片'),
                ],
              ),
            ),
          ),
        ),
      );
}

// ── Code/text view ────────────────────────────────────────────────────────────

class _CodeView extends StatelessWidget {
  const _CodeView({required this.content, required this.ext});
  final String content;
  final String ext;

  static const _codeExts = {
    '.dart', '.js', '.ts', '.jsx', '.tsx', '.py', '.java', '.kt', '.swift',
    '.go', '.rs', '.c', '.cpp', '.h', '.cs', '.php', '.rb', '.sh', '.bash',
    '.zsh', '.yaml', '.yml', '.json', '.toml', '.xml', '.html', '.css',
    '.scss', '.less', '.sql', '.gradle', '.cmake', '.makefile', '.dockerfile',
    '.ets', '.md', '.mdx',
  };

  bool get _isCode => _codeExts.contains(ext);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = _isCode
        ? (isDark ? const Color(0xFF0d1117) : const Color(0xFFf6f8fa))
        : Theme.of(context).colorScheme.surface;
    final fgColor = isDark ? const Color(0xFFe6edf3) : const Color(0xFF24292f);
    final lineCountStr = content.split('\n').length;

    return Container(
      color: bgColor,
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line numbers
                if (_isCode)
                  _LineNumbers(
                      count: lineCountStr,
                      isDark: isDark),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SelectableText(
                      content,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.5,
                        color: fgColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LineNumbers extends StatelessWidget {
  const _LineNumbers({required this.count, required this.isDark});
  final int count;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fgColor = isDark ? const Color(0xFF6e7681) : const Color(0xFF6e7781);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          count,
          (i) => SizedBox(
            height: 19.5, // matches line height of 13 * 1.5
            child: Text(
              '${i + 1}',
              style: TextStyle(
                  fontFamily: 'monospace', fontSize: 13, color: fgColor),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Too-large view ────────────────────────────────────────────────────────────

class _TooLargeView extends StatelessWidget {
  const _TooLargeView({required this.fileSize});
  final int fileSize;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_outlined,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text('文件过大 (${(fileSize / 1024).toStringAsFixed(1)} KB)'),
            const SizedBox(height: 6),
            const Text('无法在应用内预览此文件', style: TextStyle(fontSize: 13)),
          ],
        ),
      );
}

// ── Error retry ───────────────────────────────────────────────────────────────

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      );
}
