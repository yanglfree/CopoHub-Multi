import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/github_api_client.dart';
import '../../models/repository.dart';
import '../../services/auth_service.dart';

/// Shows a quick-action bottom sheet for [repo].
///
/// Options: Copy URL, Copy name, Star/Unstar, Open in browser.
Future<void> showRepoContextMenu(BuildContext context, Repository repo) {
  return showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _RepoContextMenuSheet(repo: repo),
  );
}

/// Convenience overload for places that only have [owner] and [name] strings
/// (e.g. TrendingItem, DeduplicatedRepoItem) without a full [Repository].
Future<void> showRepoContextMenuFor(
  BuildContext context, {
  required String owner,
  required String name,
}) {
  final repo = Repository(
    id: 0,
    name: name,
    fullName: '$owner/$name',
    owner: RepoOwner(login: owner, id: 0, avatarUrl: ''),
  );
  return showRepoContextMenu(context, repo);
}

// ── Bottom sheet ──────────────────────────────────────────────────────────────

class _RepoContextMenuSheet extends StatefulWidget {
  const _RepoContextMenuSheet({required this.repo});
  final Repository repo;

  @override
  State<_RepoContextMenuSheet> createState() => _RepoContextMenuSheetState();
}

class _RepoContextMenuSheetState extends State<_RepoContextMenuSheet> {
  final _api = GitHubApiClient.instance;

  bool? _isStarred; // null = loading / unknown
  bool _starLoading = false;

  String get _owner => widget.repo.owner?.login ?? '';
  String get _repoName => widget.repo.name;
  String get _fullName => '$_owner/$_repoName';
  String get _url => 'https://github.com/$_fullName';

  bool get _isLoggedIn => AuthService.instance.isLoggedIn;

  @override
  void initState() {
    super.initState();
    if (_isLoggedIn && _owner.isNotEmpty) {
      _checkStarred();
    }
  }

  Future<void> _checkStarred() async {
    final result = await _api.checkRepositoryStarred(_owner, _repoName);
    if (mounted) {
      setState(() => _isStarred = result.data ?? false);
    }
  }

  Future<void> _toggleStar() async {
    if (!_isLoggedIn || _owner.isEmpty) return;
    final currentlyStarred = _isStarred ?? false;
    setState(() {
      _starLoading = true;
      _isStarred = !currentlyStarred;
    });
    final result = currentlyStarred
        ? await _api.unstarRepository(_owner, _repoName)
        : await _api.starRepository(_owner, _repoName);
    if (!mounted) return;
    if (result.success) {
      final msg = currentlyStarred ? '已取消 Star' : '已 Star 该仓库';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
    } else {
      // Revert on failure
      setState(() => _isStarred = currentlyStarred);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? '操作失败，请重试')),
      );
    }
    setState(() => _starLoading = false);
  }

  void _copyUrl() {
    Clipboard.setData(ClipboardData(text: _url));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('链接已复制'), duration: Duration(seconds: 2)),
    );
  }

  void _copyName() {
    Clipboard.setData(ClipboardData(text: _fullName));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('名称已复制'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _openInBrowser() async {
    Navigator.pop(context);
    final uri = Uri.parse(_url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final starLabel = _isStarred == true ? '取消 Star' : 'Star';
    final starIcon =
        _isStarred == true ? Icons.star : Icons.star_border;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Repo name header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.source_outlined, size: 20, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _fullName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Copy URL
          _MenuItem(
            icon: Icons.link,
            label: '复制链接',
            onTap: _copyUrl,
          ),
          // Copy name
          _MenuItem(
            icon: Icons.content_copy_outlined,
            label: '复制仓库名',
            onTap: _copyName,
          ),
          // Star / Unstar
          if (_isLoggedIn && _owner.isNotEmpty)
            _MenuItem(
              icon: starIcon,
              label: _isStarred == null ? '加载中…' : starLabel,
              trailing: _starLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: (_isStarred == null || _starLoading)
                  ? null
                  : _toggleStar,
            ),
          // Open in browser
          _MenuItem(
            icon: Icons.open_in_browser_outlined,
            label: '在浏览器中打开',
            onTap: _openInBrowser,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Menu item ─────────────────────────────────────────────────────────────────

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 15, color: cs.onSurface),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
