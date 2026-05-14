import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../components/markdown/markdown_scroll_fix.dart';
import '../../components/repository/branch_tag_picker_bottom_sheet.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/github_api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../models/repository.dart';
import '../../services/share_service.dart';
import '../../utils/constants.dart';
import '../../utils/link_utils.dart';
import 'readme_document.dart';
import 'repository_branch_creator.dart';
import 'repository_paged_list.dart';
import 'repository_refs.dart';

/// Repository detail page — README / 代码 / Issues / Commits / Releases tabs.
class RepositoryPage extends StatefulWidget {
  const RepositoryPage({
    super.key,
    required this.owner,
    required this.repo,
    this.initialRepo,
  });
  final String owner;
  final String repo;

  /// Pre-populated [Repository] passed from the listing page that linked
  /// here. Lets us render the header without waiting on `getRepository`.
  /// We still issue the request in the background to pick up fresh stats.
  final Repository? initialRepo;

  @override
  State<RepositoryPage> createState() => _RepositoryPageState();
}

class _RepositoryPageState extends State<RepositoryPage>
    with SingleTickerProviderStateMixin {
  final _api = GitHubApiClient.instance;

  Repository? _repository;
  bool _loading = true;
  String _error = '';
  bool _isStarred = false;
  bool _isStarUpdating = false;
  int _starCount = 0;
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _tags = [];

  late final TabController _tab;
  late final List<int> _tabScrollResetVersions;
  int _activeTabIndex = 0;
  final GlobalKey<NestedScrollViewState> _nestedScrollKey = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _tabScrollResetVersions = List<int>.filled(_tab.length, 0);
    _tab.addListener(_handleTabChanged);
    if (widget.initialRepo != null) {
      _repository = widget.initialRepo;
      _starCount = widget.initialRepo!.stargazersCount;
      _loading = false;
    }
    _loadRepo();
    _loadBranches();
    _loadTags();
  }

  @override
  void dispose() {
    _tab.removeListener(_handleTabChanged);
    _tab.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tab.index == _activeTabIndex) return;
    setState(() {
      _activeTabIndex = _tab.index;
      _tabScrollResetVersions[_activeTabIndex]++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = _nestedScrollKey.currentState;
      if (state == null) return;
      final outer = state.outerController;
      if (!outer.hasClients) return;
      // Calling jumpTo on the OUTER controller goes through
      // coordinator.jumpTo(unnestOffset(pixels, outerPos)) = coordinator.jumpTo(pixels),
      // which keeps outer at its current position and resets ALL inner positions to 0.
      // Using the inner controller would apply unnestOffset wrongly (value + outerMax),
      // scrolling tab content up by outerMax pixels and causing blank screens.
      outer.jumpTo(outer.position.pixels);
    });
  }

  void _openRepositoryTab(int index) {
    if (index < 0 || index >= _tab.length) return;
    if (_tab.index == index) return;
    _tab.animateTo(index);
  }

  Future<void> _loadRepo() async {
    if (_repository == null) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }

    final results = await Future.wait([
      _api.getRepository(widget.owner, widget.repo),
      _api.checkRepositoryStarred(widget.owner, widget.repo),
    ]);

    if (!mounted) return;

    final repoResult = results[0] as dynamic;
    final starResult = results[1] as dynamic;

    if (repoResult.isSuccess) {
      setState(() {
        _repository = repoResult.data as Repository;
        _starCount = _repository!.stargazersCount;
        _isStarred = (starResult.data as bool?) ?? false;
        _loading = false;
      });
    } else if (_repository == null) {
      setState(() {
        _error = (repoResult.message as String?) ??
            AppLocalizations.of(context).loadFailed;
        _loading = false;
      });
    }
  }

  Future<void> _loadBranches() async {
    final result = await _api.getRepositoryBranches(widget.owner, widget.repo);
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() => _branches = result.data ?? []);
    }
  }

  Future<void> _loadTags() async {
    final result = await _api.getRepositoryTags(widget.owner, widget.repo);
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() => _tags = result.data ?? []);
    }
  }

  void _handleBranchCreated(String name, String sha) {
    setState(() {
      _branches = RepositoryRefs.withCreatedBranch(
        _branches,
        name: name,
        sha: sha,
      );
    });
  }

  Future<void> _toggleStar() async {
    if (_repository == null || _isStarUpdating) return;

    final wasStarred = _isStarred;
    setState(() => _isStarUpdating = true);

    final result = wasStarred
        ? await _api.unstarRepository(widget.owner, widget.repo)
        : await _api.starRepository(widget.owner, widget.repo);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _isStarred = !wasStarred;
        _starCount =
            wasStarred ? (_starCount - 1).clamp(0, 999999999) : _starCount + 1;
        _isStarUpdating = false;
      });
    } else {
      setState(() => _isStarUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? '操作失败，请重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.owner}/${widget.repo}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.owner}/${widget.repo}')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(_error),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _loadRepo, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }

    final repo = _repository!;
    final tabBar = TabBar(
      controller: _tab,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [
        Tab(text: l10n.tabReadme),
        Tab(text: l10n.tabCode),
        Tab(text: l10n.tabIssues),
        Tab(text: l10n.tabCommits),
        Tab(text: l10n.tabReleases),
      ],
    );

    return Scaffold(
      body: NestedScrollView(
        key: _nestedScrollKey,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            forceElevated: innerBoxIsScrolled,
            title: Text(
              '${widget.owner}/${widget.repo}',
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              IconButton(
                key: _shareButtonKey,
                icon: const Icon(Icons.share_outlined),
                tooltip: '分享',
                onPressed: () async {
                  final box = _shareButtonKey.currentContext?.findRenderObject()
                      as RenderBox?;
                  final origin = box != null
                      ? box.localToGlobal(Offset.zero) & box.size
                      : null;
                  try {
                    await ShareService.shareRepository(
                      owner: widget.owner,
                      repo: widget.repo,
                      description: _repository?.description,
                      stars: _repository?.stargazersCount ?? 0,
                      language: _repository?.language,
                      sharePositionOrigin: origin,
                    );
                  } catch (_) {}
                },
              ),
              _StarActionButton(
                isStarred: _isStarred,
                isLoading: _isStarUpdating,
                onPressed: _toggleStar,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: _RepoHeader(
              repo: repo,
              isStarred: _isStarred,
              starCount: _starCount,
              onStar: _toggleStar,
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedTabBarDelegate(tabBar),
          ),
        ],
        body: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: TabBarView(
            controller: _tab,
            children: [
              _ReadmeTab(
                  owner: widget.owner,
                  repo: widget.repo,
                  defaultBranch: repo.defaultBranch,
                  scrollResetVersion: _tabScrollResetVersions[0],
                  isDark: Theme.of(context).brightness == Brightness.dark,
                  onOpenRepositoryTab: _openRepositoryTab),
              _CodeTab(
                  owner: widget.owner,
                  repo: widget.repo,
                  defaultBranch: repo.defaultBranch,
                  branches: _branches,
                  tags: _tags,
                  scrollResetVersion: _tabScrollResetVersions[1],
                  onBranchCreated: _handleBranchCreated),
              _IssuesTab(
                  owner: widget.owner,
                  repo: widget.repo,
                  scrollResetVersion: _tabScrollResetVersions[2]),
              _CommitsTab(
                  owner: widget.owner,
                  repo: widget.repo,
                  defaultBranch: repo.defaultBranch,
                  branches: _branches,
                  tags: _tags,
                  scrollResetVersion: _tabScrollResetVersions[3],
                  onBranchCreated: _handleBranchCreated),
              _ReleasesTab(
                  owner: widget.owner,
                  repo: widget.repo,
                  scrollResetVersion: _tabScrollResetVersions[4]),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinnedTabBarDelegate extends SliverPersistentHeaderDelegate {
  _PinnedTabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    return Material(
      color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      elevation: overlapsContent ? 1 : 0,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}

// ── Repository header ─────────────────────────────────────────────────────────

class _StarActionButton extends StatefulWidget {
  const _StarActionButton({
    required this.isStarred,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isStarred;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  State<_StarActionButton> createState() => _StarActionButtonState();
}

class _StarActionButtonState extends State<_StarActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _StarActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading != widget.isLoading) {
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation() {
    if (widget.isLoading) {
      _controller.repeat();
    } else {
      _controller
        ..stop()
        ..reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetStarred =
        widget.isLoading ? !widget.isStarred : widget.isStarred;
    final tooltip = widget.isLoading
        ? '处理中'
        : widget.isStarred
            ? '取消 Star'
            : 'Star';

    return IconButton(
      tooltip: tooltip,
      onPressed: widget.isLoading ? null : widget.onPressed,
      icon: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = widget.isLoading ? _controller.value : 0.0;
          final pulse = widget.isLoading
              ? 1.0 + 0.16 * math.sin(progress * math.pi)
              : 1.0;
          final rotation =
              widget.isLoading ? math.sin(progress * math.pi * 2) * 0.16 : 0.0;
          final sparkleOpacity =
              widget.isLoading ? math.sin(progress * math.pi).abs() : 0.0;
          final sparkleOffset =
              widget.isLoading ? -2.0 * math.sin(progress * math.pi) : 0.0;

          return SizedBox(
            width: 28,
            height: 28,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: rotation,
                  child: Transform.scale(
                    scale: pulse,
                    child: Icon(
                      targetStarred ? Icons.star : Icons.star_border,
                      color: targetStarred || widget.isStarred
                          ? Colors.amber
                          : null,
                    ),
                  ),
                ),
                if (widget.isLoading)
                  Positioned(
                    top: 1 + sparkleOffset,
                    right: 1,
                    child: Opacity(
                      opacity: sparkleOpacity.clamp(0.0, 1.0),
                      child: const Icon(
                        Icons.star,
                        size: 8,
                        color: Colors.amber,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RepoHeader extends StatelessWidget {
  const _RepoHeader({
    required this.repo,
    required this.isStarred,
    required this.starCount,
    required this.onStar,
  });
  final Repository repo;
  final bool isStarred;
  final int starCount;
  final VoidCallback onStar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avatar = repo.owner?.avatarUrl ?? '';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cs.surfaceContainer, cs.surface],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (avatar.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: avatar,
                      width: 28,
                      height: 28,
                      placeholder: (_, __) => Container(
                          width: 28,
                          height: 28,
                          color: cs.surfaceContainerHighest),
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.account_circle, size: 28),
                    ),
                  ),
                if (avatar.isNotEmpty) const SizedBox(width: 8),
                InkWell(
                  onTap: () => context.push('/user/${repo.owner?.login}'),
                  child: Text(
                    repo.owner?.login ?? '',
                    style: TextStyle(color: cs.primary, fontSize: 14),
                  ),
                ),
                const Text(' / ', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Text(
                    repo.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (repo.private)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outline),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Private',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                  ),
              ],
            ),
            if (repo.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                repo.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _StatChip(
                    icon: Icons.star_border,
                    value: _fmt(starCount),
                    active: isStarred,
                    onTap: onStar),
                const SizedBox(width: 8),
                _StatChip(
                    icon: Icons.fork_right,
                    value: _fmt(repo.forksCount),
                    onTap: null),
                const SizedBox(width: 8),
                if ((repo.language).isNotEmpty)
                  _LanguageBadge(language: repo.language),
              ],
            ),
            if (repo.topics.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...repo.topics.take(8).map(_TopicPill.new),
                  if (repo.topics.length > 8)
                    _TopicPill('+${repo.topics.length - 8}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final String value;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final foreground = active ? cs.primary : cs.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: active ? cs.primary : cs.outlineVariant),
          borderRadius: BorderRadius.circular(18),
          color:
              active ? cs.primaryContainer.withAlpha(96) : cs.surfaceContainer,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? cs.primary : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageBadge extends StatelessWidget {
  const _LanguageBadge({required this.language});
  final String language;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = Color(int.tryParse(
            Constants.getLanguageColor(language).replaceFirst('#', '0xFF')) ??
        0xFF8b949e);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        border: Border.all(color: color.withAlpha(120)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            language,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicPill extends StatelessWidget {
  const _TopicPill(this.topic);
  final String topic;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withAlpha(72),
        border: Border.all(color: cs.primary.withAlpha(64)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        topic,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cs.primary,
        ),
      ),
    );
  }
}

// ── README tab ────────────────────────────────────────────────────────────────

class _ReadmeTab extends StatefulWidget {
  const _ReadmeTab({
    required this.owner,
    required this.repo,
    required this.defaultBranch,
    required this.scrollResetVersion,
    required this.isDark,
    required this.onOpenRepositoryTab,
  });
  final String owner;
  final String repo;
  final String defaultBranch;
  final int scrollResetVersion;
  final bool isDark;
  final ValueChanged<int> onOpenRepositoryTab;

  @override
  State<_ReadmeTab> createState() => _ReadmeTabState();
}

class _ReadmeTabState extends State<_ReadmeTab>
    with AutomaticKeepAliveClientMixin {
  final _api = GitHubApiClient.instance;
  String _readmePath = 'README.md';
  String _downloadUrl = '';
  String _htmlUrl = '';
  bool _loading = true;
  bool _hasError = false;
  String? _markdown;
  List<({ReadmeSection section, GlobalKey? anchorKey})> _readmeSections =
      const [];
  final Map<String, GlobalKey> _anchorKeys = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadReadme();
  }

  @override
  void didUpdateWidget(covariant _ReadmeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.owner != widget.owner ||
        oldWidget.repo != widget.repo ||
        oldWidget.defaultBranch != widget.defaultBranch) {
      _loadReadme();
    }
  }

  Future<void> _loadReadme() async {
    setState(() {
      _loading = true;
      _hasError = false;
      _markdown = null;
      _readmeSections = const [];
      _readmePath = 'README.md';
      _downloadUrl = '';
      _htmlUrl = '';
      _anchorKeys.clear();
    });

    final result = await _api.getRepositoryReadme(
      widget.owner,
      widget.repo,
      ref: widget.defaultBranch,
    );
    if (!mounted) return;

    if (result.isSuccess) {
      final data = result.data;
      final document = ReadmeDocumentParser.parseEncodedContent(
        content: data?['content'] as String? ?? '',
        encoding: (data?['encoding'] as String? ?? 'base64').toLowerCase(),
      );
      if (document != null && document.markdown.trim().isNotEmpty) {
        final sections = _buildRenderSections(document.sections);
        setState(() {
          _readmePath = data?['path'] as String? ?? 'README.md';
          _downloadUrl = data?['download_url'] as String? ?? '';
          _htmlUrl = data?['html_url'] as String? ?? '';
          _markdown = document.markdown;
          _readmeSections = sections;
          _loading = false;
          _hasError = false;
        });
        return;
      }
    }

    setState(() {
      _loading = false;
      _hasError = true;
      _readmeSections = const [];
    });
  }

  List<({ReadmeSection section, GlobalKey? anchorKey})> _buildRenderSections(
    List<ReadmeSection> sections,
  ) {
    _anchorKeys.clear();
    return [
      for (final section in sections)
        (
          section: section,
          anchorKey: section.anchorIds.isEmpty
              ? null
              : _registerSectionAnchors(section.anchorIds),
        ),
    ];
  }

  GlobalKey _registerSectionAnchors(List<String> anchorIds) {
    final key = GlobalKey();
    for (final anchor in anchorIds) {
      if (anchor.isNotEmpty) {
        _anchorKeys.putIfAbsent(anchor, () => key);
      }
    }
    return key;
  }

  ReadmeLinkResolver get _readmeLinkResolver => ReadmeLinkResolver(
        ReadmeLinkContext(
          owner: widget.owner,
          repo: widget.repo,
          defaultBranch: widget.defaultBranch,
          readmePath: _readmePath,
          downloadUrl: _downloadUrl,
          htmlUrl: _htmlUrl,
        ),
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_hasError || _markdown == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.article_outlined, size: 48),
            const SizedBox(height: 12),
            Text(l10n.noReadme),
          ],
        ),
      );
    }

    final sections = _readmeSections;
    final normalStyle = _readmeStyleSheet(theme, widget.isDark);
    final tableStyle = normalStyle.copyWith(
      // IntrinsicColumnWidth lets each column expand to its content width so
      // the table can scroll horizontally without squishing text into narrow
      // columns (the FlexColumnWidth default distributes fixed total width).
      tableColumnWidth: const IntrinsicColumnWidth(),
    );

    Widget buildMarkdown(String data, MarkdownStyleSheet style) =>
        MarkdownScrollFix(
          child: MarkdownBody(
            data: data,
            // selectable:true wraps content in SelectionArea which swallows
            // TapGestureRecognizer events — links become unclickable.
            selectable: false,
            styleSheet: style,
            onTapLink: (text, href, title) {
              if (href == null || href.isEmpty) return;
              final resolver = _readmeLinkResolver;
              final tabIndex = resolver.currentRepositoryTabIndex(href);
              if (tabIndex != null) {
                widget.onOpenRepositoryTab(tabIndex);
                return;
              }
              final anchor = resolver.currentReadmeAnchor(href);
              if (anchor != null) {
                _scrollToAnchor(anchor);
                return;
              }
              final resolved = resolver.resolve(href, forImage: false);
              dispatchLinkAction(context, resolved);
            },
            sizedImageBuilder: (config) {
              final resolved = _readmeLinkResolver.resolve(
                config.uri.toString(),
                forImage: true,
              );
              if (resolved.isEmpty || resolved == 'about:blank') {
                return const SizedBox.shrink();
              }
              if (resolved.endsWith('.svg') ||
                  resolved.contains('badge') ||
                  resolved.contains('shields.io')) {
                return const SizedBox.shrink();
              }
              final mq = MediaQuery.of(context);
              final screenWidth = mq.size.width;
              final dpr = mq.devicePixelRatio;
              // Phone (< 600 dp): constrain to screen width.
              // Pad / large screen: cap at 1080 logical px (or screen width if smaller).
              const kPadBreakpoint = 600.0;
              const kPadMaxWidth = 1080.0;
              final isPhone = screenWidth < kPadBreakpoint;
              final maxDisplayWidth =
                  isPhone ? screenWidth : kPadMaxWidth.clamp(0.0, screenWidth);
              // Cache up to 2× logical px for retina clarity.
              final memWidth = (maxDisplayWidth * dpr * 2).round();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxDisplayWidth),
                  child: CachedNetworkImage(
                    imageUrl: resolved,
                    fit: BoxFit.fitWidth,
                    width: maxDisplayWidth,
                    memCacheWidth: memWidth,
                    placeholder: (_, __) => const SizedBox(height: 1),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              );
            },
          ),
        );

    return SingleChildScrollView(
      key: PageStorageKey<String>(
        'repository-readme-scroll-${widget.owner}/${widget.repo}-${widget.scrollResetVersion}',
      ),
      primary: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final section in sections)
            if (section.section.isTable)
              // Wrap each table in its own horizontal scroll so wide tables
              // don't force text to wrap into unreadably narrow columns.
              KeyedSubtree(
                key: section.anchorKey,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: buildMarkdown(section.section.content, tableStyle),
                ),
              )
            else
              KeyedSubtree(
                key: section.anchorKey,
                child: buildMarkdown(section.section.content, normalStyle),
              ),
        ],
      ),
    );
  }

  MarkdownStyleSheet _readmeStyleSheet(ThemeData theme, bool isDark) {
    final base = MarkdownStyleSheet.fromTheme(theme);
    final fg = isDark ? const Color(0xFFe6edf3) : const Color(0xFF24292f);
    final muted = isDark ? const Color(0xFF8b949e) : const Color(0xFF57606a);
    final border = isDark ? const Color(0xFF30363d) : const Color(0xFFd0d7de);
    final codeBg = isDark ? const Color(0x666e7681) : const Color(0x33afb8c1);
    final preBg = isDark ? const Color(0xFF161b22) : const Color(0xFFf6f8fa);
    final link = isDark ? const Color(0xFF58a6ff) : const Color(0xFF0969da);
    final body = TextStyle(fontSize: 15, height: 1.6, color: fg);
    return base.copyWith(
      p: body,
      listBullet: body,
      tableBody: body,
      tableHead: body.copyWith(fontWeight: FontWeight.w600),
      blockquote: body.copyWith(color: muted),
      h1: TextStyle(
          fontSize: 26, fontWeight: FontWeight.w700, color: fg, height: 1.3),
      h2: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w700, color: fg, height: 1.3),
      h3: TextStyle(
          fontSize: 19, fontWeight: FontWeight.w600, color: fg, height: 1.35),
      h4: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: fg, height: 1.4),
      h5: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: fg, height: 1.4),
      h6: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: muted, height: 1.4),
      h1Padding: const EdgeInsets.only(top: 16, bottom: 6),
      h2Padding: const EdgeInsets.only(top: 16, bottom: 6),
      h3Padding: const EdgeInsets.only(top: 12, bottom: 4),
      a: TextStyle(
        color: link,
        decoration: TextDecoration.underline,
        decorationColor: link,
      ),
      code: TextStyle(
        fontSize: 13,
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
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border, width: 1)),
      ),
    );
  }

  bool _scrollToAnchor(String anchor) {
    final key = _anchorKeys[ReadmeAnchors.normalize(anchor)];
    final targetContext = key?.currentContext;
    if (targetContext == null) return false;

    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
    return true;
  }
}

