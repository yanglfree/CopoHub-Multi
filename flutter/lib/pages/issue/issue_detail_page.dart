import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../components/markdown/markdown_scroll_fix.dart';
import 'package:go_router/go_router.dart';
import '../../api/github_api_client.dart';
import '../../utils/link_utils.dart';

/// Issue detail page — mirrors HarmonyOS IssueDetailView.
/// Shows issue body, labels, assignees, and comments thread.
class IssueDetailPage extends StatefulWidget {
  const IssueDetailPage({
    super.key,
    required this.owner,
    required this.repo,
    required this.number,
  });
  final String owner;
  final String repo;
  final int number;

  @override
  State<IssueDetailPage> createState() => _IssueDetailPageState();
}

class _IssueDetailPageState extends State<IssueDetailPage> {
  final _api = GitHubApiClient.instance;

  Map<String, dynamic>? _issue;
  bool _issueLoading = true;
  String _issueError = '';

  List<Map<String, dynamic>> _comments = [];
  bool _commentsLoading = false;

  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _commentPosting = false;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadIssue();
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIssue() async {
    setState(() {
      _issueLoading = true;
      _issueError = '';
    });
    final r = await _api.getIssue(widget.owner, widget.repo, widget.number);
    if (!mounted) return;
    if (r.isSuccess) {
      setState(() {
        _issue = r.data;
        _issueLoading = false;
      });
    } else {
      setState(() {
        _issueError = r.message ?? '获取 Issue 详情失败';
        _issueLoading = false;
      });
    }
  }

  Future<void> _loadComments() async {
    setState(() => _commentsLoading = true);
    final r =
        await _api.getIssueComments(widget.owner, widget.repo, widget.number);
    if (!mounted) return;
    if (r.isSuccess) {
      setState(() {
        _comments = r.data ?? [];
        _commentsLoading = false;
      });
    } else {
      setState(() => _commentsLoading = false);
    }
  }

