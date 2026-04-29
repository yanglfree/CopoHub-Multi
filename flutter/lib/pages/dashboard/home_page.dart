import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/github_api_client.dart';
import '../../models/repository.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';

/// The "首页" (Home) tab — user repos + starred repos.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  GithubUser? get _currentUser => AuthService.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            forceElevated: innerBoxIsScrolled,
            title: const Text(
              '首页',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => context.push('/repository/new'),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add, color: cs.primary, size: 22),
                  ),
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '我的仓库'),
                Tab(text: 'Star 仓库'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _UserReposTab(username: _currentUser?.login ?? ''),
            _StarredReposTab(username: _currentUser?.login ?? ''),
          ],
        ),
      ),
    );
  }
}

// ── User repos tab ────────────────────────────────────────────────────────────

enum _VisibilityFilter { all, public, private }

class _UserReposTab extends StatefulWidget {
  const _UserReposTab({required this.username});
  final String username;

  @override
  State<_UserReposTab> createState() => _UserReposTabState();
}

class _UserReposTabState extends State<_UserReposTab>
    with AutomaticKeepAliveClientMixin {
  final _api = GitHubApiClient.instance;
  List<Repository> _allRepos = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String _error = '';

  String _selectedLanguage = 'All';
  _VisibilityFilter _visibility = _VisibilityFilter.all;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadRepos();
  }

  Future<void> _loadRepos({bool refresh = false}) async {
    if (_loading) return;
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }
    setState(() {
      _loading = true;
      _error = '';
    });

    final result = await _api.getUserRepositories(page: _page, perPage: 30);

    if (!mounted) return;

    if (result.isSuccess) {
      final items = result.data ?? [];
      setState(() {
        _loading = false;
        if (refresh) {
          _allRepos = items;
        } else {
          _allRepos = [..._allRepos, ...items];
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

  List<String> get _languages {
    final langs = _allRepos
        .map((r) => r.language)
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...langs];
  }

  List<Repository> get _filtered {
    return _allRepos.where((r) {
      final langMatch =
          _selectedLanguage == 'All' || r.language == _selectedLanguage;
      final visMatch = switch (_visibility) {
        _VisibilityFilter.all => true,
        _VisibilityFilter.public => !r.private,
        _VisibilityFilter.private => r.private,
      };
      return langMatch && visMatch;
    }).toList();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('筛选仓库',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('可见性',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  ...[
                    _VisibilityFilter.all,
                    _VisibilityFilter.public,
                    _VisibilityFilter.private,
                  ].map((v) {
                    final (label, desc) = switch (v) {
                      _VisibilityFilter.all => ('全部', '公开和私有仓库'),
                      _VisibilityFilter.public => ('公开', '所有人可见的仓库'),
                      _VisibilityFilter.private => ('私有', '仅你和协作者可见的仓库'),
                    };
                    final selected = _visibility == v;
                    return Column(
                      children: [
                        InkWell(
                          onTap: () {
                            setSheetState(() {});
                            setState(() => _visibility = v);
                            Navigator.pop(ctx);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(label,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 2),
                                      Text(desc,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  Icon(Icons.check,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      size: 20),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    if (_loading && _allRepos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty && _allRepos.isEmpty) {
      return _ErrorView(
          message: _error, onRetry: () => _loadRepos(refresh: true));
    }

    final filtered = _filtered;
    final langs = _languages;

    return RefreshIndicator(
      onRefresh: () => _loadRepos(refresh: true),
      child: CustomScrollView(
        slivers: [
          // ── Header row: 全部仓库 + 筛选 ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Text(
                    '全部仓库',
                    style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _showFilterSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: cs.outlineVariant),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.filter_list,
                              size: 15, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text('筛选',
                              style: TextStyle(
                                  fontSize: 13, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Language chips ────────────────────────────────────────────────
          if (langs.length > 1)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: langs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final lang = langs[i];
                    final selected = lang == _selectedLanguage;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedLanguage = lang),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? cs.primary : Colors.transparent,
                          border: Border.all(
                            color:
                                selected ? cs.primary : cs.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          lang,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? Colors.white
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          // ── Repo list ─────────────────────────────────────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (i >= filtered.length) {
                  if (_hasMore) _loadRepos();
                  return _hasMore ? const _LoadMoreIndicator() : null;
                }
                return Column(
                  children: [
                    _MyRepoTile(repo: filtered[i]),
                    if (i < filtered.length - 1)
                      const Divider(
                          height: 1, indent: 16, endIndent: 16),
                  ],
                );
              },
              childCount: filtered.length + (_hasMore ? 1 : 0),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Starred repos tab ─────────────────────────────────────────────────────────

class _StarredReposTab extends StatefulWidget {
  const _StarredReposTab({required this.username});
  final String username;

  @override
  State<_StarredReposTab> createState() => _StarredReposTabState();
}

class _StarredReposTabState extends State<_StarredReposTab>
    with AutomaticKeepAliveClientMixin {
  final _api = GitHubApiClient.instance;
  List<Repository> _repos = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String _error = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadRepos();
  }

  Future<void> _loadRepos({bool refresh = false}) async {
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
      username: widget.username.isEmpty ? null : widget.username,
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
    super.build(context);
    if (_loading && _repos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty && _repos.isEmpty) {
      return _ErrorView(
          message: _error, onRetry: () => _loadRepos(refresh: true));
    }
    return RefreshIndicator(
      onRefresh: () => _loadRepos(refresh: true),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _repos.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, i) {
          if (i >= _repos.length) {
            _loadRepos();
            return const _LoadMoreIndicator();
          }
          return _StarredRepoTile(repo: _repos[i]);
        },
      ),
    );
  }
}

// ── Repo tiles ────────────────────────────────────────────────────────────────

class _MyRepoTile extends StatelessWidget {
  const _MyRepoTile({required this.repo});
  final Repository repo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => context.push(
          '/repository/${repo.owner?.login ?? ''}/${repo.name}',
          extra: repo),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    repo.name,
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (repo.private)
                  Icon(Icons.lock_outline,
                      size: 16, color: cs.onSurfaceVariant),
              ],
            ),
            if (repo.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                repo.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (repo.language.isNotEmpty) ...[
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: Color(int.tryParse(
                              Constants.getLanguageColor(repo.language)
                                  .replaceFirst('#', '0xFF')) ??
                          0xFF8b949e),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(repo.language,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                ],
                const Spacer(),
                Text(
                  _timeAgo(repo.pushedAt.isNotEmpty
                      ? repo.pushedAt
                      : repo.updatedAt),
                  style:
                      TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StarredRepoTile extends StatelessWidget {
  const _StarredRepoTile({required this.repo});
  final Repository repo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => context.push(
          '/repository/${repo.owner?.login ?? ''}/${repo.name}',
          extra: repo),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              repo.name,
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (repo.owner?.login.isNotEmpty == true) ...[
              const SizedBox(height: 2),
              Text(
                repo.owner!.login,
                style:
                    TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ],
            if (repo.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                repo.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (repo.language.isNotEmpty) ...[
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: Color(int.tryParse(
                              Constants.getLanguageColor(repo.language)
                                  .replaceFirst('#', '0xFF')) ??
                          0xFF8b949e),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(repo.language,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 12),
                ],
                if (repo.stargazersCount > 0) ...[
                  Icon(Icons.star_border,
                      size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text(_fmt(repo.stargazersCount),
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 10),
                ],
                if (repo.forksCount > 0) ...[
                  Icon(Icons.fork_right,
                      size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text(_fmt(repo.forksCount),
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 10),
                ],
                const Spacer(),
                Text(
                  _timeAgo(repo.pushedAt.isNotEmpty
                      ? repo.pushedAt
                      : repo.updatedAt),
                  style:
                      TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
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

// ── Helpers ───────────────────────────────────────────────────────────────────

String _timeAgo(String isoDate) {
  if (isoDate.isEmpty) return '';
  final dt = DateTime.tryParse(isoDate);
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt.toLocal());
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
  if (diff.inDays < 1) return '${diff.inHours} 小时前';
  if (diff.inDays < 30) return '${diff.inDays} 天前';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} 个月前';
  return '${(diff.inDays / 365).floor()} 年前';
}

class _LoadMoreIndicator extends StatelessWidget {
  const _LoadMoreIndicator();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      );
}
