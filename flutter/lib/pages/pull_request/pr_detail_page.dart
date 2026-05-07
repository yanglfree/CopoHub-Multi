import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import '../../api/github_api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/link_utils.dart';

/// Pull Request detail page.
///
/// Shows PR-specific metadata (branches, review status, merge controls) in
/// addition to the body and comments thread that the Issue detail page provides.
class PrDetailPage extends StatefulWidget {
  const PrDetailPage({
    super.key,
    required this.owner,
    required this.repo,
    required this.number,
  });
  final String owner;
  final String repo;
  final int number;

  @override
  State<PrDetailPage> createState() => _PrDetailPageState();
}

class _PrDetailPageState extends State<PrDetailPage>
    with SingleTickerProviderStateMixin {
  final _api = GitHubApiClient.instance;

  // PR data
  Map<String, dynamic>? _pr;
  bool _prLoading = true;
  String _prError = '';

  // Reviews
  List<Map<String, dynamic>> _reviews = [];

  // Files changed
  List<Map<String, dynamic>> _files = [];
  bool _filesLoading = false;

  // Comments
  List<Map<String, dynamic>> _comments = [];
  bool _commentsLoading = false;

  // Action in progress
  bool _actionLoading = false;

  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadPr();
    _loadComments();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadPr() async {
    setState(() {
      _prLoading = true;
      _prError = '';
    });
    final results = await Future.wait([
      _api.getPullRequest(widget.owner, widget.repo, widget.number),
      _api.getPullRequestReviews(widget.owner, widget.repo, widget.number),
    ]);
    if (!mounted) return;
    final prResult = results[0] as dynamic;
    final reviewsResult = results[1] as dynamic;
    if (prResult.isSuccess) {
      setState(() {
        _pr = prResult.data as Map<String, dynamic>;
        _reviews = ((reviewsResult.data as List<dynamic>?) ?? [])
            .cast<Map<String, dynamic>>();
        _prLoading = false;
      });
    } else {
      setState(() {
        _prError = (prResult.message as String?) ?? '获取 PR 详情失败';
        _prLoading = false;
      });
    }
  }

  Future<void> _loadComments() async {
    setState(() => _commentsLoading = true);
    final r = await _api.getPullRequestComments(
        widget.owner, widget.repo, widget.number);
    if (!mounted) return;
    setState(() {
      _comments = r.data ?? [];
      _commentsLoading = false;
    });
  }

  Future<void> _loadFiles() async {
    if (_filesLoading || _files.isNotEmpty) return;
    setState(() => _filesLoading = true);
    final r =
        await _api.getPullRequestFiles(widget.owner, widget.repo, widget.number);
    if (!mounted) return;
    setState(() {
      _files = r.data ?? [];
      _filesLoading = false;
    });
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _mergePr(String mergeMethod) async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    final l10n = AppLocalizations.of(context);
    final r = await _api.mergePullRequest(
      widget.owner,
      widget.repo,
      widget.number,
      mergeMethod: mergeMethod,
    );
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (r.isSuccess) {
      _showSnack(l10n.prMergeSuccess);
      await _loadPr();
    } else {
      _showSnack('${l10n.prMergeFail}: ${r.message ?? ''}');
    }
  }

  Future<void> _closePr() async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    final l10n = AppLocalizations.of(context);
    final r = await _api.updatePullRequestState(
      widget.owner,
      widget.repo,
      widget.number,
      state: 'closed',
    );
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (r.isSuccess) {
      _showSnack(l10n.prCloseSuccess);
      await _loadPr();
    } else {
      _showSnack('${l10n.prOperationFail}: ${r.message ?? ''}');
    }
  }

  Future<void> _reopenPr() async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    final l10n = AppLocalizations.of(context);
    final r = await _api.updatePullRequestState(
      widget.owner,
      widget.repo,
      widget.number,
      state: 'open',
    );
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (r.isSuccess) {
      _showSnack(l10n.prReopenSuccess);
      await _loadPr();
    } else {
      _showSnack('${l10n.prOperationFail}: ${r.message ?? ''}');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showMergeSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('选择合并方式',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: cs.onSurface)),
            ),
            _MergeOption(
              icon: Icons.merge,
              title: 'Merge commit',
              subtitle: '将所有提交合并到主分支',
              onTap: () {
                Navigator.of(ctx).pop();
                _mergePr('merge');
              },
            ),
            _MergeOption(
              icon: Icons.compress,
              title: 'Squash and merge',
              subtitle: '将所有提交压缩为一个提交',
              onTap: () {
                Navigator.of(ctx).pop();
                _mergePr('squash');
              },
            ),
            _MergeOption(
              icon: Icons.linear_scale,
              title: 'Rebase and merge',
              subtitle: '将提交变基到主分支',
              onTap: () {
                Navigator.of(ctx).pop();
                _mergePr('rebase');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PR #${widget.number}',
            style: const TextStyle(fontSize: 15)),
      ),
      body: _prLoading
          ? const Center(child: CircularProgressIndicator())
          : _prError.isNotEmpty
              ? _ErrorRetry(message: _prError, onRetry: _loadPr)
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final pr = _pr!;
    final state = pr['state'] as String? ?? 'open';
    final isMerged = pr['merged'] as bool? ?? false;
    final isDraft = pr['draft'] as bool? ?? false;
    final isOpen = state == 'open';
    final mergeable = pr['mergeable'] as bool?;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_loadPr(), _loadComments()]);
        if (_files.isNotEmpty) _files = [];
      },
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: _PrHeader(
              pr: pr,
              isMerged: isMerged,
              isDraft: isDraft,
              reviews: _reviews,
              onUserTap: (login) => context.push('/user/$login'),
            ),
          ),
          // Action bar for open non-draft PRs
          if (isOpen && !isDraft)
            SliverToBoxAdapter(
              child: _ActionBar(
                mergeable: mergeable,
                actionLoading: _actionLoading,
                onMerge: _showMergeSheet,
                onClose: _closePr,
              ),
            ),
          if (!isOpen && !isMerged)
            SliverToBoxAdapter(
              child: _ActionBar(
                isReopen: true,
                actionLoading: _actionLoading,
                onReopen: _reopenPr,
              ),
            ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedTabBarDelegate(
              TabBar(
                controller: _tab,
                tabs: const [
                  Tab(text: '评论'),
                  Tab(text: '文件变更'),
                  Tab(text: '审阅'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            // ── Comments tab ─────────────────────────────────────────────────
            _CommentsTab(
              comments: _comments,
              loading: _commentsLoading,
              onUserTap: (login) => context.push('/user/$login'),
            ),
            // ── Files tab ───────────────────────────────────────────────────
            _FilesTab(
              files: _files,
              loading: _filesLoading,
              onVisible: _loadFiles,
            ),
            // ── Reviews tab ─────────────────────────────────────────────────
            _ReviewsTab(
              reviews: _reviews,
              onUserTap: (login) => context.push('/user/$login'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── PR Header ─────────────────────────────────────────────────────────────────

class _PrHeader extends StatelessWidget {
  const _PrHeader({
    required this.pr,
    required this.isMerged,
    required this.isDraft,
    required this.reviews,
    required this.onUserTap,
  });

  final Map<String, dynamic> pr;
  final bool isMerged;
  final bool isDraft;
  final List<Map<String, dynamic>> reviews;
  final void Function(String) onUserTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = pr['title'] as String? ?? '';
    final body = pr['body'] as String? ?? '';
    final state = pr['state'] as String? ?? 'open';
    final user = pr['user'] as Map<String, dynamic>? ?? {};
    final login = user['login'] as String? ?? '';
    final avatar = user['avatar_url'] as String? ?? '';
    final createdAt = pr['created_at'] as String? ?? '';
    final labels = (pr['labels'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final head = (pr['head'] as Map<String, dynamic>?)?['label'] as String?
        ?? (pr['head'] as Map<String, dynamic>?)?['ref'] as String? ?? '';
    final base = (pr['base'] as Map<String, dynamic>?)?['label'] as String?
        ?? (pr['base'] as Map<String, dynamic>?)?['ref'] as String? ?? '';
    final commits = pr['commits'] as int? ?? 0;
    final additions = pr['additions'] as int? ?? 0;
    final deletions = pr['deletions'] as int? ?? 0;
    final changedFiles = pr['changed_files'] as int? ?? 0;

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
                _PrStateBadge(
                    state: state, isMerged: isMerged, isDraft: isDraft),
              ],
            ),
            const SizedBox(height: 10),
            // Branches
            if (head.isNotEmpty && base.isNotEmpty) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fork_right, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        head,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward,
                          size: 12, color: cs.onSurfaceVariant),
                    ),
                    Flexible(
                      child: Text(
                        base,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
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
                  final bgColor =
                      Color(int.tryParse('0xFF$hex') ?? 0xFFe0e0e0);
                  final brightness =
                      ThemeData.estimateBrightnessForColor(bgColor);
                  final fgColor =
                      brightness == Brightness.dark ? Colors.white : Colors.black;
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
            // Stats row
            if (commits > 0 || changedFiles > 0) ...[
              const Divider(height: 20),
              Row(
                children: [
                  if (commits > 0) ...[
                    _StatChip(
                        icon: Icons.commit,
                        label: '$commits 提交'),
                    const SizedBox(width: 10),
                  ],
                  if (changedFiles > 0)
                    _StatChip(
                        icon: Icons.description_outlined,
                        label: '$changedFiles 文件'),
                  if (additions > 0 || deletions > 0) ...[
                    const SizedBox(width: 10),
                    Text('+$additions',
                        style: const TextStyle(
                            color: Color(0xFF1a7f37),
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                    const SizedBox(width: 4),
                    Text('-$deletions',
                        style: const TextStyle(
                            color: Color(0xFFcf222e),
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ],
                ],
              ),
            ],
            // Body
            if (body.isNotEmpty) ...[
              const Divider(height: 20),
              _GithubMarkdown(body: body),
            ],
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

// ── PR state badge ────────────────────────────────────────────────────────────

class _PrStateBadge extends StatelessWidget {
  const _PrStateBadge(
      {required this.state, required this.isMerged, required this.isDraft});
  final String state;
  final bool isMerged;
  final bool isDraft;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    final IconData icon;

    if (isMerged) {
      color = const Color(0xFF8250df);
      label = 'Merged';
      icon = Icons.merge;
    } else if (isDraft) {
      color = const Color(0xFF57606a);
      label = 'Draft';
      icon = Icons.edit_outlined;
    } else if (state == 'open') {
      color = const Color(0xFF1a7f37);
      label = 'Open';
      icon = Icons.call_merge;
    } else {
      color = const Color(0xFFcf222e);
      label = 'Closed';
      icon = Icons.close;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ],
      ),
    );
  }
}

// ── Action bar ────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    this.mergeable,
    required this.actionLoading,
    this.onMerge,
    this.onClose,
    this.onReopen,
    this.isReopen = false,
  });

  final bool? mergeable;
  final bool actionLoading;
  final VoidCallback? onMerge;
  final VoidCallback? onClose;
  final VoidCallback? onReopen;
  final bool isReopen;

  @override
  Widget build(BuildContext context) {
    if (isReopen) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: actionLoading ? null : onReopen,
            icon: actionLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.restart_alt, size: 18),
            label: const Text('重新开启 PR'),
          ),
        ),
      );
    }

    final canMerge = mergeable == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: (actionLoading || !canMerge) ? null : onMerge,
              icon: actionLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.merge, size: 18),
              label: Text(canMerge ? '合并 PR' : '无法合并'),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: actionLoading ? null : onClose,
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

// ── Comments tab ──────────────────────────────────────────────────────────────

class _CommentsTab extends StatelessWidget {
  const _CommentsTab({
    required this.comments,
    required this.loading,
    required this.onUserTap,
  });
  final List<Map<String, dynamic>> comments;
  final bool loading;
  final void Function(String) onUserTap;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (comments.isEmpty) {
      return const Center(child: Text('暂无评论'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: comments.length,
      itemBuilder: (context, i) =>
          _CommentTile(comment: comments[i], onUserTap: onUserTap),
    );
  }
}

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
                              fontSize: 11, color: cs.onSurfaceVariant)),
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

// ── Files tab ─────────────────────────────────────────────────────────────────

class _FilesTab extends StatefulWidget {
  const _FilesTab({
    required this.files,
    required this.loading,
    required this.onVisible,
  });
  final List<Map<String, dynamic>> files;
  final bool loading;
  final VoidCallback onVisible;

  @override
  State<_FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<_FilesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.onVisible();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    if (widget.loading) return const Center(child: CircularProgressIndicator());
    if (widget.files.isEmpty) return const Center(child: Text('暂无文件变更'));

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: widget.files.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, i) {
        final file = widget.files[i];
        final filename = file['filename'] as String? ?? '';
        final status = file['status'] as String? ?? '';
        final additions = file['additions'] as int? ?? 0;
        final deletions = file['deletions'] as int? ?? 0;

        Color statusColor;
        IconData statusIcon;
        switch (status) {
          case 'added':
            statusColor = const Color(0xFF1a7f37);
            statusIcon = Icons.add_circle_outline;
          case 'removed':
            statusColor = const Color(0xFFcf222e);
            statusIcon = Icons.remove_circle_outline;
          case 'renamed':
            statusColor = const Color(0xFF0969da);
            statusIcon = Icons.drive_file_rename_outline;
          default:
            statusColor = cs.onSurfaceVariant;
            statusIcon = Icons.edit_outlined;
        }

        return ListTile(
          dense: true,
          leading: Icon(statusIcon, size: 18, color: statusColor),
          title: Text(
            filename,
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (additions > 0)
                Text('+$additions',
                    style: const TextStyle(
                        color: Color(0xFF1a7f37),
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
              if (additions > 0 && deletions > 0)
                const SizedBox(width: 4),
              if (deletions > 0)
                Text('-$deletions',
                    style: const TextStyle(
                        color: Color(0xFFcf222e),
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}

// ── Reviews tab ───────────────────────────────────────────────────────────────

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({required this.reviews, required this.onUserTap});
  final List<Map<String, dynamic>> reviews;
  final void Function(String) onUserTap;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const Center(child: Text('暂无审阅'));
    final cs = Theme.of(context).colorScheme;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: reviews.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, i) {
        final review = reviews[i];
        final user = review['user'] as Map<String, dynamic>? ?? {};
        final login = user['login'] as String? ?? '';
        final avatar = user['avatar_url'] as String? ?? '';
        final state = review['state'] as String? ?? '';
        final body = review['body'] as String? ?? '';
        final submittedAt = review['submitted_at'] as String? ?? '';

        Color stateColor;
        IconData stateIcon;
        String stateLabel;
        switch (state) {
          case 'APPROVED':
            stateColor = const Color(0xFF1a7f37);
            stateIcon = Icons.check_circle_outline;
            stateLabel = '已批准';
          case 'CHANGES_REQUESTED':
            stateColor = const Color(0xFFcf222e);
            stateIcon = Icons.rate_review_outlined;
            stateLabel = '请求更改';
          case 'COMMENTED':
            stateColor = cs.onSurfaceVariant;
            stateIcon = Icons.comment_outlined;
            stateLabel = '评论';
          case 'DISMISSED':
            stateColor = cs.onSurfaceVariant;
            stateIcon = Icons.block_outlined;
            stateLabel = '已忽略';
          default:
            stateColor = cs.onSurfaceVariant;
            stateIcon = Icons.pending_outlined;
            stateLabel = state;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (avatar.isNotEmpty)
                GestureDetector(
                  onTap: login.isNotEmpty ? () => onUserTap(login) : null,
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatar,
                      width: 32,
                      height: 32,
                      placeholder: (_, __) => Container(
                          width: 32,
                          height: 32,
                          color: cs.surfaceContainerHighest),
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.account_circle, size: 32),
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: login.isNotEmpty ? () => onUserTap(login) : null,
                          child: Text(login,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: cs.primary)),
                        ),
                        const SizedBox(width: 8),
                        Icon(stateIcon, size: 14, color: stateColor),
                        const SizedBox(width: 4),
                        Text(stateLabel,
                            style: TextStyle(
                                fontSize: 12,
                                color: stateColor,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text(_fmtDate(submittedAt),
                            style: TextStyle(
                                fontSize: 11, color: cs.onSurfaceVariant)),
                      ],
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(body,
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurface, height: 1.4)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
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

// ── Stat chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ],
    );
  }
}

// ── Merge option tile ─────────────────────────────────────────────────────────

class _MergeOption extends StatelessWidget {
  const _MergeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: cs.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pinned tab bar delegate ───────────────────────────────────────────────────

class _PinnedTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedTabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: tabBar,
      );

  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(_PinnedTabBarDelegate old) => tabBar != old.tabBar;
}

// ── Shared GitHub Markdown ────────────────────────────────────────────────────

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
      blockquote: bodyStyle.copyWith(color: muted),
      h1: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w700, color: fg, height: 1.3),
      h2: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700, color: fg, height: 1.3),
      h3: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, color: fg, height: 1.35),
      a: TextStyle(
          color: link,
          decoration: TextDecoration.underline,
          decorationColor: link),
      code: TextStyle(
          fontSize: 12, fontFamily: 'monospace', backgroundColor: codeBg,
          color: fg),
      codeblockPadding: const EdgeInsets.all(12),
      codeblockDecoration: BoxDecoration(
          color: preBg, borderRadius: BorderRadius.circular(6)),
      blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: border, width: 4))),
      blockquotePadding: const EdgeInsets.only(left: 12),
      tableBorder: TableBorder.all(color: border, width: 1),
      tableCellsPadding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      horizontalRuleDecoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: border, width: 1))),
    );

    return MarkdownBody(
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
          child: Image.network(src, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        );
      },
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
