import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/github_api_client.dart';
import '../../components/feedback/cache_warning_banner.dart';
import '../../components/repository/repo_context_menu.dart';
import '../../components/repository/repository_activity_sparkline.dart';
import '../../models/repository.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/repo_metadata_style.dart';

/// Full repository list for the authenticated user (or any public user).
///
/// Supports:
/// - Infinite scroll pagination
/// - Language filter chips
/// - Pull-to-refresh
///
/// Mirrors HarmonyOS `UserRepositoriesView.ets`.
class UserRepositoriesPage extends StatefulWidget {
  const UserRepositoriesPage({
    super.key,

    /// When null, fetches the authenticated user's repos (including private).
    this.username,
  });
  final String? username;

  @override
  State<UserRepositoriesPage> createState() => _UserRepositoriesPageState();
}

class _UserRepositoriesPageState extends State<UserRepositoriesPage> {
  final _api = GitHubApiClient.instance;
  final _scrollController = ScrollController();

  List<Repository> _all = [];
  List<Repository> _filtered = [];
  List<String> _languages = ['All'];
  String _selectedLanguage = 'All';

  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String _error = '';

  bool get _isSelf =>
      widget.username == null ||
      widget.username == AuthService.instance.currentUser?.login;

  String get _displayTitle =>
      widget.username != null ? '${widget.username} 的仓库' : '我的仓库';

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_loading && _hasMore) _load();
    }
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

    final result = _isSelf
        ? await _api.getUserRepositories(page: _page, perPage: 30)
        : await _api.getUserPublicRepositories(
            widget.username!,
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
          _all = items;
        } else {
          _all = [..._all, ...items];
        }
        _hasMore = items.length >= 30;
        _page++;
        _updateLanguages();
        _applyFilter();
      });
    } else {
      setState(() {
        _loading = false;
        _error = result.message ?? '加载失败';
      });
    }
  }

  void _updateLanguages() {
    final langs = <String>{'All'};
    for (final r in _all) {
      if (r.language.isNotEmpty) langs.add(r.language);
    }
    _languages = langs.toList();
  }

  void _applyFilter() {
    if (_selectedLanguage == 'All') {
      _filtered = List.of(_all);
    } else {
      _filtered = _all.where((r) => r.language == _selectedLanguage).toList();
    }
  }

  void _selectLanguage(String lang) {
    setState(() {
      _selectedLanguage = lang;
      _applyFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_displayTitle),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Language filter chips
            if (_languages.length > 1)
              SliverToBoxAdapter(
                child: _LanguageFilterBar(
                  languages: _languages,
                  selected: _selectedLanguage,
                  onSelect: _selectLanguage,
                ),
              ),

            // Error banner
            if (_error.isNotEmpty)
              SliverToBoxAdapter(child: CacheWarningBanner(message: _error)),

            // Empty state (after initial load)
            if (!_loading && _all.isEmpty && _error.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('暂无仓库')),
              ),

            // Repository list
            SliverList.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, i) => _RepoTile(repo: _filtered[i]),
            ),

            // Footer: loading indicator or "no more"
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : !_hasMore && _all.isNotEmpty
                        ? Center(
                            child: Text(
                              '共 ${_all.length} 个仓库',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 12),
                            ),
                          )
                        : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Language filter bar ───────────────────────────────────────────────────────

class _LanguageFilterBar extends StatelessWidget {
  const _LanguageFilterBar({
    required this.languages,
    required this.selected,
    required this.onSelect,
  });
  final List<String> languages;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: languages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final lang = languages[i];
          final isSelected = lang == selected;
          return GestureDetector(
            onTap: () => onSelect(lang),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? cs.primary : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                lang,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? cs.onPrimary : cs.onSurface,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Repository tile ───────────────────────────────────────────────────────────

class _RepoTile extends StatelessWidget {
  const _RepoTile({required this.repo});
  final Repository repo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final metadataColor = repoMetadataColor(cs);
    final langColor = repo.language.isNotEmpty
        ? _hexToColor(Constants.getLanguageColor(repo.language))
        : null;
    final owner = repo.owner?.login ?? '';

    return InkWell(
      onTap: () =>
          context.push('/repository/${repo.owner?.login ?? ''}/${repo.name}'),
      onLongPress: () => showRepoContextMenu(context, repo),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Repo name + private badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          repo.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      ),
                      if (repo.private)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: cs.outlineVariant),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('Private',
                              style: TextStyle(
                                  fontSize: 10, color: cs.onSurfaceVariant)),
                        ),
                    ],
                  ),

                  // Description
                  if (repo.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      repo.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          height: 1.4),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Stats row
                  Row(
                    children: [
                      if (repo.language.isNotEmpty) ...[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: langColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            repo.language,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(fontSize: 12, color: metadataColor),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Icon(Icons.star_border, size: 14, color: metadataColor),
                      const SizedBox(width: 2),
                      Text('${repo.stargazersCount}',
                          style: TextStyle(fontSize: 12, color: metadataColor)),
                      const SizedBox(width: 12),
                      Icon(Icons.call_split, size: 14, color: metadataColor),
                      const SizedBox(width: 2),
                      Text('${repo.forksCount}',
                          style: TextStyle(fontSize: 12, color: metadataColor)),
                    ],
                  ),
                ],
              ),
            ),
            if (owner.isNotEmpty) ...[
              const SizedBox(width: 12),
              RepositoryActivitySparkline(
                owner: owner,
                repo: repo.name,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Color? _hexToColor(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return null;
    }
  }
}