// ── Code tab ──────────────────────────────────────────────────────────────────

class _CodeTab extends StatefulWidget {
  const _CodeTab({
    required this.owner,
    required this.repo,
    required this.defaultBranch,
    required this.branches,
    required this.tags,
    required this.scrollResetVersion,
    required this.onBranchCreated,
  });
  final String owner;
  final String repo;
  final String defaultBranch;
  final List<Map<String, dynamic>> branches;
  final List<Map<String, dynamic>> tags;
  final int scrollResetVersion;
  final void Function(String name, String sha) onBranchCreated;

  @override
  State<_CodeTab> createState() => _CodeTabState();
}

class _CodeTabState extends State<_CodeTab> with AutomaticKeepAliveClientMixin {
  final _api = GitHubApiClient.instance;
  late final RepositoryBranchCreator _branchCreator =
      RepositoryBranchCreator(createBranch: _api.createBranch);

  String _selectedBranch = '';
  // Stack of (path, displayName) for breadcrumb navigation
  final List<_PathEntry> _pathStack = [];
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _error = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _selectedBranch = widget.defaultBranch;
    _loadContents('');
  }

  @override
  void didUpdateWidget(covariant _CodeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  Future<void> _loadContents(String path) async {
    setState(() {
      _loading = true;
      _error = '';
    });

    final result = await _api.getFileContents(
      widget.owner,
      widget.repo,
      path,
      ref: _selectedBranch,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final data = result.data;
      if (data is List) {
        final items = data.cast<Map<String, dynamic>>();
        // Sort: directories first, then files, both alphabetically
        items.sort((a, b) {
          final aDir = a['type'] == 'dir';
          final bDir = b['type'] == 'dir';
          if (aDir != bDir) return aDir ? -1 : 1;
          return (a['name'] as String? ?? '')
              .compareTo(b['name'] as String? ?? '');
        });
        setState(() {
          _items = items;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = AppLocalizations.of(context).loadFailed;
        });
      }
    } else {
      setState(() {
        _loading = false;
        _error = result.message ?? AppLocalizations.of(context).loadFailed;
      });
    }
  }

  void _navigateInto(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? '';
    final path = item['path'] as String? ?? '';
    setState(() => _pathStack.add(_PathEntry(name: name, path: path)));
    _loadContents(path);
  }

  void _navigateBack() {
    if (_pathStack.isEmpty) return;
    _pathStack.removeLast();
    _loadContents(_pathStack.isEmpty ? '' : _pathStack.last.path);
  }

  void _navigateTo(int index) {
    if (index == -1) {
      setState(() => _pathStack.clear());
      _loadContents('');
    } else {
      final path = _pathStack[index].path;
      setState(() => _pathStack.removeRange(index + 1, _pathStack.length));
      _loadContents(path);
    }
  }

  Future<void> _createNewBranch(String newName, String sourceRef) async {
    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() {
      _loading = true;
      _error = '';
    });

    final result = await _branchCreator.create(
      owner: widget.owner,
      repo: widget.repo,
      newBranchName: newName,
      sourceRef: sourceRef,
      branches: widget.branches,
      fallbackErrorMessage: l10n.createBranchFailed,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.createBranchSuccess)),
      );
      widget.onBranchCreated(newName, result.baseSha!);
      setState(() {
        _selectedBranch = newName;
        _pathStack.clear();
      });
      _loadContents('');
    } else {
      setState(() {
        _loading = false;
        _error = result.message;
      });
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  Future<void> _showBranchPicker(BuildContext context) async {
    final result = await BranchTagPickerBottomSheet.show(
      context,
      branches: widget.branches,
      tags: widget.tags,
      initialRef: _selectedBranch,
    );

    if (result != null && mounted) {
      final name = result.$1;
      final source = result.$2;
      final createBranch = result.$3;

      if (createBranch) {
        await _createNewBranch(name, source);
      } else if (name != _selectedBranch) {
        setState(() {
          _selectedBranch = name;
          _pathStack.clear();
        });
        _loadContents('');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Branch + path header ──────────────────────────────────────────
        Container(
          color: cs.surfaceContainer,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              if (_pathStack.isNotEmpty)
                InkWell(
                  onTap: _navigateBack,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.arrow_back_ios_new, size: 16),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      InkWell(
                        onTap:
                            _pathStack.isEmpty ? null : () => _navigateTo(-1),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          child: Text(
                            l10n.root,
                            style: TextStyle(
                              fontSize: 13,
                              color: _pathStack.isEmpty
                                  ? cs.onSurface
                                  : cs.primary,
                              fontWeight: _pathStack.isEmpty
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      for (int i = 0; i < _pathStack.length; i++) ...[
                        Icon(Icons.chevron_right,
                            size: 14, color: cs.onSurfaceVariant),
                        InkWell(
                          onTap: i == _pathStack.length - 1
                              ? null
                              : () => _navigateTo(i),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            child: Text(
                              _pathStack[i].name,
                              style: TextStyle(
                                fontSize: 13,
                                color: i == _pathStack.length - 1
                                    ? cs.onSurface
                                    : cs.primary,
                                fontWeight: i == _pathStack.length - 1
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Branch chip
              GestureDetector(
                onTap: () => _showBranchPicker(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fork_right, size: 14),
                      const SizedBox(width: 4),
                      Text(_selectedBranch,
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── File list ─────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => _loadContents(
                              _pathStack.isEmpty ? '' : _pathStack.last.path,
                            ),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                  : _items.isEmpty
                      ? Center(child: Text(l10n.noFiles))
                      : ListView.separated(
                          key: PageStorageKey<String>(
                            'repository-code-${widget.owner}/${widget.repo}-${widget.scrollResetVersion}',
                          ),
                          padding: EdgeInsets.zero,
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 48),
                          itemBuilder: (context, i) {
                            final item = _items[i];
                            final name = item['name'] as String? ?? '';
                            final type = item['type'] as String? ?? '';
                            final isDir = type == 'dir';
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                isDir ? Icons.folder_outlined : _fileIcon(name),
                                size: 20,
                                color: isDir
                                    ? Colors.amber.shade700
                                    : cs.onSurfaceVariant,
                              ),
                              title: Text(name,
                                  style: const TextStyle(fontSize: 13)),
                              trailing: isDir
                                  ? const Icon(Icons.chevron_right, size: 16)
                                  : null,
                              onTap: isDir
                                  ? () => _navigateInto(item)
                                  : () => context.push(
                                        '/file-viewer',
                                        extra: {
                                          'owner': widget.owner,
                                          'repo': widget.repo,
                                          'path':
                                              item['path'] as String? ?? name,
                                          'branch': _selectedBranch,
                                          'fileName': name,
                                        },
                                      ),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  static IconData _fileIcon(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'dart':
      case 'py':
      case 'js':
      case 'ts':
      case 'java':
      case 'kt':
      case 'swift':
      case 'go':
      case 'rs':
      case 'c':
      case 'cpp':
      case 'h':
        return Icons.code;
      case 'md':
      case 'txt':
      case 'rst':
        return Icons.description_outlined;
      case 'json':
      case 'yaml':
      case 'yml':
      case 'toml':
      case 'xml':
        return Icons.data_object;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'svg':
      case 'webp':
        return Icons.image_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}

class _PathEntry {
  _PathEntry({required this.name, required this.path});
  final String name;
  final String path;
}

// ── Issues tab ────────────────────────────────────────────────────────────────

class _IssuesTab extends StatefulWidget {
  const _IssuesTab({
    required this.owner,
    required this.repo,
    required this.scrollResetVersion,
  });
  final String owner;
  final String repo;
  final int scrollResetVersion;

  @override
  State<_IssuesTab> createState() => _IssuesTabState();
}

class _IssuesTabState extends State<_IssuesTab>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 30;

  final _api = GitHubApiClient.instance;
  RepositoryPagedList<Map<String, dynamic>> _issues =
      const RepositoryPagedList.initial();
  // 'all' | 'open' | 'closed'
  String _state = 'open';
  // 'all' | 'issues' | 'pulls'
  String _typeFilter = 'all';

  int? _issueCount;
  int? _prCount;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCounts();
  }

  @override
  void didUpdateWidget(covariant _IssuesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  Future<void> _loadCounts() async {
    final result = await _api.getIssueCounts(widget.owner, widget.repo);
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() {
        _issueCount = result.data!['issue_count'];
        _prCount = result.data!['pr_count'];
      });
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (_issues.isLoading) return;
    final loadingState = _issues.startLoading(refresh: refresh);
    setState(() {
      _issues = loadingState;
    });

    final dynamic result;
    if (_typeFilter == 'pulls') {
      result = await _api.getRepositoryPullRequests(
        widget.owner,
        widget.repo,
        state: _state == 'all' ? 'all' : _state,
        page: loadingState.page,
        perPage: _pageSize,
      );
    } else {
      result = await _api.getRepositoryIssues(
        widget.owner,
        widget.repo,
        state: _state == 'all' ? 'all' : _state,
        page: loadingState.page,
        perPage: _pageSize,
      );
    }

    if (!mounted) return;

    if (result.isSuccess) {
      final rawItemCount = (result.data as List?)?.length ?? 0;
      List<Map<String, dynamic>> items =
          List<Map<String, dynamic>>.from(result.data ?? []);
      // Client-side filter: when showing Issues only, exclude PRs
      if (_typeFilter == 'issues') {
        items = items.where((e) => e['pull_request'] == null).toList();
      }
      setState(() {
        _issues = _issues.complete(
          items: items,
          pageSize: _pageSize,
          rawItemCount: rawItemCount,
        );
      });
    } else {
      setState(() {
        _issues = _issues
            .fail(result.message ?? AppLocalizations.of(context).loadFailed);
      });
    }
  }

  void _switchState(String s) {
    if (s == _state) return;
    setState(() {
      _state = s;
      _issues = _issues.reset();
    });
    _load();
  }

  void _switchType(String t) {
    if (t == _typeFilter) return;
    setState(() {
      _typeFilter = t;
      _issues = _issues.reset();
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    final totalCount = (_issueCount != null || _prCount != null)
        ? (_issueCount ?? 0) + (_prCount ?? 0)
        : null;
    final issues = _issues.items;

    return Column(
      children: [
        // ── Filter toolbar ─────────────────────────────────────────────────
        Container(
          height: 44,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _IssueTypeTab(
                      label: l10n.filterAll,
                      count: totalCount,
                      selected: _typeFilter == 'all',
                      onTap: () => _switchType('all'),
                    ),
                    _IssueTypeTab(
                      label: 'Issues',
                      count: _issueCount,
                      selected: _typeFilter == 'issues',
                      onTap: () => _switchType('issues'),
                    ),
                    _IssueTypeTab(
                      label: 'PRs',
                      count: _prCount,
                      selected: _typeFilter == 'pulls',
                      onTap: () => _switchType('pulls'),
                    ),
                  ],
                ),
              ),
              _StateFilterButton(
                state: _state,
                onChanged: _switchState,
              ),
              if (_typeFilter == 'pulls')
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: '创建 Pull Request',
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () =>
                      context.push('/pr/new/${widget.owner}/${widget.repo}'),
                ),
              if (_typeFilter == 'issues')
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: l10n.createIssue,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () async {
                    await context
                        .push('/issue/new/${widget.owner}/${widget.repo}');
                    if (mounted) _load(refresh: true);
                  },
                ),
            ],
          ),
        ),
        // ── List ───────────────────────────────────────────────────────────
        Expanded(
          child: _issues.isLoading && issues.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _issues.error.isNotEmpty && issues.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_issues.error, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => _load(refresh: true),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                  : issues.isEmpty
                      ? Center(child: Text(l10n.noIssues))
                      : RefreshIndicator(
                          onRefresh: () => _load(refresh: true),
                          child: ListView.separated(
                            key: PageStorageKey<String>(
                              'repository-issues-${widget.owner}/${widget.repo}-${widget.scrollResetVersion}',
                            ),
                            padding: EdgeInsets.zero,
                            itemCount:
                                issues.length + (_issues.hasMore ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, indent: 16),
                            itemBuilder: (context, i) {
                              if (i >= issues.length) {
                                _load();
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                );
                              }
                              return _IssueTile(
                                  issue: issues[i],
                                  onTap: () {
                                    final number = issues[i]['number'] as int?;
                                    if (number != null) {
                                      final isPr =
                                          issues[i]['pull_request'] != null ||
                                              _typeFilter == 'pulls';
                                      if (isPr) {
                                        context.push(
                                            '/pr/${widget.owner}/${widget.repo}/$number');
                                      } else {
                                        context.push(
                                            '/issue/${widget.owner}/${widget.repo}/$number');
                                      }
                                    }
                                  });
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

// ── Issue type tab (underline style) ─────────────────────────────────────────

class _IssueTypeTab extends StatelessWidget {
  const _IssueTypeTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n < 10000 ? 1 : 0)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? cs.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? cs.onSurface : cs.onSurfaceVariant,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? cs.primaryContainer
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _formatCount(count!),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color:
                        selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── State filter dropdown chip ────────────────────────────────────────────────

class _StateFilterButton extends StatelessWidget {
  const _StateFilterButton({
    required this.state,
    required this.onChanged,
  });
  final String state;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final String label;
    final Color dotColor;
    if (state == 'open') {
      label = l10n.filterOpen;
      dotColor = Colors.green.shade600;
    } else if (state == 'closed') {
      label = l10n.filterClosed;
      dotColor = Colors.purple.shade600;
    } else {
      label = l10n.filterAll;
      dotColor = cs.onSurfaceVariant;
    }

    return GestureDetector(
      onTap: () => _showMenu(context, l10n),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        margin: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(width: 1),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 13, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context, AppLocalizations l10n) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(
      Offset(0, renderBox.size.height + 4),
      ancestor: overlay,
    );
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx - 40,
        offset.dy,
        overlay.size.width - offset.dx - renderBox.size.width + 40,
        0,
      ),
      items: [
        PopupMenuItem(value: 'open', child: Text(l10n.filterOpen)),
        PopupMenuItem(value: 'closed', child: Text(l10n.filterClosed)),
        PopupMenuItem(value: 'all', child: Text(l10n.filterAll)),
      ],
    ).then((value) {
      if (value != null) onChanged(value);
    });
  }
}

class _IssueTile extends StatelessWidget {
  const _IssueTile({required this.issue, required this.onTap});
  final Map<String, dynamic> issue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = issue['title'] as String? ?? '';
    final number = issue['number'] as int? ?? 0;
    final state = issue['state'] as String? ?? 'open';
    final isPr = issue['pull_request'] != null;
    final labels = ((issue['labels'] as List<dynamic>?) ?? [])
        .cast<Map<String, dynamic>>();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isPr ? Icons.call_merge : Icons.circle_outlined,
                size: 16,
                color: state == 'open'
                    ? Colors.green.shade600
                    : Colors.purple.shade600,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: [
                      Text('#$number',
                          style: Theme.of(context).textTheme.bodySmall),
                      ...labels.take(3).map((l) {
                        final color = Color(int.tryParse(
                                    '0xFF${l['color'] as String? ?? ''}') ??
                                0x22000000)
                            .withAlpha(60);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            l['name'] as String? ?? '',
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      }),
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

// ── Commits tab ───────────────────────────────────────────────────────────────

class _CommitsTab extends StatefulWidget {
  const _CommitsTab({
    required this.owner,
    required this.repo,
    required this.defaultBranch,
    required this.branches,
    required this.tags,
    required this.scrollResetVersion,
    required this.onBranchCreated,
  });
  final String owner;
  final String repo;
  final String defaultBranch;
  final List<Map<String, dynamic>> branches;
  final List<Map<String, dynamic>> tags;
  final int scrollResetVersion;
  final void Function(String name, String sha) onBranchCreated;

  @override
  State<_CommitsTab> createState() => _CommitsTabState();
}

class _CommitsTabState extends State<_CommitsTab>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 30;

  final _api = GitHubApiClient.instance;
  late final RepositoryBranchCreator _branchCreator =
      RepositoryBranchCreator(createBranch: _api.createBranch);
  RepositoryPagedList<Map<String, dynamic>> _commits =
      const RepositoryPagedList.initial();
  String _selectedBranch = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _selectedBranch = widget.defaultBranch;
    _load();
  }

  @override
  void didUpdateWidget(covariant _CommitsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  Future<void> _load({bool refresh = false}) async {
    if (_commits.isLoading) return;
    final loadingState = _commits.startLoading(refresh: refresh);
    setState(() {
      _commits = loadingState;
    });

    final result = await _api.getRepositoryCommits(
      widget.owner,
      widget.repo,
      sha: _selectedBranch,
      page: loadingState.page,
      perPage: _pageSize,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final items = result.data ?? [];
      setState(() {
        _commits = _commits.complete(
          items: items,
          pageSize: _pageSize,
        );
      });
    } else {
      setState(() {
        _commits = _commits.fail(
          result.message ?? AppLocalizations.of(context).loadFailed,
        );
      });
    }
  }

  Future<void> _createNewBranch(String newName, String sourceRef) async {
    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() {
      _commits = _commits.startLoading();
    });

    final result = await _branchCreator.create(
      owner: widget.owner,
      repo: widget.repo,
      newBranchName: newName,
      sourceRef: sourceRef,
      branches: widget.branches,
      fallbackErrorMessage: l10n.createBranchFailed,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.createBranchSuccess)),
      );
      widget.onBranchCreated(newName, result.baseSha!);
      setState(() {
        _selectedBranch = newName;
        _commits = _commits.reset();
      });
      _load();
    } else {
      setState(() {
        _commits = _commits.fail(result.message);
      });
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  Future<void> _showBranchPicker(BuildContext context) async {
    final result = await BranchTagPickerBottomSheet.show(
      context,
      branches: widget.branches,
      tags: widget.tags,
      initialRef: _selectedBranch,
    );

    if (result != null && mounted) {
      final name = result.$1;
      final source = result.$2;
      final createBranch = result.$3;

      if (createBranch) {
        await _createNewBranch(name, source);
      } else if (name != _selectedBranch) {
        setState(() {
          _selectedBranch = name;
          _commits = _commits.reset();
        });
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final commits = _commits.items;

    return Column(
      children: [
        // ── Branch selector bar ───────────────────────────────────────────
        InkWell(
          onTap: () => _showBranchPicker(context),
          child: Container(
            color: cs.surfaceContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.fork_right, size: 16),
                const SizedBox(width: 6),
                Text(l10n.branch,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _selectedBranch,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_drop_down, size: 20, color: cs.outline),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // ── Commit list ───────────────────────────────────────────────────
        Expanded(
          child: _commits.isLoading && commits.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _commits.error.isNotEmpty && commits.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_commits.error, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => _load(refresh: true),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                  : commits.isEmpty
                      ? Center(child: Text(l10n.noCommits))
                      : RefreshIndicator(
                          onRefresh: () => _load(refresh: true),
                          child: ListView.separated(
                            key: PageStorageKey<String>(
                              'repository-commits-${widget.owner}/${widget.repo}-${widget.scrollResetVersion}',
                            ),
                            padding: EdgeInsets.zero,
                            itemCount:
                                commits.length + (_commits.hasMore ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, indent: 16),
                            itemBuilder: (context, i) {
                              if (i >= commits.length) {
                                _load();
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                );
                              }
                              final c = commits[i];
                              return _CommitTile(
                                commit: c,
                                onTap: () {
                                  final sha = c['sha'] as String? ?? '';
                                  if (sha.isNotEmpty) {
                                    context.push(
                                        '/commit/${widget.owner}/${widget.repo}/$sha');
                                  }
                                },
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

class _CommitTile extends StatelessWidget {
  const _CommitTile({required this.commit, required this.onTap});
  final Map<String, dynamic> commit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final commitData = commit['commit'] as Map<String, dynamic>? ?? {};
    final message = commitData['message'] as String? ?? '';
    final firstLine = message.split('\n').first;
    final rawSha = commit['sha'] as String? ?? '';
    final sha = rawSha.substring(0, 7.clamp(0, rawSha.length));
    final authorData = commit['author'] as Map<String, dynamic>?;
    final avatarUrl = authorData?['avatar_url'] as String? ?? '';
    final login = authorData?['login'] as String? ?? '';
    final authorCommit = commitData['author'] as Map<String, dynamic>? ?? {};
    final dateStr = authorCommit['date'] as String? ?? '';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (avatarUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: avatarUrl,
                    width: 28,
                    height: 28,
                    placeholder: (_, __) => Container(
                        width: 28,
                        height: 28,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.account_circle, size: 28),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(sha,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.primary,
                          )),
                      if (login.isNotEmpty)
                        Text(' · $login',
                            style: Theme.of(context).textTheme.bodySmall),
                      if (dateStr.isNotEmpty)
                        Text(' · ${_shortDate(dateStr)}',
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

  static String _shortDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Releases tab ──────────────────────────────────────────────────────────────

class _ReleasesTab extends StatefulWidget {
  const _ReleasesTab({
    required this.owner,
    required this.repo,
    required this.scrollResetVersion,
  });
  final String owner;
  final String repo;
  final int scrollResetVersion;

  @override
  State<_ReleasesTab> createState() => _ReleasesTabState();
}

class _ReleasesTabState extends State<_ReleasesTab>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 20;

  final _api = GitHubApiClient.instance;
  RepositoryPagedList<Map<String, dynamic>> _releases =
      const RepositoryPagedList.initial();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ReleasesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  Future<void> _load({bool refresh = false}) async {
    if (_releases.isLoading) return;
    final loadingState = _releases.startLoading(refresh: refresh);
    setState(() {
      _releases = loadingState;
    });

    final result = await _api.getRepositoryReleases(
      widget.owner,
      widget.repo,
      page: loadingState.page,
      perPage: _pageSize,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _releases = _releases.complete(
          items: result.data ?? [],
          pageSize: _pageSize,
        );
      });
    } else {
      setState(() {
        _releases = _releases.fail(
          result.message ?? AppLocalizations.of(context).loadFailed,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final releases = _releases.items;

    if (_releases.isLoading && releases.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_releases.error.isNotEmpty && releases.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_releases.error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _load(refresh: true),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (releases.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.new_releases_outlined, size: 48),
            const SizedBox(height: 12),
            Text(l10n.noReleases),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
          ),
          child: Row(
            children: [
              Text(
                '${releases.length} 个 Release',
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed:
                    _releases.isLoading ? null : () => _load(refresh: true),
                icon: _releases.isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 16),
                label: const Text('刷新'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(refresh: true),
            child: ListView.separated(
              key: PageStorageKey<String>(
                'repository-releases-${widget.owner}/${widget.repo}-${widget.scrollResetVersion}',
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              itemCount: releases.length + (_releases.hasMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i >= releases.length) {
                  _load();
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _ReleaseTile(release: releases[i]);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ReleaseTile extends StatefulWidget {
  const _ReleaseTile({required this.release});
  final Map<String, dynamic> release;

  @override
  State<_ReleaseTile> createState() => _ReleaseTileState();
}

class _ReleaseTileState extends State<_ReleaseTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final release = widget.release;
    final name = release['name'] as String? ?? '';
    final tag = release['tag_name'] as String? ?? '';
    final title = name.isNotEmpty ? name : tag;
    final prerelease = release['prerelease'] as bool? ?? false;
    final draft = release['draft'] as bool? ?? false;
    final publishedAt = release['published_at'] as String? ??
        release['created_at'] as String? ??
        '';
    final body = (release['body'] as String? ?? '').trim();
    final htmlUrl = release['html_url'] as String? ?? '';
    final zipballUrl = release['zipball_url'] as String? ?? '';
    final tarballUrl = release['tarball_url'] as String? ?? '';
    final author = release['author'] is Map
        ? release['author'] as Map<dynamic, dynamic>
        : null;
    final authorName = author?['login'] as String? ?? 'Unknown';
    final assets = ((release['assets'] as List<dynamic>?) ?? [])
        .whereType<Map>()
        .map((asset) => Map<String, dynamic>.from(asset))
        .toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withAlpha(128)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.sell_outlined, size: 20, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (prerelease || draft) ...[
                      const SizedBox(width: 8),
                      _ReleaseBadge(
                        text: draft ? 'Draft' : 'Pre-release',
                        color: draft ? cs.outline : Colors.orange.shade700,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.push('/user/$authorName'),
                        child: _ReleaseMeta(
                          icon: Icons.person_outline,
                          text: authorName,
                          tappable: true,
                        ),
                      ),
                    ),
                    _ReleaseMeta(
                      icon: Icons.calendar_today_outlined,
                      text: _relativeTime(publishedAt),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${assets.length} 个资源文件',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (body.isNotEmpty && !_expanded) ...[
                  const SizedBox(height: 12),
                  Text(
                    _bodyPreview(body),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(_expanded ? '隐藏详情' : '查看详情'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed:
                          htmlUrl.isEmpty ? null : () => _openUrl(htmlUrl),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('在 GitHub 中打开'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _ReleaseDetails(
              body: body,
              assets: assets,
              zipballUrl: zipballUrl,
              tarballUrl: tarballUrl,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }

  static String _relativeTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt.toLocal());
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return _shortDate(iso);
    } catch (_) {
      return iso;
    }
  }

  static String _shortDate(String iso) {
    final dt = DateTime.parse(iso);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  static String _bodyPreview(String body) {
    var text = body
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^\)]*\)'), '') // images
        .replaceAllMapped(
            RegExp(r'\[([^\]]+)\]\([^\)]+\)'), (m) => m[1]!) // links → text
        .replaceAll(RegExp(r'```[\s\S]*?```'), '') // fenced code blocks
        .replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1]!) // inline code
        .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '') // headings
        .replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m[1]!) // bold **
        .replaceAllMapped(RegExp(r'__([^_]+)__'), (m) => m[1]!) // bold __
        .replaceAllMapped(RegExp(r'\*([^*\n]+)\*'), (m) => m[1]!) // italic *
        .replaceAll(RegExp(r'^>\s*', multiLine: true), '') // blockquotes
        .replaceAll(
            RegExp(r'^[-*+]\s+', multiLine: true), '') // unordered lists
        .replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), ''); // ordered lists
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(3)
        .join(' · ');
    return lines.isEmpty ? body : lines;
  }
}

class _ReleaseBadge extends StatelessWidget {
  const _ReleaseBadge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        border: Border.all(color: color.withAlpha(128)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ReleaseMeta extends StatelessWidget {
  const _ReleaseMeta({
    required this.icon,
    required this.text,
    this.tappable = false,
  });
  final IconData icon;
  final String text;
  final bool tappable;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = tappable ? cs.primary : cs.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: color,
              decoration: tappable ? TextDecoration.underline : null,
              decorationColor: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReleaseDetails extends StatelessWidget {
  const _ReleaseDetails({
    required this.body,
    required this.assets,
    required this.zipballUrl,
    required this.tarballUrl,
  });

  final String body;
  final List<Map<String, dynamic>> assets;
  final String zipballUrl;
  final String tarballUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasSources = zipballUrl.isNotEmpty || tarballUrl.isNotEmpty;
    final hasAssets = assets.isNotEmpty || hasSources;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (body.isNotEmpty)
            MarkdownScrollFix(
              child: MarkdownBody(
                data: body,
                selectable: true,
                onTapLink: (text, href, title) {
                  if (href != null) {
                    _openUrl(href);
                  }
                },
              ),
            )
          else
            Text(
              '暂无发布说明',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          if (hasAssets) ...[
            const SizedBox(height: 16),
            Text(
              '资源文件',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            ...assets.map(_ReleaseAssetRow.new),
            if (zipballUrl.isNotEmpty)
              _ReleaseSourceRow(label: 'Source code (zip)', url: zipballUrl),
            if (tarballUrl.isNotEmpty)
              _ReleaseSourceRow(label: 'Source code (tar.gz)', url: tarballUrl),
          ],
        ],
      ),
    );
  }
}

class _ReleaseAssetRow extends StatelessWidget {
  const _ReleaseAssetRow(this.asset);
  final Map<String, dynamic> asset;

  @override
  Widget build(BuildContext context) {
    final name = asset['name'] as String? ?? '';
    final url = asset['browser_download_url'] as String? ?? '';
    final size = asset['size'] as int? ?? 0;
    final downloads = asset['download_count'] as int? ?? 0;
    return _ReleaseDownloadRow(
      icon: Icons.save_alt_outlined,
      label: name,
      subtitle: '${_formatSize(size)} · $downloads downloads',
      onTap: url.isEmpty ? null : () => _openUrl(url),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(value >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
  }
}

class _ReleaseSourceRow extends StatelessWidget {
  const _ReleaseSourceRow({required this.label, required this.url});
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return _ReleaseDownloadRow(
      icon: Icons.code,
      label: label,
      onTap: () => _openUrl(url),
    );
  }
}

class _ReleaseDownloadRow extends StatelessWidget {
  const _ReleaseDownloadRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 7),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withAlpha(128),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openUrl(String url) async {
  if (url.isEmpty) return;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
