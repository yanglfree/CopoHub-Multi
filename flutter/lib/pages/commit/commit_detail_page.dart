import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../api/github_api_client.dart';

/// Commit detail page — mirrors HarmonyOS CommitDetailView.
/// Shows commit metadata, stats, and per-file diffs.
class CommitDetailPage extends StatefulWidget {
  const CommitDetailPage({
    super.key,
    required this.owner,
    required this.repo,
    required this.sha,
  });
  final String owner;
  final String repo;
  final String sha;

  @override
  State<CommitDetailPage> createState() => _CommitDetailPageState();
}

class _CommitDetailPageState extends State<CommitDetailPage> {
  final _api = GitHubApiClient.instance;

  Map<String, dynamic>? _commit;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final result = await _api.getCommit(widget.owner, widget.repo, widget.sha);
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() {
        _commit = result.data;
        _loading = false;
      });
    } else {
      setState(() {
        _error = result.message ?? '获取提交详情失败';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.sha.length >= 7 ? widget.sha.substring(0, 7) : widget.sha,
          style: const TextStyle(
              fontFamily: 'monospace', fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: '复制 SHA',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.sha));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('已复制 SHA')));
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _ErrorRetry(message: _error, onRetry: _load)
              : _CommitBody(
                  commit: _commit!,
                  owner: widget.owner,
                  repo: widget.repo,
                ),
    );
  }
}

// ── Commit body ───────────────────────────────────────────────────────────────

class _CommitBody extends StatelessWidget {
  const _CommitBody({
    required this.commit,
    required this.owner,
    required this.repo,
  });
  final Map<String, dynamic> commit;
  final String owner;
  final String repo;

  @override
  Widget build(BuildContext context) {
    final commitData = commit['commit'] as Map<String, dynamic>? ?? {};
    final message = (commitData['message'] as String? ?? '').trim();
    final authorInfo = commitData['author'] as Map<String, dynamic>? ?? {};
    final authorName = authorInfo['name'] as String? ?? '';
    final authorDate = authorInfo['date'] as String? ?? '';

    final authorUser = commit['author'] as Map<String, dynamic>?;
    final authorLogin = authorUser?['login'] as String? ?? '';
    final authorAvatar = authorUser?['avatar_url'] as String? ?? '';

    final stats = commit['stats'] as Map<String, dynamic>? ?? {};
    final additions = stats['additions'] as int? ?? 0;
    final deletions = stats['deletions'] as int? ?? 0;
    final files = (commit['files'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    final title = message.contains('\n')
        ? message.substring(0, message.indexOf('\n'))
        : message;
    final body = message.contains('\n')
        ? message.substring(message.indexOf('\n') + 1).trim()
        : '';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Header card ──────────────────────────────────────────────────────
        _CommitHeader(
          title: title,
          body: body,
          authorLogin: authorLogin,
          authorName: authorName,
          authorAvatar: authorAvatar,
          authorDate: authorDate,
          additions: additions,
          deletions: deletions,
          filesCount: files.length,
          onAuthorTap: authorLogin.isNotEmpty
              ? () => context.push('/user/$authorLogin')
              : null,
        ),
        // ── Files changed ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '变更文件 (${files.length})',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        ...List.generate(files.length, (i) {
          final file = files[i];
          return _FileTile(
            file: file,
            onTap: () => context.push(
              '/diff-file',
              extra: {
                'filename': file['filename'] as String? ?? '',
                'status': file['status'] as String? ?? 'modified',
                'additions': file['additions'] as int? ?? 0,
                'deletions': file['deletions'] as int? ?? 0,
                'patch': file['patch'] as String?,
              },
            ),
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Commit header ─────────────────────────────────────────────────────────────

class _CommitHeader extends StatelessWidget {
  const _CommitHeader({
    required this.title,
    required this.body,
    required this.authorLogin,
    required this.authorName,
    required this.authorAvatar,
    required this.authorDate,
    required this.additions,
    required this.deletions,
    required this.filesCount,
    this.onAuthorTap,
  });

  final String title;
  final String body;
  final String authorLogin;
  final String authorName;
  final String authorAvatar;
  final String authorDate;
  final int additions;
  final int deletions;
  final int filesCount;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            // Body
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(body,
                  style: TextStyle(
                      fontSize: 13, color: cs.onSurfaceVariant, height: 1.4)),
            ],
            const SizedBox(height: 12),
            // Author row
            InkWell(
              onTap: onAuthorTap,
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  if (authorAvatar.isNotEmpty)
                    ClipOval(
                      child: CachedNetworkImage(
                          imageUrl: authorAvatar,
                          width: 24,
                          height: 24,
                          placeholder: (_, __) => Container(
                              width: 24,
                              height: 24,
                              color: cs.surfaceContainerHighest),
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.account_circle, size: 24)),
                    )
                  else
                    const Icon(Icons.account_circle, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      authorLogin.isNotEmpty ? '@$authorLogin' : authorName,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: onAuthorTap != null ? cs.primary : null),
                    ),
                  ),
                  Text(_fmtDate(authorDate),
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const Divider(height: 20),
            // Stats row
            Row(
              children: [
                _StatChip(
                    label: '+$additions',
                    color: isDark
                        ? const Color(0xFF3FB950)
                        : const Color(0xFF1a7f37)),
                const SizedBox(width: 8),
                _StatChip(
                    label: '-$deletions',
                    color: isDark
                        ? const Color(0xFFF85149)
                        : const Color(0xFFcf222e)),
                const SizedBox(width: 8),
                _StatChip(
                    label: '$filesCount 文件',
                    color: cs.onSurfaceVariant),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${_p(dt.month)}-${_p(dt.day)} '
          '${_p(dt.hour)}:${_p(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }

  static String _p(int v) => v.toString().padLeft(2, '0');
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
                fontFamily: 'monospace')),
      );
}

// ── File tile (expandable diff) ───────────────────────────────────────────────

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.file,
    required this.onTap,
  });
  final Map<String, dynamic> file;
  final VoidCallback onTap;

  Color _statusColor(String status, bool isDark) {
    switch (status) {
      case 'added':
        return isDark ? const Color(0xFF3FB950) : const Color(0xFF1a7f37);
      case 'removed':
        return isDark ? const Color(0xFFF85149) : const Color(0xFFcf222e);
      case 'renamed':
        return isDark ? const Color(0xFFD29922) : const Color(0xFF9a6700);
      default:
        return isDark ? const Color(0xFF79c0ff) : const Color(0xFF0969da);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filename = file['filename'] as String? ?? '';
    final status = file['status'] as String? ?? 'modified';
    final additions = file['additions'] as int? ?? 0;
    final deletions = file['deletions'] as int? ?? 0;
    final patch = file['patch'] as String?;

    final statusColor = _statusColor(status, isDark);
    final label = _statusLabel(status);

    return Column(
      children: [
        InkWell(
          onTap: patch != null ? onTap : null,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Status badge
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor)),
                ),
                const SizedBox(width: 10),
                // Filename
                Expanded(
                  child: Text(
                    filename,
                    style: const TextStyle(
                        fontSize: 13, fontFamily: 'monospace'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // +/- stats
                const SizedBox(width: 8),
                Text('+$additions',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF3FB950)
                            : const Color(0xFF1a7f37),
                        fontFamily: 'monospace')),
                const SizedBox(width: 4),
                Text('-$deletions',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFFF85149)
                            : const Color(0xFFcf222e),
                        fontFamily: 'monospace')),
                if (patch != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1, indent: 16),
      ],
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────

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
