import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
  int _starCount = 0;
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _tags = [];

  late final TabController _tab;
  late final List<int> _tabScrollResetVersions;
  int _activeTabIndex = 0;
  final GlobalKey<NestedScrollViewState> _nestedScrollKey = GlobalKey();

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
      final inner = state.innerController;
      if (!outer.hasClients || !inner.hasClients) return;
      // jumpTo on innerController takes the combined unnested offset, so
      // pass outer's current pixels — this keeps the header where it is
      // (preserving the pinned-tab state) while resetting inner content
      // to 0 so the freshly selected tab starts from the top.
      inner.jumpTo(outer.position.pixels);
    });
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

  Future<void> _toggleStar() async {
    if (_repository == null) return;
    if (_isStarred) {
      await _api.unstarRepository(widget.owner, widget.repo);
      setState(() {
        _isStarred = false;
        _starCount = (_starCount - 1).clamp(0, 999999999);
      });
    } else {
      await _api.starRepository(widget.owner, widget.repo);
      setState(() {
        _isStarred = true;
        _starCount++;
      });
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
                icon: const Icon(Icons.share_outlined),
                tooltip: '分享',
                onPressed: () => ShareService.shareRepository(
                  owner: widget.owner,
                  repo: widget.repo,
                  description: _repository?.description,
                  stars: _repository?.stargazersCount ?? 0,
                  language: _repository?.language,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isStarred ? Icons.star : Icons.star_border,
                  color: _isStarred ? Colors.amber : null,
                ),
                tooltip: _isStarred ? '取消 Star' : 'Star',
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
                  isDark: Theme.of(context).brightness == Brightness.dark),
              _CodeTab(
                  owner: widget.owner,
                  repo: widget.repo,
                  defaultBranch: repo.defaultBranch,
                  branches: _branches,
                  tags: _tags,
                  scrollResetVersion: _tabScrollResetVersions[1]),
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
                  scrollResetVersion: _tabScrollResetVersions[3]),
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
  });
  final String owner;
  final String repo;
  final String defaultBranch;
  final int scrollResetVersion;
  final bool isDark;

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
      return;
    }
    if (oldWidget.scrollResetVersion == widget.scrollResetVersion) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = PrimaryScrollController.maybeOf(context);
      if (controller == null || !controller.hasClients) return;
      controller.jumpTo(0);
    });
  }

  Future<void> _loadReadme() async {
    setState(() {
      _loading = true;
      _hasError = false;
      _markdown = null;
      _readmePath = 'README.md';
      _downloadUrl = '';
      _htmlUrl = '';
    });

    final result = await _api.getRepositoryReadme(
      widget.owner,
      widget.repo,
      ref: widget.defaultBranch,
    );
    if (!mounted) return;

    if (result.isSuccess) {
      final data = result.data;
      final encoded = data?['content'] as String? ?? '';
      final encoding = (data?['encoding'] as String? ?? 'base64').toLowerCase();
      final text = _decodeReadmeContent(encoded, encoding);
      if (text != null && text.trim().isNotEmpty) {
        setState(() {
          _readmePath = data?['path'] as String? ?? 'README.md';
          _downloadUrl = data?['download_url'] as String? ?? '';
          _htmlUrl = data?['html_url'] as String? ?? '';
          _markdown = _stripHtmlForMarkdown(text);
          _loading = false;
          _hasError = false;
        });
        return;
      }
    }

    setState(() {
      _loading = false;
      _hasError = true;
    });
  }

  /// Preprocess raw GitHub README markdown:
  /// - Converts common HTML tags to markdown equivalents (bold, italic, links, images)
  /// - Strips remaining HTML so flutter_markdown doesn't show raw angle-bracket tags
  String _stripHtmlForMarkdown(String src) {
    var s = src;

    // 1. Drop HTML comments first so they don't interfere with later regexes.
    s = s.replaceAll(RegExp(r'<!--[\s\S]*?-->', caseSensitive: false), '');

    // 2. Erase opaque blocks entirely (script/style/svg/iframe content).
    s = s.replaceAllMapped(
      RegExp(
        r'<(script|style|iframe|svg|video|audio|object)\b[^>]*?>[\s\S]*?</\1>',
        caseSensitive: false,
      ),
      (_) => '',
    );

    // 3. Convert <pre><code>…</code></pre> → fenced code block.
    s = s.replaceAllMapped(
      RegExp(
        r'<pre\b[^>]*?>\s*<code\b[^>]*?>([\s\S]*?)</code>\s*</pre>',
        caseSensitive: false,
      ),
      (m) => '\n```\n${_unescapeHtmlEntities(m.group(1)!)}\n```\n',
    );
    s = s.replaceAllMapped(
      RegExp(r'<pre\b[^>]*?>([\s\S]*?)</pre>', caseSensitive: false),
      (m) => '\n```\n${_unescapeHtmlEntities(m.group(1)!)}\n```\n',
    );

    // 4. Convert <img> → markdown image ![]().
    s = s.replaceAllMapped(
      RegExp(
        r'''<img\b[^>]*?\bsrc\s*=\s*(["'])([^"']*)\1[^>]*?/?>''',
        caseSensitive: false,
      ),
      (m) {
        final src = m.group(2) ?? '';
        final raw = m.group(0)!;
        final altM = RegExp(
          r'''\balt\s*=\s*(["'])([^"']*)\1''',
          caseSensitive: false,
        ).firstMatch(raw);
        return '![${altM?.group(2) ?? ''}]($src)';
      },
    );

    // 5. Convert <a href="…">text</a> → [text](href).
    s = s.replaceAllMapped(
      RegExp(
        r'''<a\b[^>]*?\bhref\s*=\s*(["'])([^"']*)\1[^>]*?>([\s\S]*?)</a>''',
        caseSensitive: false,
      ),
      (m) {
        final href = _unescapeHtmlEntities(m.group(2) ?? '');
        final text = _unescapeHtmlEntities(
          (m.group(3) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim(),
        );
        return text.isEmpty ? '' : '[$text]($href)';
      },
    );

    // 6. Convert inline formatting HTML → markdown equivalents.
    s = s.replaceAllMapped(
      RegExp(r'<(b|strong)\b[^>]*?>([\s\S]*?)</(b|strong)>', caseSensitive: false),
      (m) => '**${m.group(2)}**',
    );
    s = s.replaceAllMapped(
      RegExp(r'<(i|em)\b[^>]*?>([\s\S]*?)</(i|em)>', caseSensitive: false),
      (m) => '_${m.group(2)}_',
    );
    s = s.replaceAllMapped(
      RegExp(r'<(del|s|strike)\b[^>]*?>([\s\S]*?)</(del|s|strike)>', caseSensitive: false),
      (m) => '~~${m.group(2)}~~',
    );
    s = s.replaceAllMapped(
      RegExp(r'<code\b[^>]*?>([\s\S]*?)</code>', caseSensitive: false),
      (m) => '`${_unescapeHtmlEntities(m.group(1)!)}`',
    );

    // 7. Convert <br> to newline.
    s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    // 8. Strip remaining HTML container/block tags, keeping their inner text.
    s = s.replaceAll(
      RegExp(
        r'</?(?:div|span|p|section|article|header|footer|nav|main|aside|center'
        r'|details|summary|table|thead|tbody|tr|td|th|font|small|big|sub|sup'
        r'|kbd|mark|figure|figcaption|picture|source|h[1-6])\b[^>]*?>',
        caseSensitive: false,
      ),
      '',
    );

    // 9. Drop standalone void/self-closing tags we have no markdown mapping for.
    s = s.replaceAll(
      RegExp(
        r'<(?:input|meta|link|embed)\b[^>]*?/?>',
        caseSensitive: false,
      ),
      '',
    );

    // 10. Remove leading whitespace from image lines so they are not
    // misinterpreted as indented code blocks (4-space rule) by the parser.
    s = s.replaceAllMapped(
      RegExp(r'^[^\S\n]+(![\[\(])', multiLine: true),
      (m) => m.group(1)!,
    );

    // 11. Unescape remaining HTML entities in the full text.
    s = _unescapeHtmlEntities(s);

    return s;
  }

  String _unescapeHtmlEntities(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      // Match &nbsp; with or without the trailing semicolon (some READMEs omit it).
      .replaceAll(RegExp(r'&nbsp;?'), '\u00a0');

  /// Splits [text] into sections so that markdown table blocks (lines whose
  /// first non-space character is `|`) can be rendered inside a horizontal
  /// scroll container, while normal prose/code sections use full width.
  List<({bool isTable, String content})> _splitByTables(String text) {
    final sections = <({bool isTable, String content})>[];
    final buf = StringBuffer();
    bool inTable = false;

    void flush() {
      final s = buf.toString();
      if (s.trim().isNotEmpty) sections.add((isTable: inTable, content: s));
      buf.clear();
    }

    for (final line in text.split('\n')) {
      final tableRow = line.trimLeft().startsWith('|');
      if (tableRow != inTable) {
        flush();
        inTable = tableRow;
      }
      buf.writeln(line);
    }
    flush();
    return sections;
  }

  String? _decodeReadmeContent(String content, String encoding) {
    if (content.isEmpty) return null;
    if (encoding != 'base64') return content;
    try {
      return utf8.decode(base64Decode(content.replaceAll('\n', '')));
    } catch (_) {
      return null;
    }
  }

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

    final sections = _splitByTables(_markdown!);
    final normalStyle = _readmeStyleSheet(theme, widget.isDark);
    final tableStyle = normalStyle.copyWith(
      // IntrinsicColumnWidth lets each column expand to its content width so
      // the table can scroll horizontally without squishing text into narrow
      // columns (the FlexColumnWidth default distributes fixed total width).
      tableColumnWidth: const IntrinsicColumnWidth(),
    );

    Widget buildMarkdown(String data, MarkdownStyleSheet style) => MarkdownBody(
          data: data,
          // selectable:true wraps content in SelectionArea which swallows
          // TapGestureRecognizer events — links become unclickable.
          selectable: false,
          styleSheet: style,
          onTapLink: (text, href, title) {
            if (href == null || href.isEmpty) return;
            final resolved = _resolveReadmeUrl(href, forImage: false);
            dispatchLinkAction(context, resolved);
          },
          sizedImageBuilder: (config) {
            final resolved =
                _resolveReadmeUrl(config.uri.toString(), forImage: true);
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
            if (section.isTable)
              // Wrap each table in its own horizontal scroll so wide tables
              // don't force text to wrap into unreadably narrow columns.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: buildMarkdown(section.content, tableStyle),
              )
            else
              buildMarkdown(section.content, normalStyle),
        ],
      ),
    );
  }

  MarkdownStyleSheet _readmeStyleSheet(ThemeData theme, bool isDark) {
    final base = MarkdownStyleSheet.fromTheme(theme);
    final fg = isDark ? const Color(0xFFe6edf3) : const Color(0xFF24292f);
    final muted = isDark ? const Color(0xFF8b949e) : const Color(0xFF57606a);
    final border = isDark ? const Color(0xFF30363d) : const Color(0xFFd0d7de);
    final codeBg = isDark
        ? const Color(0x666e7681)
        : const Color(0x33afb8c1);
    final preBg = isDark ? const Color(0xFF161b22) : const Color(0xFFf6f8fa);
    final link = isDark ? const Color(0xFF58a6ff) : const Color(0xFF0969da);
    final body = TextStyle(fontSize: 15, height: 1.6, color: fg);
    return base.copyWith(
      p: body,
      listBullet: body,
      tableBody: body,
      tableHead: body.copyWith(fontWeight: FontWeight.w600),
      blockquote: body.copyWith(color: muted),
      h1: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: fg, height: 1.3),
      h2: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: fg, height: 1.3),
      h3: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: fg, height: 1.35),
      h4: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: fg, height: 1.4),
      h5: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg, height: 1.4),
      h6: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted, height: 1.4),
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
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border, width: 1)),
      ),
    );
  }

  String _resolveReadmeUrl(String href, {bool forImage = false}) {
    final trimmed = href.trim();
    if (trimmed.isEmpty) return trimmed;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      final scheme = uri.scheme.toLowerCase();
      if (scheme == 'http' || scheme == 'https' || scheme == 'mailto') {
        return trimmed;
      }
      if (forImage && scheme == 'data') {
        return trimmed;
      }
      return 'about:blank';
    }

    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }

    if (trimmed.startsWith('#')) {
      final base = _htmlUrl.isNotEmpty
          ? _htmlUrl
          : 'https://github.com/${widget.owner}/${widget.repo}';
      return '$base$trimmed';
    }

    if (trimmed.startsWith('/')) {
      final sitePath = trimmed.substring(1);
      if (sitePath.startsWith('${widget.owner}/${widget.repo}/')) {
        return 'https://github.com$trimmed';
      }
      final path = _normalizeRepoPath(trimmed.substring(1));
      if (forImage) return _rawUrlFor(path);
      return 'https://github.com/${widget.owner}/${widget.repo}/blob/${widget.defaultBranch}/$path';
    }

    final baseDir = _readmePath.contains('/')
        ? _readmePath.substring(0, _readmePath.lastIndexOf('/'))
        : '';
    final joined = baseDir.isEmpty ? trimmed : '$baseDir/$trimmed';
    final normalized = _normalizeRepoPath(joined);

    if (forImage) {
      if (_downloadUrl.isNotEmpty && normalized == _readmePath) {
        return _downloadUrl;
      }
      return _rawUrlFor(normalized);
    }

    return 'https://github.com/${widget.owner}/${widget.repo}/blob/${widget.defaultBranch}/$normalized';
  }

  String _rawUrlFor(String path) =>
      'https://raw.githubusercontent.com/${widget.owner}/${widget.repo}/${_encodePath(widget.defaultBranch)}/${_encodePath(path)}';

  String _encodePath(String path) =>
      path.split('/').map(Uri.encodeComponent).join('/');

  String _normalizeRepoPath(String path) {
    final output = <String>[];
    for (final part in path.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (output.isNotEmpty) output.removeLast();
        continue;
      }
      output.add(part);
    }
    return output.join('/');
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
  });
  final String owner;
  final String repo;
  final String defaultBranch;
  final List<Map<String, dynamic>> branches;
  final List<Map<String, dynamic>> tags;
  final int scrollResetVersion;

  @override
  State<_CodeTab> createState() => _CodeTabState();
}

