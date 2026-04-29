import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/github_api_client.dart';
import '../../models/user.dart';

/// Followers or Following list — mirrors HarmonyOS SocialListView.
/// [type] should be 'followers' or 'following'.
class SocialListPage extends StatefulWidget {
  const SocialListPage({
    super.key,
    required this.username,
    required this.type,
  });
  final String username;
  final String type; // 'followers' | 'following'

  @override
  State<SocialListPage> createState() => _SocialListPageState();
}

class _SocialListPageState extends State<SocialListPage> {
  final _api = GitHubApiClient.instance;

  List<GithubUser> _users = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String _error = '';

  bool get _isFollowers => widget.type == 'followers';
  String get _title => _isFollowers ? '粉丝' : '正在关注';

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

    final result = _isFollowers
        ? await _api.getUserFollowers(widget.username, page: _page, perPage: 30)
        : await _api.getUserFollowing(widget.username, page: _page, perPage: 30);

    if (!mounted) return;

    if (result.isSuccess) {
      final items = result.data ?? [];
      setState(() {
        _loading = false;
        if (refresh) {
          _users = items;
        } else {
          _users = [..._users, ...items];
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
        title: Text(
          '${widget.username} 的$_title',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: _loading && _users.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty && _users.isEmpty
              ? _ErrorView(
                  message: _error,
                  onRetry: () => _load(refresh: true),
                )
              : _users.isEmpty
                  ? _EmptyView(
                      message: _isFollowers ? '暂无粉丝' : '暂无关注')
                  : RefreshIndicator(
                      onRefresh: () => _load(refresh: true),
                      child: ListView.separated(
                        itemCount: _users.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (context, i) {
                          if (i >= _users.length) {
                            _load();
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                  child: CircularProgressIndicator()),
                            );
                          }
                          return _UserTile(
                            user: _users[i],
                            onTap: () =>
                                context.push('/user/${_users[i].login}'),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ── User tile ─────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onTap});
  final GithubUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: user.avatarUrl,
                width: 40,
                height: 40,
                placeholder: (_, __) => Container(
                    width: 40,
                    height: 40,
                    color: cs.surfaceContainerHighest),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.account_circle, size: 40),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name.isNotEmpty ? user.name : user.login,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    user.login,
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  if (user.bio.isNotEmpty)
                    Text(
                      user.bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),
                ],
              ),
            ),
            if (user.publicRepos > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Column(
                  children: [
                    const Icon(Icons.book_outlined, size: 13),
                    Text('${user.publicRepos}',
                        style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
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

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message),
          ],
        ),
      );
}
