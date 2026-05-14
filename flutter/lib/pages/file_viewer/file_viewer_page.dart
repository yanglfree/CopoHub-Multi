import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:highlight/highlight.dart' show highlight, Node;
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import '../../api/github_api_client.dart';
import '../../components/dialogs/app_dialog.dart';

// Extension → highlight.js language name mapping
const _extLang = <String, String>{
  '.dart': 'dart',
  '.js': 'javascript',
  '.jsx': 'javascript',
  '.ts': 'typescript',
  '.tsx': 'typescript',
  '.ets': 'typescript',
  '.py': 'python',
  '.java': 'java',
  '.kt': 'kotlin',
  '.swift': 'swift',
  '.go': 'go',
  '.rs': 'rust',
  '.c': 'c',
  '.cpp': 'cpp',
  '.cc': 'cpp',
  '.cxx': 'cpp',
  '.h': 'cpp',
  '.hpp': 'cpp',
  '.cs': 'cs',
  '.php': 'php',
  '.rb': 'ruby',
  '.sh': 'bash',
  '.bash': 'bash',
  '.zsh': 'bash',
  '.yaml': 'yaml',
  '.yml': 'yaml',
  '.json': 'json',
  '.toml': 'ini',
  '.xml': 'xml',
  '.html': 'xml',
  '.htm': 'xml',
  '.css': 'css',
  '.scss': 'scss',
  '.less': 'less',
  '.sql': 'sql',
  '.groovy': 'groovy',
  '.gradle': 'groovy',
  '.cmake': 'cmake',
  '.dockerfile': 'dockerfile',
  '.makefile': 'makefile',
  '.md': 'markdown',
  '.mdx': 'markdown',
};

// A flat text segment with an optional syntax highlight style
class _Seg {
  const _Seg(this.text, this.style);
  final String text;
  final TextStyle? style;
}

