import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/github_api_client.dart';
import '../../components/repository/repo_context_menu.dart';
import '../../models/repository.dart';
import '../../models/user.dart';
import '../../utils/constants.dart';

/// Search repos and users — mirrors HarmonyOS SearchView.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  final _api = GitHubApiClient.instance;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  late final TabController _tab;

  // Repos
  List<Repository> _repos = [];
  bool _reposLoading = false;
  bool _reposHasMore = true;
  int _reposPage = 1;
  String _reposError = '';

  // Users
  List<GithubUser> _users = [];
  bool _usersLoading = false;
  bool _usersHasMore = true;
  int _usersPage = 1;
  String _usersError = '';

  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _tab.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _query => _controller.text.trim();

  void _onSubmit(String _) => _search();

  void _search() {
    if (_query.isEmpty) return;
    setState(() {
      _hasSearched = true;
      _repos = [];
      _reposPage = 1;
      _reposHasMore = true;
      _reposError = '';
      _users = [];
      _usersPage = 1;
      _usersHasMore = true;
      _usersError = '';
    });
    _loadRepos();
    _loadUsers();
  }

  Future<void> _loadRepos({bool more = false}) async {
    if (_reposLoading || (!_reposHasMore && more)) return;
    setState(() {
      _reposLoading = true;
      _reposError = '';
    });

    final page = more ? _reposPage : 1;
    final result = await _api.searchRepositories(
      _query,
      sort: 'stars',
      page: page,
      perPage: 30,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final items = (result.data?['items'] as List<dynamic>? ?? [])
          .map((e) => Repository.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _reposLoading = false;
        if (more) {
          _repos = [..._repos, ...items];
        } else {
          _repos = items;
        }
        _reposHasMore = items.length >= 30;
        _reposPage = page + 1;
      });
    } else {
      setState(() {
        _reposLoading = false;
        _reposError = result.message ?? '搜索失败';
      });
    }
  }

  Future<void> _loadUsers({bool more = false}) async {
    if (_usersLoading || (!_usersHasMore && more)) return;
    setState(() {
      _usersLoading = true;
      _usersError = '';
    });

    final page = more ? _usersPage : 1;
    final result = await _api.searchUsers(
      _query,
      sort: 'followers',
      page: page,
      perPage: 30,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final items = (result.data?['items'] as List<dynamic>? ?? [])
          .map((e) => GithubUser.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _usersLoading = false;
        if (more) {
          _users = [..._users, ...items];
        } else {
          _users = items;
        }
        _usersHasMore = items.length >= 30;
        _usersPage = page + 1;
      });
    } else {
      setState(() {
        _usersLoading = false;
        _usersError = result.message ?? '搜索失败';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _SearchBar(
          controller: _controller,
          focusNode: _focusNode,
          onSubmit: _onSubmit,
          onClear: () => setState(() {
            _controller.clear();
            _hasSearched = false;
            _repos = [];
            _users = [];
          }),
        ),
        bottom: _hasSearched
            ? TabBar(
                controller: _tab,
                tabs: [
                  Tab(text: '仓库 ${_repos.isNotEmpty ? "(${_repos.length}+)" : ""}'),
                  Tab(text: '用户 ${_users.isNotEmpty ? "(${_users.length}+)" : ""}'),
                ],
              )
            : null,
      ),
      body: !_hasSearched
          ? _SearchHint(onSuggestionTap: (s) {
              _controller.text = s;
              _search();
            })
          : TabBarView(
              controller: _tab,
              children: [
                _ReposResultList(
                  repos: _repos,
                  loading: _reposLoading,
                  error: _reposError,
                  hasMore: _reposHasMore,
                  onLoadMore: () => _loadRepos(more: true),
                  onRetry: _search,
                ),
                _UsersResultList(
                  users: _users,
                  loading: _usersLoading,
                  error: _usersError,
                  hasMore: _usersHasMore,
                  onLoadMore: () => _loadUsers(more: true),
                  onRetry: _search,
                ),
              ],
            ),
    );
  }
}