  Future<void> _toggleIssueState() async {
    final issue = _issue;
    if (issue == null || _actionLoading) return;
    final isOpen = (issue['state'] as String? ?? 'open') == 'open';
    setState(() => _actionLoading = true);
    final r = await _api.updateIssue(
      widget.owner, widget.repo, widget.number,
      state: isOpen ? 'closed' : 'open',
    );
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (r.isSuccess) {
      setState(() => _issue = r.data);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(isOpen ? 'Issue 已关闭' : 'Issue 已重新开启')),
      );
    } else {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('操作失败: ${r.message ?? ''}')),
      );
    }
  }

  Future<void> _postComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty || _commentPosting) return;
    setState(() => _commentPosting = true);
    final r = await _api.createIssueComment(
        widget.owner, widget.repo, widget.number, body);
    if (!mounted) return;
    setState(() => _commentPosting = false);
    if (r.isSuccess) {
      _commentCtrl.clear();
      FocusScope.of(context).unfocus();
      await _loadComments();
      if (mounted && _scrollCtrl.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } else {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('评论失败: ${r.message ?? ''}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final issue = _issue;
    final isOpen = (issue?['state'] as String? ?? 'open') == 'open';
    final isPR = issue?['pull_request'] != null;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isPR ? 'Pull Request #${widget.number}' : 'Issue #${widget.number}',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          if (!_issueLoading && _issueError.isEmpty && !isPR)
            _actionLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    onPressed: _toggleIssueState,
                    tooltip: isOpen ? '关闭 Issue' : '重新开启',
                    icon: Icon(
                      isOpen
                          ? Icons.do_not_disturb_on_outlined
                          : Icons.replay_outlined,
                      color: isOpen ? Theme.of(context).colorScheme.error : const Color(0xFF1a7f37),
                    ),
                  ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _issueLoading
                ? const Center(child: CircularProgressIndicator())
                : _issueError.isNotEmpty
                    ? _ErrorRetry(message: _issueError, onRetry: _loadIssue)
                    : RefreshIndicator(
                        onRefresh: () async {
                          await Future.wait([_loadIssue(), _loadComments()]);
                        },
                        child: ListView(
                          controller: _scrollCtrl,
                          children: [
                            // ── Issue header ─────────────────────────────────
                            _IssueHeader(
                              issue: issue!,
                              isOpen: isOpen,
                              onUserTap: (login) =>
                                  context.push('/user/$login'),
                            ),
                            // ── Comments ──────────────────────────────────────
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text(
                                '评论 (${_comments.length})',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (_commentsLoading)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                    child: CircularProgressIndicator()),
                              )
                            else if (_comments.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: Text('暂无评论',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant)),
                                ),
                              )
                            else
                              ..._comments.map((c) => _CommentTile(
                                    comment: c,
                                    onUserTap: (login) =>
                                        context.push('/user/$login'),
                                  )),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
          ),
          // ── Comment input bar ─────────────────────────────────────────────
          if (!_issueLoading && _issueError.isEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 8,
                bottom: MediaQuery.of(context).padding.bottom + 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: '写评论…',
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _commentPosting
                      ? const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton.filled(
                          onPressed: _postComment,
                          icon: const Icon(Icons.send, size: 18),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(36, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Issue header ──────────────────────────────────────────────────────────────

class _IssueHeader extends StatelessWidget {
  const _IssueHeader({
    required this.issue,
    required this.isOpen,
    required this.onUserTap,
  });
  final Map<String, dynamic> issue;
  final bool isOpen;
  final void Function(String) onUserTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = issue['title'] as String? ?? '';
    final body = issue['body'] as String? ?? '';
    final user = issue['user'] as Map<String, dynamic>? ?? {};
    final login = user['login'] as String? ?? '';
    final avatar = user['avatar_url'] as String? ?? '';
    final createdAt = issue['created_at'] as String? ?? '';
    final labels = (issue['labels'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final assignees = (issue['assignees'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final comments = issue['comments'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + state badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                const SizedBox(width: 8),
                _StateBadge(isOpen: isOpen),
              ],
            ),
            const SizedBox(height: 10),
            // Author + date
            InkWell(
              onTap: login.isNotEmpty ? () => onUserTap(login) : null,
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  if (avatar.isNotEmpty)
                    ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatar,
                        width: 20,
                        height: 20,
                        placeholder: (_, __) => Container(
                            width: 20,
                            height: 20,
                            color: cs.surfaceContainerHighest),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.account_circle, size: 20),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Text(login,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.primary)),
                  const SizedBox(width: 6),
                  Text(_fmtDate(createdAt),
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            // Labels
            if (labels.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: labels.map((l) {
                  final hex = l['color'] as String? ?? 'e0e0e0';
                  final bgColor = Color(
                      int.tryParse('0xFF$hex') ?? 0xFFe0e0e0);
                  final brightness = ThemeData.estimateBrightnessForColor(bgColor);
                  final fgColor = brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l['name'] as String? ?? '',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: fgColor),
                    ),
                  );
                }).toList(),
              ),
            ],
            // Assignees
            if (assignees.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('指派给: ',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                  ...assignees.take(5).map((a) {
                    final aLogin = a['login'] as String? ?? '';
                    final aAvatar = a['avatar_url'] as String? ?? '';
                    return GestureDetector(
                      onTap: aLogin.isNotEmpty
                          ? () => onUserTap(aLogin)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Tooltip(
                          message: aLogin,
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: aAvatar,
                              width: 20,
                              height: 20,
                              placeholder: (_, __) => Container(
                                  width: 20,
                                  height: 20,
                                  color: cs.surfaceContainerHighest),
                              errorWidget: (_, __, ___) =>
                                  const Icon(Icons.account_circle, size: 20),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
            // Body
            if (body.isNotEmpty) ...[
              const Divider(height: 20),
              _GithubMarkdown(body: body),
            ],
            // Comment count
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.comment_outlined, size: 14),
                const SizedBox(width: 4),
                Text('$comments 条评论',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
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
      return '${dt.year}-${_p(dt.month)}-${_p(dt.day)}';
    } catch (_) {
      return iso;
    }
  }

  static String _p(int v) => v.toString().padLeft(2, '0');
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.isOpen});
  final bool isOpen;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isOpen
              ? const Color(0xFF1a7f37)
              : const Color(0xFF8250df),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                isOpen
                    ? Icons.circle_outlined
                    : Icons.check_circle_outlined,
                size: 12,
                color: Colors.white),
            const SizedBox(width: 4),
            Text(isOpen ? 'Open' : 'Closed',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ],
        ),
      );
}

// ── Comment tile ──────────────────────────────────────────────────────────────

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.onUserTap});
  final Map<String, dynamic> comment;
  final void Function(String) onUserTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = comment['user'] as Map<String, dynamic>? ?? {};
    final login = user['login'] as String? ?? '';
    final avatar = user['avatar_url'] as String? ?? '';
    final body = comment['body'] as String? ?? '';
    final createdAt = comment['created_at'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author header
              InkWell(
                onTap: login.isNotEmpty ? () => onUserTap(login) : null,
                child: Row(
                  children: [
                    if (avatar.isNotEmpty)
                      ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: avatar,
                          width: 24,
                          height: 24,
                          placeholder: (_, __) => Container(
                              width: 24,
                              height: 24,
                              color: cs.surfaceContainerHighest),
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.account_circle, size: 24),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(login,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.primary)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_fmtDate(createdAt),
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 8),
                _GithubMarkdown(body: body),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${_p(dt.month)}-${_p(dt.day)}';
    } catch (_) {
      return iso;
    }
  }

  static String _p(int v) => v.toString().padLeft(2, '0');
}