// Recursively flatten highlight node tree, propagating parent styles to leaves
List<_Seg> _flattenNodes(
  List<Node> nodes,
  Map<String, TextStyle> theme,
  TextStyle? parent,
) {
  final out = <_Seg>[];
  for (final n in nodes) {
    final s = n.className != null ? theme[n.className!] : null;
    final eff = parent == null
        ? s
        : s == null
            ? parent
            : parent.merge(s);
    if (n.value != null) {
      out.add(_Seg(n.value!, eff));
    } else if (n.children != null && n.children!.isNotEmpty) {
      out.addAll(_flattenNodes(n.children!, theme, eff));
    }
  }
  return out;
}

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

  // Search
  bool _isSearchVisible = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<int> _matchOffsets = [];
  int _currentMatchIndex = 0;

  // Display options
  bool _softWrap = false;
  bool _isFullscreen = false;

  final _vertScrollController = ScrollController();

  static const _imageSuffixes = [
    '.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.bmp', '.ico',
  ];

  String get _displayName =>
      widget.fileName ?? widget.path.split('/').last;

  String get _ext => _displayName.contains('.')
      ? '.${_displayName.split('.').last.toLowerCase()}'
      : '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _vertScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
      _content = '';
      _isImage = false;
    });

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
            decoded = utf8.decode(base64.decode(encoded.replaceAll('\n', '')));
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

  void _updateSearch(String query) {
    final offsets = <int>[];
    if (query.isNotEmpty) {
      final lower = _content.toLowerCase();
      final lowerQuery = query.toLowerCase();
      int start = 0;
      while (true) {
        final index = lower.indexOf(lowerQuery, start);
        if (index == -1) break;
        offsets.add(index);
        start = index + 1;
      }
    }
    setState(() {
      _searchQuery = query;
      _matchOffsets = offsets;
      _currentMatchIndex = 0;
    });
    if (offsets.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToMatch(0));
    }
  }

  void _scrollToMatch(int index) {
    if (_matchOffsets.isEmpty ||
        index < 0 ||
        index >= _matchOffsets.length) {
      return;
    }
    final offset = _matchOffsets[index];
    final linesAbove =
        '\n'.allMatches(_content.substring(0, offset)).length;
    const lineHeight = 13.0 * 1.5;
    const topPadding = 8.0;
    final target = topPadding + linesAbove * lineHeight;
    if (!_vertScrollController.hasClients) return;
    _vertScrollController.animateTo(
      target.clamp(0.0, _vertScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _prevMatch() {
    if (_matchOffsets.isEmpty) return;
    final newIndex =
        (_currentMatchIndex - 1 + _matchOffsets.length) % _matchOffsets.length;
    setState(() => _currentMatchIndex = newIndex);
    _scrollToMatch(newIndex);
  }

  void _nextMatch() {
    if (_matchOffsets.isEmpty) return;
    final newIndex = (_currentMatchIndex + 1) % _matchOffsets.length;
    setState(() => _currentMatchIndex = newIndex);
    _scrollToMatch(newIndex);
  }

  void _closeSearch() {
    setState(() {
      _isSearchVisible = false;
      _searchController.clear();
      _searchQuery = '';
      _matchOffsets = [];
      _currentMatchIndex = 0;
    });
  }

  void _jumpToLine(int line) {
    const lineHeight = 13.0 * 1.5;
    const topPadding = 8.0;
    final target = topPadding + (line - 1) * lineHeight;
    if (!_vertScrollController.hasClients) return;
    _vertScrollController.animateTo(
      target.clamp(0.0, _vertScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _showJumpToLineDialog() {
    final totalLines = _content.split('\n').length;
    showDialog<void>(
      context: context,
      builder: (_) => _JumpToLineDialog(
        totalLines: totalLines,
        onJump: _jumpToLine,
      ),
    );
  }

  Future<void> _downloadFile() async {
    final rawUrl =
        'https://raw.githubusercontent.com/${widget.owner}/${widget.repo}/${widget.branch}/${widget.path}';
    await launchUrl(Uri.parse(rawUrl), mode: LaunchMode.externalApplication);
  }

  bool get _hasTextContent =>
      !_loading && _error.isEmpty && !_isImage && !_isTooLarge && _content.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final appBar = _isFullscreen
        ? null
        : AppBar(
            title: _isSearchVisible
                ? _SearchBar(
                    controller: _searchController,
                    matchCount: _matchOffsets.length,
                    currentMatch:
                        _matchOffsets.isEmpty ? 0 : _currentMatchIndex + 1,
                    onChanged: _updateSearch,
                    onPrev: _prevMatch,
                    onNext: _nextMatch,
                    onClose: _closeSearch,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${widget.owner}/${widget.repo}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                      ),
                    ],
                  ),
            actions: _isSearchVisible
                ? const []
                : [
                    if (_hasTextContent) ...[
                      IconButton(
                        icon: const Icon(Icons.search),
                        tooltip: '搜索',
                        onPressed: () =>
                            setState(() => _isSearchVisible = true),
                      ),
                      IconButton(
                        icon: Icon(
                          _isFullscreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                        ),
                        tooltip: _isFullscreen ? '退出全屏' : '全屏',
                        onPressed: () =>
                            setState(() => _isFullscreen = !_isFullscreen),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          switch (v) {
                            case 'jump':
                              { _showJumpToLineDialog(); }
                            case 'wrap':
                              { setState(() => _softWrap = !_softWrap); }
                            case 'download':
                              { _downloadFile(); }
                            case 'copy':
                              {
                                Clipboard.setData(
                                    ClipboardData(text: _content));
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('已复制到剪贴板')));
                              }
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'jump',
                            child: ListTile(
                              leading: Icon(Icons.format_list_numbered),
                              title: Text('跳转到行'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'wrap',
                            child: ListTile(
                              leading: Icon(_softWrap
                                  ? Icons.wrap_text
                                  : Icons.wrap_text_outlined),
                              title: Text(_softWrap ? '不换行' : '换行显示'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'download',
                            child: ListTile(
                              leading: Icon(Icons.download_outlined),
                              title: Text('下载'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'copy',
                            child: ListTile(
                              leading: Icon(Icons.copy_outlined),
                              title: Text('复制内容'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ] else if (!_loading) ...[
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'download') _downloadFile();
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'download',
                            child: ListTile(
                              leading: Icon(Icons.download_outlined),
                              title: Text('下载'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
          );

    return Scaffold(
      appBar: appBar,
      body: Stack(
        children: [
          _buildBody(),
          if (_isFullscreen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: Material(
                color: Colors.black.withAlpha(160),
                borderRadius: BorderRadius.circular(20),
                child: IconButton(
                  icon: const Icon(Icons.fullscreen_exit,
                      color: Colors.white, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: '退出全屏',
                  onPressed: () => setState(() => _isFullscreen = false),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) return _ErrorRetry(message: _error, onRetry: _load);
    if (_isTooLarge) {
      return _TooLargeView(
          fileSize: _fileSize, onDownload: _downloadFile);
    }
    if (_isImage) return _ImageView(url: _imageUrl, name: _displayName);
    return _CodeView(
      content: _content,
      ext: _ext,
      searchQuery: _searchQuery,
      matchOffsets: _matchOffsets,
      currentMatchIndex: _currentMatchIndex,
      softWrap: _softWrap,
      scrollController: _vertScrollController,
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.matchCount,
    required this.currentMatch,
    required this.onChanged,
    required this.onPrev,
    required this.onNext,
    required this.onClose,
  });
  final TextEditingController controller;
  final int matchCount;
  final int currentMatch;
  final ValueChanged<String> onChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '搜索...',
              border: InputBorder.none,
              isDense: true,
            ),
            style: const TextStyle(fontSize: 14),
            onChanged: onChanged,
          ),
        ),
        if (matchCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '$currentMatch/$matchCount',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up, size: 20),
          onPressed: matchCount > 0 ? onPrev : null,
          visualDensity: VisualDensity.compact,
          tooltip: '上一个',
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          onPressed: matchCount > 0 ? onNext : null,
          visualDensity: VisualDensity.compact,
          tooltip: '下一个',
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: onClose,
          visualDensity: VisualDensity.compact,
          tooltip: '关闭搜索',
        ),
      ],
    );
  }
}

// ── Jump to line dialog ───────────────────────────────────────────────────────

class _JumpToLineDialog extends StatefulWidget {
  const _JumpToLineDialog({required this.totalLines, required this.onJump});
  final int totalLines;
  final ValueChanged<int> onJump;

  @override
  State<_JumpToLineDialog> createState() => _JumpToLineDialogState();
}

class _JumpToLineDialogState extends State<_JumpToLineDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < 1 || value > widget.totalLines) {
      setState(
          () => _errorText = '请输入 1 ~ ${widget.totalLines} 之间的行号');
      return;
    }
    Navigator.of(context).pop();
    widget.onJump(value);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '跳转到行',
      icon: Icons.format_list_numbered_rounded,
      actions: [
        AppDialogAction(
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppDialogAction(
          label: '跳转',
          isPrimary: true,
          onPressed: _submit,
        ),
      ],
      child: AppDialogTextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        label: '行号 (1-${widget.totalLines})',
        errorText: _errorText,
        onSubmitted: (_) => _submit(),
      ),
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

class _CodeView extends StatefulWidget {
  const _CodeView({
    required this.content,
    required this.ext,
    this.searchQuery = '',
    this.matchOffsets = const [],
    this.currentMatchIndex = 0,
    this.softWrap = false,
    this.scrollController,
  });
  final String content;
  final String ext;
  final String searchQuery;
  final List<int> matchOffsets;
  final int currentMatchIndex;
  final bool softWrap;
  final ScrollController? scrollController;

  @override
  State<_CodeView> createState() => _CodeViewState();
}

class _CodeViewState extends State<_CodeView> {
  // Cached parsed nodes from highlight (language-specific, theme-independent)
  List<Node>? _parsedNodes;
  bool _parseFailed = false;

  // Cached flat segments with applied theme colors
  List<_Seg>? _cachedSegs;
  bool? _cachedIsDark;

  String? get _lang => _extLang[widget.ext];

  List<_Seg> _getSegs(bool isDark) {
    final lang = _lang;
    if (lang == null || _parseFailed) return [_Seg(widget.content, null)];

    if (_parsedNodes == null) {
      try {
        _parsedNodes =
            highlight.parse(widget.content, language: lang).nodes ?? [];
      } catch (_) {
        _parseFailed = true;
        return [_Seg(widget.content, null)];
      }
    }

    if (_cachedSegs == null || _cachedIsDark != isDark) {
      _cachedIsDark = isDark;
      final theme = isDark ? atomOneDarkTheme : githubTheme;
      _cachedSegs = _flattenNodes(_parsedNodes!, theme, null);
    }

    return _cachedSegs!;
  }

  // Produce TextSpan list, overlaying search highlights on syntax spans
  List<TextSpan> _applySearch(List<_Seg> segs) {
    final offsets = widget.matchOffsets;
    final qlen = widget.searchQuery.length;

    if (offsets.isEmpty || qlen == 0) {
      return segs.map((s) => TextSpan(text: s.text, style: s.style)).toList();
    }

    final spans = <TextSpan>[];
    int pos = 0;

    for (final seg in segs) {
      final segStart = pos;
      final segEnd = pos + seg.text.length;
      pos = segEnd;

      final breakpoints = <int>{segStart, segEnd};
      bool hasOverlap = false;
      for (final ms in offsets) {
        final me = ms + qlen;
        if (ms < segEnd && me > segStart) {
          hasOverlap = true;
          breakpoints.add(ms.clamp(segStart, segEnd));
          breakpoints.add(me.clamp(segStart, segEnd));
        }
      }

      if (!hasOverlap) {
        spans.add(TextSpan(text: seg.text, style: seg.style));
        continue;
      }

      final sorted = breakpoints.toList()..sort();
      for (int i = 0; i < sorted.length - 1; i++) {
        final f = sorted[i];
        final t = sorted[i + 1];
        if (f >= t) continue;

        Color? bg;
        Color? fg;
        for (int mi = 0; mi < offsets.length; mi++) {
          final ms = offsets[mi];
          final me = ms + qlen;
          if (ms <= f && me >= t) {
            bg = mi == widget.currentMatchIndex
                ? const Color(0xFFFF8C00).withAlpha(220)
                : const Color(0xFFFFEB3B).withAlpha(180);
            fg = Colors.black87;
            break;
          }
        }

        final sub = seg.text.substring(f - segStart, t - segStart);
        TextStyle? style = seg.style;
        if (bg != null) {
          style = (style ?? const TextStyle()).copyWith(
            backgroundColor: bg,
            color: fg,
          );
        }
        spans.add(TextSpan(text: sub, style: style));
      }
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMap = isDark ? atomOneDarkTheme : githubTheme;
    final hasLang = _lang != null;

    final bgColor = hasLang
        ? (themeMap['root']?.backgroundColor ??
            (isDark ? const Color(0xFF282c34) : const Color(0xFFf8f8f8)))
        : Theme.of(context).colorScheme.surface;
    final fgColor = hasLang
        ? (themeMap['root']?.color ??
            (isDark ? const Color(0xFFabb2bf) : const Color(0xFF333333)))
        : Theme.of(context).colorScheme.onSurface;

    final lineCount = widget.content.split('\n').length;

    final baseStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      height: 1.5,
      color: fgColor,
    );

    Widget textWidget;
    if (hasLang) {
      final segs = _getSegs(isDark);
      final spans = _applySearch(segs);
      textWidget = SelectableText.rich(
        TextSpan(style: baseStyle, children: spans),
      );
    } else if (widget.searchQuery.isEmpty || widget.matchOffsets.isEmpty) {
      textWidget = SelectableText(widget.content, style: baseStyle);
    } else {
      final spans = _applySearch([_Seg(widget.content, null)]);
      textWidget = SelectableText.rich(
        TextSpan(style: baseStyle, children: spans),
      );
    }

    final scrolled = widget.softWrap
        ? textWidget
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: textWidget,
          );

    return Container(
      color: bgColor,
      child: Scrollbar(
        controller: widget.scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: widget.scrollController,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasLang && !widget.softWrap)
                  _LineNumbers(count: lineCount, isDark: isDark),
                Expanded(child: scrolled),
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
    final fgColor =
        isDark ? const Color(0xFF6e7681) : const Color(0xFF6e7781);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          count,
          (i) => SizedBox(
            height: 19.5,
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
  const _TooLargeView({required this.fileSize, this.onDownload});
  final int fileSize;
  final VoidCallback? onDownload;

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
            if (onDownload != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onDownload,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('下载文件'),
              ),
            ],
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
