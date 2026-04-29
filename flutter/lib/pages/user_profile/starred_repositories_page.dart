import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/github_api_client.dart';
import '../../models/repository.dart';
import '../../utils/constants.dart';

/// Starred repositories list for a given [username].
/// Mirrors HarmonyOS StarredRepositoriesTabView.
class StarredRepositoriesPage extends StatefulWidget {
  const StarredRepositoriesPage({
    super.key,
    required this.username,
  });
  final String username;

  @override
  State<StarredRepositoriesPage> createState() =>
      _StarredRepositoriesPageState();
}

class _StarredRepositoriesPageState extends State<StarredRepositoriesPage> {
  final _api = GitHubApiClient.instance;

  List<Repository> _repos = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }
    setState(() {
      _loading = true;
      _error = '';
    });

    final result = await _api.getUserStarredRepositories(
      username: widget.username,
      page: _page,
      perPage: 30,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final items = result.data ?? [];
      setState(() {
        _loading = false;
        if (refresh) {
          _repos = items;
        } else {
          _repos = [..._repos, ...items];
        }
        _hasMore = items.length >= 30;
        _page++;
      });
    } else {
      setState(() {
        _loading = false;
        _error = result.message ?? '加载失败';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.username} 的 Stars'),
      ),
      body: _loading && _repos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty && _repos.isEmpty
              ? _ErrorView(message: _error, onRetry: () => _load(refresh: true))
              : _repos.isEmpty
                  ? const _EmptyView()
                  : RefreshIndicator(
                      onRefresh: () => _load(refresh: true),
                      child: ListView.separated(
                        itemCount: _repos.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 16),
                        itemBuilder: (context, i) {
                          if (i >= _repos.length) {
                            if (_hasMore && !_loading) _load();
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                  child: CircularProgressIndicator()),
                            );
                          }
                          final repo = _repos[i];
                          return _RepoTile(
                            repo: repo,
                            onTap: () => context.push(
                                '/repository/${repo.owner?.login ?? widget.username}/${repo.name}'),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ── Repo tile ─────────────────────────────────────────────────────────────────

class _RepoTile extends StatelessWidget {
  const _RepoTile({required this.repo, required this.onTap});
  final Repository repo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Owner avatar
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: repo.owner?.avatarUrl ?? '',
                width: 32,
                height: 32,
                placeholder: (_, __) =>
                    Container(width: 32, height: 32, color: cs.surfaceContainerHighest),
                errorWidget: (_, __, ___) =>
                    Icon(Icons.account_circle, size: 32, color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // owner/repo
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                          fontSize: 14, color: cs.primary, fontWeight: FontWeight.w600),
                      children: [
                        if (repo.owner?.login != null)
                          TextSpan(
                            text: '${repo.owner!.login}/',
                            style: const TextStyle(fontWeight: FontWeight.w400),
                          ),
                        TextSpan(text: repo.name),
                      ],
                    ),
                  ),
                  if (repo.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      repo.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 6),
                  // stars / language / fork indicator
                  Row(
                    children: [
                      if (repo.language.isNotEmpty) ...[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(int.tryParse(
                                    Constants.getLanguageColor(repo.language)
                                        .replaceFirst('#', '0xFF')) ??
                                0xFF8B949E),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(repo.language,
                            style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 12),
                      ],
                      const Icon(Icons.star_border, size: 13),
                      const SizedBox(width: 2),
                      Text('${repo.stargazersCount}',
                          style: const TextStyle(fontSize: 11)),
                      if (repo.fork) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.fork_right,
                            size: 13, color: cs.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Text('Fork',
                            style: TextStyle(
                                fontSize: 11, color: cs.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty / Error views ───────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_border,
              size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          const Text('还没有 Star 的仓库'),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
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
}
