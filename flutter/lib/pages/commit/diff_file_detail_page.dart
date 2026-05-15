import 'package:flutter/material.dart';

/// Full-page diff viewer for a single changed file.
/// Mirrors HarmonyOS CodeDiffViewer — shows old/new line numbers
/// and colour-coded addition / deletion / context / header rows.
class DiffFileDetailPage extends StatefulWidget {
  const DiffFileDetailPage({
    super.key,
    required this.filename,
    required this.status,
    required this.additions,
    required this.deletions,
    this.patch,
  });

  final String filename;
  final String status; // 'added' | 'removed' | 'modified' | 'renamed'
  final int additions;
  final int deletions;
  final String? patch;

  @override
  State<DiffFileDetailPage> createState() => _DiffFileDetailPageState();
}

class _DiffFileDetailPageState extends State<DiffFileDetailPage> {
  late final List<_DiffLine> _lines;

  @override
  void initState() {
    super.initState();
    _lines = _parsePatch(widget.patch);
  }

  // ── patch parser ────────────────────────────────────────────────────────────

  static List<_DiffLine> _parsePatch(String? patch) {
    if (patch == null || patch.isEmpty) return [];

    final lines = patch.split('\n');
    final result = <_DiffLine>[];
    int oldLine = 0;
    int newLine = 0;

    for (final line in lines) {
      if (line.startsWith('@@')) {
        final m = RegExp(r'@@ -(\d+),?\d* \+(\d+),?\d* @@').firstMatch(line);
        if (m != null) {
          oldLine = int.parse(m.group(1)!) - 1;
          newLine = int.parse(m.group(2)!) - 1;
        }
        result.add(_DiffLine(type: _DLT.header, content: line));
      } else if (line.startsWith('+') && !line.startsWith('+++')) {
        newLine++;
        result.add(_DiffLine(
          type: _DLT.addition,
          content: line.substring(1),
          newLineNumber: newLine,
        ));
      } else if (line.startsWith('-') && !line.startsWith('---')) {
        oldLine++;
        result.add(_DiffLine(
          type: _DLT.deletion,
          content: line.substring(1),
          oldLineNumber: oldLine,
        ));
      } else if (line.startsWith(' ')) {
        oldLine++;
        newLine++;
        result.add(_DiffLine(
          type: _DLT.context,
          content: line.substring(1),
          oldLineNumber: oldLine,
          newLineNumber: newLine,
        ));
      }
    }

    return result;
  }

  // ── helpers ─────────────────────────────────────────────────────────────────

  String _statusLabel() {
    switch (widget.status) {
      case 'added':
        return 'A';
      case 'removed':
        return 'D';
      case 'renamed':
        return 'R';
      default:
        return 'M';
    }
  }

  Color _statusColor() {
    switch (widget.status) {
      case 'added':
        return const Color(0xFF1a7f37);
      case 'removed':
        return const Color(0xFFcf222e);
      case 'renamed':
        return const Color(0xFF9a6700);
      default:
        return const Color(0xFF0969da);
    }
  }

  String _statusText() {
    switch (widget.status) {
      case 'added':
        return '新建文件';
      case 'removed':
        return '删除文件';
      case 'renamed':
        return '重命名';
      default:
        return '修改文件';
    }
  }

  // ── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final baseName = widget.filename.split('/').last;
    final dirPath = widget.filename.contains('/')
        ? widget.filename.substring(0, widget.filename.lastIndexOf('/'))
        : '';
    final statusColor = _statusColor();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _statusLabel(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    baseName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (dirPath.isNotEmpty)
              Text(
                dirPath,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              )
            else
              Text(
                _statusText(),
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+${widget.additions}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1a7f37),
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '-${widget.deletions}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFcf222e),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _lines.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description_outlined,
                      size: 48, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('无差异内容', style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            )
          : _DiffView(lines: _lines, isDark: isDark),
    );
  }
}

// ── Diff view ─────────────────────────────────────────────────────────────────

class _DiffView extends StatelessWidget {
  const _DiffView({required this.lines, required this.isDark});
  final List<_DiffLine> lines;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF0d1117) : const Color(0xFFf6f8fa);
    final screenWidth = MediaQuery.of(context).size.width;
    // Estimate content width: line-num col ~88px + ~7.5px per char + 24px padding
    final maxChars = lines.fold<int>(
        0, (m, l) => l.content.length > m ? l.content.length : m);
    final estimatedWidth = 88.0 + maxChars * 7.5 + 24.0;
    final totalWidth = estimatedWidth.clamp(screenWidth, double.infinity);

    return Container(
      color: bgColor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          child: ListView.builder(
            itemCount: lines.length,
            itemBuilder: (context, i) =>
                _DiffLineWidget(line: lines[i], isDark: isDark),
          ),
        ),
      ),
    );
  }
}

// ── Single diff line ──────────────────────────────────────────────────────────

class _DiffLineWidget extends StatelessWidget {
  const _DiffLineWidget({required this.line, required this.isDark});
  final _DiffLine line;
  final bool isDark;

  Color _bg() {
    switch (line.type) {
      case _DLT.addition:
        return isDark ? const Color(0xFF1a4d2e) : const Color(0xFFe6ffec);
      case _DLT.deletion:
        return isDark ? const Color(0xFF4d1a1e) : const Color(0xFFffebe9);
      case _DLT.header:
        return isDark ? const Color(0xFF1a2d4d) : const Color(0xFFddf4ff);
      case _DLT.context:
        return Colors.transparent;
    }
  }

  Color _fg() {
    switch (line.type) {
      case _DLT.addition:
        return isDark ? const Color(0xFF56d364) : const Color(0xFF1a7f37);
      case _DLT.deletion:
        return isDark ? const Color(0xFFf85149) : const Color(0xFFcf222e);
      case _DLT.header:
        return isDark ? const Color(0xFF79c0ff) : const Color(0xFF0969da);
      case _DLT.context:
        return isDark ? const Color(0xFFe6edf3) : const Color(0xFF24292f);
    }
  }

  String _prefix() {
    switch (line.type) {
      case _DLT.addition:
        return '+';
      case _DLT.deletion:
        return '-';
      default:
        return ' ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final lineNumColor =
        isDark ? const Color(0xFF6e7681) : const Color(0xFF6e7781);
    final numBg = isDark ? const Color(0xFF161b22) : const Color(0xFFf0f2f5);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Line numbers column ──────────────────────────────────────────
        Container(
          color: numBg,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  line.oldLineNumber?.toString() ?? '',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: lineNumColor,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 34,
                child: Text(
                  line.newLineNumber?.toString() ?? '',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: lineNumColor,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        // ── Diff content column ──────────────────────────────────────────
        Expanded(
          child: Container(
            color: _bg(),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              '${_prefix()}${line.content}',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: _fg(),
                height: 1.5,
              ),
              softWrap: false,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

enum _DLT { context, addition, deletion, header }

class _DiffLine {
  const _DiffLine({
    required this.type,
    required this.content,
    this.oldLineNumber,
    this.newLineNumber,
  });
  final _DLT type;
  final String content;
  final int? oldLineNumber;
  final int? newLineNumber;
}