// ── Search bar widget ─────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onClear,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 12, 6),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmit,
        decoration: InputDecoration(
          hintText: '搜索仓库或用户…',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: ListenableBuilder(
            listenable: controller,
            builder: (_, __) => controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClear,
                  )
                : const SizedBox.shrink(),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          isDense: true,
        ),
      ),
    );
  }
}

// ── Search hint / suggestions ─────────────────────────────────────────────────

class _SearchHint extends StatelessWidget {
  const _SearchHint({required this.onSuggestionTap});
  final void Function(String) onSuggestionTap;

  static const _suggestions = [
    'flutter', 'react', 'vue', 'typescript', 'python',
    'rust', 'golang', 'kubernetes', 'llm', 'next.js',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('热门搜索',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions
                .map((s) => ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 13)),
                      onPressed: () => onSuggestionTap(s),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Repos result list ─────────────────────────────────────────────────────────

class _ReposResultList extends StatelessWidget {
  const _ReposResultList({
    required this.repos,
    required this.loading,
    required this.error,
    required this.hasMore,
    required this.onLoadMore,
    required this.onRetry,
  });
  final List<Repository> repos;
  final bool loading;
  final String error;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading && repos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error.isNotEmpty && repos.isEmpty) {
      return _ErrorView(message: error, onRetry: onRetry);
    }
    if (repos.isEmpty) {
      return const _EmptyView(message: '没有找到相关仓库');
    }

    return ListView.separated(
      itemCount: repos.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, i) {
        if (i >= repos.length) {
          onLoadMore();
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final repo = repos[i];
        final owner = repo.owner?.login ?? '';
        return _RepoTile(
          repo: repo,
          onTap: () => context.push('/repository/$owner/${repo.name}',
              extra: repo),
        );
      },
    );
  }
}

class _RepoTile extends StatelessWidget {
  const _RepoTile({required this.repo, required this.onTap});
  final Repository repo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avatar = repo.owner?.avatarUrl ?? '';

    return InkWell(
      onTap: onTap,
      onLongPress: () => showRepoContextMenu(context, repo),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (avatar.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 10, top: 2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
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
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    repo.fullName,
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (repo.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      repo.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 6),
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
                                0xFF8b949e),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(repo.language,
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 10),
                      ],
                      const Icon(Icons.star_border, size: 13),
                      const SizedBox(width: 2),
                      Text(_fmt(repo.stargazersCount),
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(width: 10),
                      const Icon(Icons.fork_right, size: 13),
                      const SizedBox(width: 2),
                      Text(_fmt(repo.forksCount),
                          style: Theme.of(context).textTheme.bodySmall),
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

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

// ── Users result list ─────────────────────────────────────────────────────────

class _UsersResultList extends StatelessWidget {
  const _UsersResultList({
    required this.users,
    required this.loading,
    required this.error,
    required this.hasMore,
    required this.onLoadMore,
    required this.onRetry,
  });
  final List<GithubUser> users;
  final bool loading;
  final String error;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading && users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error.isNotEmpty && users.isEmpty) {
      return _ErrorView(message: error, onRetry: onRetry);
    }
    if (users.isEmpty) {
      return const _EmptyView(message: '没有找到相关用户');
    }

    return ListView.separated(
      itemCount: users.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 72),
      itemBuilder: (context, i) {
        if (i >= users.length) {
          onLoadMore();
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _UserTile(
          user: users[i],
          onTap: () => context.push('/user/${users[i].login}'),
        );
      },
    );
  }
}

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
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (user.followers > 0)
              Column(
                children: [
                  const Icon(Icons.people_outline, size: 14),
                  Text(_fmt(user.followers),
                      style: const TextStyle(fontSize: 11)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

// ── Shared helpers ────────────────────────────────────────────────────────────

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
            Text(message, textAlign: TextAlign.center),
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
            Icon(Icons.search_off,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message),
          ],
        ),
      );
}
