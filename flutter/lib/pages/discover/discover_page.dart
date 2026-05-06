import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/github_api_client.dart';
import '../../models/repository.dart';
import '../../components/skeleton/repo_list_skeleton.dart';
import '../../utils/constants.dart';
import '../../l10n/app_localizations.dart';

/// "Discover" tab — Popular / Latest repos from GitHub search.
/// Mirrors HarmonyOS DiscoverView.
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _nestedKey = GlobalKey<NestedScrollViewState>();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tab.indexIsChanging) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final innerCtrl = _nestedKey.currentState?.innerController;
      if (innerCtrl != null && innerCtrl.hasClients) {
        innerCtrl.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: NestedScrollView(
        key: _nestedKey,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            forceElevated: innerBoxIsScrolled,
            title: Text(l10n.discoverTitle,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: l10n.search,
                onPressed: () => context.push('/search'),
              ),
            ],
            bottom: TabBar(
              controller: _tab,
              tabs: [
                Tab(text: l10n.popular),
                Tab(text: l10n.latest),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: const [
            _RepoSearchTab(query: 'stars:>1000', sort: 'stars', label: 'Popular'),
            _RepoSearchTab(query: 'stars:>10', sort: 'updated', label: 'Latest'),
          ],
        ),
      ),
    );
  }
}

// ── Search-backed repo list tab ───────────────────────────────────────────────

class _RepoSearchTab extends StatefulWidget {
  const _RepoSearchTab({
    required this.query,
    required this.sort,
    required this.label,
  });
  final String query;
  final String sort;
  final String label;

  @override
  State<_RepoSearchTab> createState() => _RepoSearchTabState();
}

class _RepoSearchTabState extends State<_RepoSearchTab>
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

    final result = await _api.searchRepositories(
      widget.query,
      sort: widget.sort,
      page: _page,
      perPage: 30,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final data = result.data ?? {};
      final items = ((data['items'] as List<dynamic>?) ?? [])
          .map((e) => Repository.fromJson(e as Map<String, dynamic>))
          .toList();
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
      return _ErrorView(message: _error, onRetry: () => _load(refresh: true));
    }
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _repos.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _repos.length) {
            _load();
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Column(
            children: [
              _DiscoverRepoCard(repo: _repos[i]),
              if (i < _repos.length - 1)
                const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        },
      ),
    );
  }
}

// ── Repo card ─────────────────────────────────────────────────────────────────

class _DiscoverRepoCard extends StatelessWidget {
  const _DiscoverRepoCard({required this.repo});
  final Repository repo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => context.push('/repository/${repo.owner?.login}/${repo.name}',
          extra: repo),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${repo.owner?.login}/${repo.name}',
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 12),
                ],
                if (repo.stargazersCount > 0) ...[
                  Icon(Icons.star_border, size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text(_fmt(repo.stargazersCount),
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 10),
                ],
                if (repo.forksCount > 0) ...[
                  Icon(Icons.fork_right, size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text(_fmt(repo.forksCount),
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

// ── Shared helpers ────────────────────────────────────────────────────────────

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
                child: Text(AppLocalizations.of(context).retry),
              ),
            ],
          ),
        ),
      );
}
