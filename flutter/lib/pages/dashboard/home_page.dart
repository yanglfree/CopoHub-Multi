import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/github_api_client.dart';
import '../../components/feedback/cache_warning_banner.dart';
import '../../components/repository/repo_context_menu.dart';
import '../../components/repository/repository_activity_sparkline.dart';
import '../../components/skeleton/repo_list_skeleton.dart';
import '../../l10n/app_localizations.dart';
import '../../models/repository.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/repo_metadata_style.dart';

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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          l10n.home,
          style: const TextStyle(fontWeight: FontWeight.w700),
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
                  // Flutter-OH does not support Color.withValues yet.
                  // ignore: deprecated_member_use
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
          tabs: [
            Tab(text: l10n.myRepositories),
            Tab(text: l10n.starredRepositories),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _UserReposTab(username: _currentUser?.login ?? ''),
          _StarredReposTab(username: _currentUser?.login ?? ''),
        ],
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
        _error = result.cacheWarning ?? '';
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
        _error = result.message ?? AppLocalizations.of(context).loadFailed;
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
    final l10n = AppLocalizations.of(context);
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
                      Text(l10n.filterRepositories,
                          style: const TextStyle(
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
                  Text(l10n.visibility,
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
                      _VisibilityFilter.all => (
                          l10n.visibilityAll,
                          l10n.visibilityAllDescription
                        ),
                      _VisibilityFilter.public => (
                          l10n.visibilityPublic,
                          l10n.visibilityPublicDescription
                        ),
                      _VisibilityFilter.private => (
                          l10n.visibilityPrivate,
                          l10n.visibilityPrivateDescription
                        ),
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
    final l10n = AppLocalizations.of(context);

    if (_loading && _allRepos.isEmpty) {
      return const RepoListSkeleton();
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
        key: const PageStorageKey<String>('home-user-repos'),
        slivers: [
          // ── Header row: 全部仓库 + 筛选 ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Text(
                    l10n.allRepositories,
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
                          Text(l10n.filter,
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
          if (_error.isNotEmpty)
            SliverToBoxAdapter(child: CacheWarningBanner(message: _error)),
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
                      onTap: () => setState(() => _selectedLanguage = lang),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? cs.primary : Colors.transparent,
                          border: Border.all(
                            color: selected ? cs.primary : cs.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          lang,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color:
                                selected ? Colors.white : cs.onSurfaceVariant,
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
                      const Divider(height: 1, indent: 16, endIndent: 16),
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
        _error = result.cacheWarning ?? '';
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
        _error = result.message ?? AppLocalizations.of(context).loadFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading && _repos.isEmpty) {
      return const RepoListSkeleton();
    }
    if (_error.isNotEmpty && _repos.isEmpty) {
      return _ErrorView(
          message: _error, onRetry: () => _loadRepos(refresh: true));
    }
    return RefreshIndicator(
      onRefresh: () => _loadRepos(refresh: true),
      child: CustomScrollView(
        key: const PageStorageKey<String>('home-starred-repos'),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          if (_error.isNotEmpty)
            SliverToBoxAdapter(child: CacheWarningBanner(message: _error)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (i >= _repos.length) {
                  if (_hasMore) _loadRepos();
                  return _hasMore ? const _LoadMoreIndicator() : null;
                }
                return Column(
                  children: [
                    _StarredRepoTile(repo: _repos[i]),
                    if (i < _repos.length - 1)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                );
              },
              childCount: _repos.length + (_hasMore ? 1 : 0),
            ),
          ),
        ],
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
    final l10n = AppLocalizations.of(context);
    final owner = repo.owner?.login ?? '';
    final updatedText = _updatedTimeAgo(
        l10n, repo.pushedAt.isNotEmpty ? repo.pushedAt : repo.updatedAt);
    return InkWell(
      onTap: () => context.push(
          '/repository/${repo.owner?.login ?? ''}/${repo.name}',
          extra: repo),
      onLongPress: () => showRepoContextMenu(context, repo),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
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
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                if (owner.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 76,
                    child: Opacity(
                      opacity: 0.68,
                      child: RepositoryActivitySparkline(
                        owner: owner,
                        repo: repo.name,
                        width: 76,
                        height: 30,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            _RepoMetadata(
              repo: repo,
              updatedText: updatedText,
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
    final l10n = AppLocalizations.of(context);
    final metadataColor = repoMetadataColor(cs);
    return InkWell(
      onTap: () => context.push(
          '/repository/${repo.owner?.login ?? ''}/${repo.name}',
          extra: repo),
      onLongPress: () => showRepoContextMenu(context, repo),
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
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ],
            if (repo.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                repo.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
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
                      style: TextStyle(fontSize: 12, color: metadataColor)),
                  const SizedBox(width: 12),
                ],
                if (repo.stargazersCount > 0) ...[
                  Icon(Icons.star_border, size: 13, color: metadataColor),
                  const SizedBox(width: 2),
                  Text(_fmt(repo.stargazersCount),
                      style: TextStyle(fontSize: 12, color: metadataColor)),
                  const SizedBox(width: 10),
                ],
                if (repo.forksCount > 0) ...[
                  Icon(Icons.fork_right, size: 13, color: metadataColor),
                  const SizedBox(width: 2),
                  Text(_fmt(repo.forksCount),
                      style: TextStyle(fontSize: 12, color: metadataColor)),
                  const SizedBox(width: 10),
                ],
                const Spacer(),
                Text(
                  _updatedTimeAgo(
                      l10n,
                      repo.pushedAt.isNotEmpty
                          ? repo.pushedAt
                          : repo.updatedAt),
                  style: TextStyle(fontSize: 12, color: metadataColor),
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

class _RepoMetadata extends StatelessWidget {
  const _RepoMetadata({
    required this.repo,
    required this.updatedText,
  });

  final Repository repo;
  final String updatedText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final licenseText = _licenseText(repo.license);
    final metadataColor = repoMetadataColor(cs);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxItemWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
        return Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (repo.language.isNotEmpty)
              _RepoMetadataItem(
                tooltip: l10n.language,
                icon: _LanguageDot(language: repo.language),
                text: repo.language,
                color: metadataColor,
                maxWidth: maxItemWidth,
              ),
            _RepoMetadataItem(
              tooltip: l10n.stars,
              icon: Icon(Icons.star_border, size: 13, color: metadataColor),
              text: _fmt(repo.stargazersCount),
              color: metadataColor,
              maxWidth: maxItemWidth,
            ),
            if (licenseText.isNotEmpty)
              _RepoMetadataItem(
                tooltip: l10n.license,
                icon: Icon(Icons.balance, size: 13, color: metadataColor),
                text: licenseText,
                color: metadataColor,
                maxWidth: maxItemWidth,
              ),
            if (updatedText.isNotEmpty)
              _RepoMetadataItem(
                tooltip: l10n.updated,
                text: updatedText,
                color: metadataColor,
                maxWidth: maxItemWidth,
              ),
          ],
        );
      },
    );
  }

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  static String _licenseText(RepoLicense? license) {
    if (license == null) return '';
    final raw = license.name.isNotEmpty ? license.name : license.spdxId;
    final normalized = raw.toLowerCase();

    if (normalized.contains('apache')) return 'Apache 2.0';
    if (normalized == 'mit' || normalized.contains('mit license')) {
      return 'MIT';
    }
    if (normalized.contains('gnu affero') || normalized.contains('agpl')) {
      return 'AGPL v3';
    }
    if (normalized.contains('gnu lesser') || normalized.contains('lgpl')) {
      return normalized.contains('2.1') ? 'LGPL v2.1' : 'LGPL v3';
    }
    if (normalized.contains('gnu general public') ||
        normalized.contains('gpl')) {
      if (normalized.contains('2.0') || normalized.contains('v2')) {
        return 'GPL v2';
      }
      return 'GPL v3';
    }
    if (normalized.contains('mozilla') || normalized.contains('mpl')) {
      return 'MPL 2.0';
    }
    if (normalized.contains('bsd 3') || normalized.contains('3-clause')) {
      return 'BSD 3-Clause';
    }
    if (normalized.contains('bsd 2') || normalized.contains('2-clause')) {
      return 'BSD 2-Clause';
    }
    if (normalized.contains('unlicense')) return 'Unlicense';

    return raw;
  }
}

class _RepoMetadataItem extends StatelessWidget {
  const _RepoMetadataItem({
    required this.tooltip,
    required this.text,
    required this.color,
    required this.maxWidth,
    this.icon,
  });

  final String tooltip;
  final Widget? icon;
  final String text;
  final Color color;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(fontSize: 12, color: color);
    final textMaxWidth = maxWidth - (icon == null ? 0 : 17);

    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 4),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: textMaxWidth),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageDot extends StatelessWidget {
  const _LanguageDot({required this.language});

  final String language;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: Color(int.tryParse(Constants.getLanguageColor(language)
                .replaceFirst('#', '0xFF')) ??
            0xFF8b949e),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _updatedTimeAgo(AppLocalizations l10n, String isoDate) {
  if (isoDate.isEmpty) return '';
  final dt = DateTime.tryParse(isoDate);
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt.toLocal());
  final relativeTime = diff.inMinutes < 1
      ? l10n.justNow
      : diff.inHours < 1
          ? l10n.minutesAgo(diff.inMinutes)
          : diff.inDays < 1
              ? l10n.hoursAgo(diff.inHours)
              : diff.inDays < 30
                  ? l10n.daysAgo(diff.inDays)
                  : diff.inDays < 365
                      ? l10n.monthsAgo((diff.inDays / 30).floor())
                      : l10n.yearsAgo((diff.inDays / 365).floor());
  return l10n.updatedAgo(relativeTime);
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
              OutlinedButton(
                  onPressed: onRetry,
                  child: Text(AppLocalizations.of(context).retry)),
            ],
          ),
        ),
      );
}