class _CodeTabState extends State<_CodeTab> with AutomaticKeepAliveClientMixin {
  final _api = GitHubApiClient.instance;

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
    if (oldWidget.scrollResetVersion == widget.scrollResetVersion) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = PrimaryScrollController.maybeOf(context);
      if (controller == null || !controller.hasClients) return;
      controller.jumpTo(0);
    });
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

    // Find source branch's commit SHA
    final sourceBranchInfo = widget.branches.cast<Map<String, dynamic>?>().firstWhere(
      (b) => b != null && b['name'] == sourceRef,
      orElse: () => null,
    );
    final baseSha = sourceBranchInfo?['commit']?['sha'] as String?;

    if (baseSha == null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.createBranchFailed)),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    final result = await _api.createBranch(
      owner: widget.owner,
      repo: widget.repo,
      newBranchName: newName,
      baseSha: baseSha,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.createBranchSuccess)),
      );
      // We cannot call _loadBranches() directly as it's in the parent state.
      // For now, we manually update the local state.
      widget.branches.insert(0, {
        'name': newName,
        'commit': {'sha': baseSha},
      });
      setState(() {
        _selectedBranch = newName;
        _pathStack.clear();
      });
      _loadContents('');
    } else {
      setState(() {
        _loading = false;
        _error = result.message ?? l10n.createBranchFailed;
      });
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(result.message ?? l10n.createBranchFailed)),
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
                  ? Center(child: Text(_error))
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
  final _api = GitHubApiClient.instance;
  List<Map<String, dynamic>> _issues = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  // 'all' | 'open' | 'closed'
  String _state = 'open';
  // 'all' | 'issues' | 'pulls'
  String _typeFilter = 'all';
  String _error = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _IssuesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollResetVersion == widget.scrollResetVersion) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = PrimaryScrollController.maybeOf(context);
      if (controller == null || !controller.hasClients) return;
      controller.jumpTo(0);
    });
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

    final dynamic result;
    if (_typeFilter == 'pulls') {
      result = await _api.getRepositoryPullRequests(
        widget.owner,
        widget.repo,
        state: _state == 'all' ? 'all' : _state,
        page: _page,
        perPage: 30,
      );
    } else {
      result = await _api.getRepositoryIssues(
        widget.owner,
        widget.repo,
        state: _state == 'all' ? 'all' : _state,
        page: _page,
        perPage: 30,
      );
    }

    if (!mounted) return;

    if (result.isSuccess) {
      List<Map<String, dynamic>> items =
          List<Map<String, dynamic>>.from(result.data ?? []);
      // Client-side filter: when showing Issues only, exclude PRs
      if (_typeFilter == 'issues') {
        items = items
            .where((e) => e['pull_request'] == null)
            .toList();
      }
      setState(() {
        _loading = false;
        if (refresh) {
          _issues = items;
        } else {
          _issues = [..._issues, ...items];
        }
        // For issues-only mode the filtered count may be < perPage even if more
        // pages exist, so only stop paging when the raw page was short.
        _hasMore = (result.data as List?)?.length != null &&
            (result.data as List).length >= 30;
        _page++;
      });
    } else {
      setState(() {
        _loading = false;
        _error = result.message ?? AppLocalizations.of(context).loadFailed;
      });
    }
  }

  void _switchState(String s) {
    if (s == _state) return;
    setState(() {
      _state = s;
      _issues = [];
      _page = 1;
    });
    _load();
  }

  void _switchType(String t) {
    if (t == _typeFilter) return;
    setState(() {
      _typeFilter = t;
      _issues = [];
      _page = 1;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        // ── Type filter chips ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
          child: Row(
            children: [
              _FilterChip(
                label: l10n.filterAll,
                selected: _typeFilter == 'all',
                onTap: () => _switchType('all'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Issues',
                selected: _typeFilter == 'issues',
                onTap: () => _switchType('issues'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'PRs',
                selected: _typeFilter == 'pulls',
                onTap: () => _switchType('pulls'),
              ),
            ],
          ),
        ),
        // ── State filter chips ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(
            children: [
              _FilterChip(
                label: l10n.filterAll,
                selected: _state == 'all',
                onTap: () => _switchState('all'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: l10n.filterOpen,
                selected: _state == 'open',
                onTap: () => _switchState('open'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: l10n.filterClosed,
                selected: _state == 'closed',
                onTap: () => _switchState('closed'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading && _issues.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty && _issues.isEmpty
                  ? Center(child: Text(_error))
                  : _issues.isEmpty
                      ? Center(child: Text(l10n.noIssues))
                      : RefreshIndicator(
                          onRefresh: () => _load(refresh: true),
                          child: ListView.separated(
                            key: PageStorageKey<String>(
                              'repository-issues-${widget.owner}/${widget.repo}-${widget.scrollResetVersion}',
                            ),
                            padding: EdgeInsets.zero,
                            itemCount: _issues.length + (_hasMore ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, indent: 16),
                            itemBuilder: (context, i) {
                              if (i >= _issues.length) {
                                _load();
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                );
                              }
                              return _IssueTile(
                                  issue: _issues[i],
                                  onTap: () {
                                    final number = _issues[i]['number'] as int?;
                                    if (number != null) {
                                      final isPr = _issues[i]['pull_request'] != null ||
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
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
  });
  final String owner;
  final String repo;
  final String defaultBranch;
  final List<Map<String, dynamic>> branches;
  final List<Map<String, dynamic>> tags;
  final int scrollResetVersion;

  @override
  State<_CommitsTab> createState() => _CommitsTabState();
}

class _CommitsTabState extends State<_CommitsTab>
    with AutomaticKeepAliveClientMixin {
  final _api = GitHubApiClient.instance;
  List<Map<String, dynamic>> _commits = [];
  String _selectedBranch = '';
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String _error = '';

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
    if (oldWidget.scrollResetVersion == widget.scrollResetVersion) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = PrimaryScrollController.maybeOf(context);
      if (controller == null || !controller.hasClients) return;
      controller.jumpTo(0);
    });
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

    final result = await _api.getRepositoryCommits(
      widget.owner,
      widget.repo,
      sha: _selectedBranch,
      page: _page,
      perPage: 30,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final items = result.data ?? [];
      setState(() {
        _loading = false;
        if (refresh) {
          _commits = items;
        } else {
          _commits = [..._commits, ...items];
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

  Future<void> _createNewBranch(String newName, String sourceRef) async {
    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Find source branch's commit SHA
    final sourceBranchInfo = widget.branches.cast<Map<String, dynamic>?>().firstWhere(
      (b) => b != null && b['name'] == sourceRef,
      orElse: () => null,
    );
    final baseSha = sourceBranchInfo?['commit']?['sha'] as String?;

    if (baseSha == null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.createBranchFailed)),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    final result = await _api.createBranch(
      owner: widget.owner,
      repo: widget.repo,
      newBranchName: newName,
      baseSha: baseSha,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.createBranchSuccess)),
      );
      // We'd need to tell parent to reload branches if we want it updated everywhere,
      // but for now let's just update locally and switch.
      setState(() {
        _selectedBranch = newName;
        _commits = [];
        _page = 1;
      });
      _load();
    } else {
      setState(() {
        _loading = false;
        _error = result.message ?? l10n.createBranchFailed;
      });
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(result.message ?? l10n.createBranchFailed)),
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
          _commits = [];
          _page = 1;
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
          child: _loading && _commits.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty && _commits.isEmpty
                  ? Center(child: Text(_error))
                  : _commits.isEmpty
                      ? Center(child: Text(l10n.noCommits))
                      : RefreshIndicator(
                          onRefresh: () => _load(refresh: true),
                          child: ListView.separated(
                            key: PageStorageKey<String>(
                              'repository-commits-${widget.owner}/${widget.repo}-${widget.scrollResetVersion}',
                            ),
                            padding: EdgeInsets.zero,
                            itemCount: _commits.length + (_hasMore ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, indent: 16),
                            itemBuilder: (context, i) {
                              if (i >= _commits.length) {
                                _load();
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                );
                              }
                              final c = _commits[i];
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
  final _api = GitHubApiClient.instance;
  List<Map<String, dynamic>> _releases = [];
  bool _loading = true;
  String _error = '';

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
    if (oldWidget.scrollResetVersion == widget.scrollResetVersion) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = PrimaryScrollController.maybeOf(context);
      if (controller == null || !controller.hasClients) return;
      controller.jumpTo(0);
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    final result = await _api.getRepositoryReleases(
      widget.owner,
      widget.repo,
      perPage: 20,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _releases = result.data ?? [];
        _loading = false;
      });
    } else {
      setState(() {
        _error = result.message ?? AppLocalizations.of(context).loadFailed;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    if (_loading && _releases.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) return Center(child: Text(_error));
    if (_releases.isEmpty) {
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
                '${_releases.length} 个 Release',
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _loading ? null : _load,
                icon: _loading
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
            onRefresh: _load,
            child: ListView.separated(
              key: PageStorageKey<String>(
                'repository-releases-${widget.owner}/${widget.repo}-${widget.scrollResetVersion}',
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              itemCount: _releases.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _ReleaseTile(release: _releases[i]),
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
                      child: _ReleaseMeta(
                        icon: Icons.person_outline,
                        text: authorName,
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
    final lines = body
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(3)
        .join('\n');
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
  const _ReleaseMeta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant,
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
            MarkdownBody(
              data: body,
              selectable: true,
              onTapLink: (text, href, title) {
                if (href != null) {
                  _openUrl(href);
                }
              },
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