// ── Error retry ──────────────────────────────────────────────────────────────

/// Shared GitHub-flavoured Markdown renderer used for issue bodies and comments.
class _GithubMarkdown extends StatelessWidget {
  const _GithubMarkdown({required this.body});
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? const Color(0xFFe6edf3) : const Color(0xFF24292f);
    final muted = isDark ? const Color(0xFF8b949e) : const Color(0xFF57606a);
    final border = isDark ? const Color(0xFF30363d) : const Color(0xFFd0d7de);
    final codeBg = isDark ? const Color(0x666e7681) : const Color(0x33afb8c1);
    final preBg = isDark ? const Color(0xFF161b22) : const Color(0xFFf6f8fa);
    final link = isDark ? const Color(0xFF58a6ff) : const Color(0xFF0969da);
    final base = MarkdownStyleSheet.fromTheme(theme);
    final bodyStyle = TextStyle(fontSize: 13, height: 1.5, color: fg);
    final style = base.copyWith(
      p: bodyStyle,
      listBullet: bodyStyle,
      tableBody: bodyStyle,
      tableHead: bodyStyle.copyWith(fontWeight: FontWeight.w600),
      blockquote: bodyStyle.copyWith(color: muted),
      h1: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: fg, height: 1.3),
      h2: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fg, height: 1.3),
      h3: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: fg, height: 1.35),
      a: TextStyle(
        color: link,
        decoration: TextDecoration.underline,
        decorationColor: link,
      ),
      code: TextStyle(
        fontSize: 12,
        fontFamily: 'monospace',
        backgroundColor: codeBg,
        color: fg,
      ),
      codeblockPadding: const EdgeInsets.all(12),
      codeblockDecoration: BoxDecoration(
        color: preBg,
        borderRadius: BorderRadius.circular(6),
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: border, width: 4)),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12),
      tableBorder: TableBorder.all(color: border, width: 1),
      tableCellsPadding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border, width: 1)),
      ),
    );

    return MarkdownScrollFix(
      child: MarkdownBody(
        data: body,
        selectable: false,
        styleSheet: style,
        onTapLink: (text, href, title) {
          if (href == null || href.isEmpty) return;
          dispatchLinkAction(context, href);
        },
        imageBuilder: (uri, title, alt) {
          final src = uri.toString();
          if (src.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Image.network(
              src,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
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
