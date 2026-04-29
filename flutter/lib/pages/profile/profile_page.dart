import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/github_api_client.dart';
import '../../components/contribution/contribution_calendar.dart';
import '../../models/github_org.dart';
import '../../models/pinned_repository.dart';
import '../../models/user.dart';
import '../../models/user_activity.dart';
import '../../router/app_router.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = AuthService.instance;
  final _theme = ThemeService.instance;
  final _api = GitHubApiClient.instance;

  List<GithubOrg> _orgs = [];
  bool _orgsLoading = true;

  List<PinnedRepository> _pinnedRepos = [];
  bool _pinnedLoading = true;
  bool _pinnedIsTopRepos = false;

  UserActivitySummary? _activity;
  bool _activityLoading = true;

  @override
  void initState() {
    super.initState();
    final login = _auth.currentUser?.login ?? '';
    if (login.isNotEmpty) {
      _loadOrgs(login);
      _loadPinnedOrTopRepos(login);
      _loadActivity();
    }
  }

  Future<void> _loadOrgs(String login) async {
    final result = await _api.getUserOrgs(login);
    if (!mounted) return;
    setState(() {
      _orgs = result.data ?? [];
      _orgsLoading = false;
    });
  }

  Future<void> _loadPinnedOrTopRepos(String login) async {
    // 1. Try pinned repos via GraphQL
    final pinned = await _api.getUserPinnedRepos(login);
    if (!mounted) return;

    if (pinned.data?.isNotEmpty == true) {
      setState(() {
        _pinnedRepos = pinned.data!;
        _pinnedIsTopRepos = false;
        _pinnedLoading = false;
      });
      return;
    }

    // 2. Fallback: top repos by stars
    final top = await _api.getUserTopRepos(login);
    if (!mounted) return;
    setState(() {
      _pinnedRepos = top.data ?? [];
      _pinnedIsTopRepos = true;
      _pinnedLoading = false;
    });
  }

  Future<void> _loadActivity() async {
    // Use /user/events so private-repo pushes are included
    final result = await _api.getMyEvents(perPage: 100);
    if (!mounted) return;

    if (result.isSuccess) {
      final events = result.data ?? [];
      int commitCount = 0;
      int repoCount = 0;
      int prCount = 0;

      for (final event in events) {
        final type = event['type'] as String? ?? '';
        final payload = event['payload'] as Map<String, dynamic>?;
        switch (type) {
          case 'PushEvent':
            // size is an int but some responses return num
            final size = (payload?['size'] as num?)?.toInt() ??
                (payload?['commits'] as List?)?.length ??
                0;
            commitCount += size;
            break;
          case 'CreateEvent':
            if (payload?['ref_type'] == 'repository') repoCount++;
            break;
          case 'PullRequestEvent':
            if (payload?['action'] == 'opened') prCount++;
            break;
        }
      }

      setState(() {
        _activity = UserActivitySummary(
          commitCount: commitCount,
          repoCount: repoCount,
          prCount: prCount,
        );
        _activityLoading = false;
      });
    } else {
      setState(() => _activityLoading = false);
    }
  }

  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── Simple pinned app bar (no expandedHeight) ──────────────
                SliverAppBar(
                  pinned: true,
                  title: Text(
                    user.name.isNotEmpty ? user.name : '@${user.login}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),

                // ── User card (auto-sizes to content, no fixed height) ─────
                SliverToBoxAdapter(child: _UserCard(user: user)),

                // ── Stats ──────────────────────────────────────────────────
                SliverToBoxAdapter(child: _StatsBar(user: user)),

                // ── Info (location / company / blog / email) ───────────────
                SliverToBoxAdapter(child: _InfoSection(user: user)),

                // ── Organizations (conditional) ────────────────────────────
                if (!_orgsLoading && _orgs.isNotEmpty)
                  SliverToBoxAdapter(child: _OrgRow(orgs: _orgs)),

                // ── Contribution heatmap ───────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: ContributionCalendar(username: user.login),
                  ),
                ),

                // ── Activity summary ───────────────────────────────────────
                SliverToBoxAdapter(
                  child: _ActivitySummaryCard(
                    activity: _activity,
                    loading: _activityLoading,
                  ),
                ),

                // ── Pinned / Top repos carousel (conditional) ──────────────
                if (!_pinnedLoading && _pinnedRepos.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _PinnedReposCarousel(
                      repos: _pinnedRepos,
                      login: user.login,
                      isTopRepos: _pinnedIsTopRepos,
                    ),
                  ),

                // ── Menu ───────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _MenuSection(
                    onMyRepos: () => context.push(AppRoutes.myRepos),
                    onStarred: () =>
                        context.push('/starred/${user.login}'),
                    onSettings: () => context.push(AppRoutes.settings),
                    onLogout: _handleLogout,
                    themeService: _theme,
                  ),
                ),

                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('CopoHub',
                          style:
                              TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── User card (自适应高度，无 fixed expandedHeight) ─────────────────────────

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});
  final GithubUser user;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cs.primaryContainer, cs.surface],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: CachedNetworkImage(
              imageUrl: user.avatarUrl,
              width: 72,
              height: 72,
              placeholder: (_, __) => Container(
                  width: 72,
                  height: 72,
                  color: cs.surfaceContainerHighest),
              errorWidget: (_, __, ___) =>
                  Icon(Icons.person, size: 36, color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user.name.isNotEmpty)
                  Text(
                    user.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                Text(
                  '@${user.login}',
                  style:
                      TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                ),
                if (user.bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    user.bio,
                    // 最多显示 3 行，防止过长
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats bar ─────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.user});
  final GithubUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _StatItem(label: '仓库', value: '${user.publicRepos}'),
            const VerticalDivider(width: 1),
            _StatItem(label: '关注者', value: _fmt(user.followers)),
            const VerticalDivider(width: 1),
            _StatItem(label: '正在关注', value: '${user.following}'),
          ],
        ),
      ),
    );
  }

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}

// ── Info section ──────────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.user});
  final GithubUser user;

  @override
  Widget build(BuildContext context) {
    final items = [
      if (user.company.isNotEmpty) (Icons.business_outlined, user.company),
      if (user.location.isNotEmpty)
        (Icons.location_on_outlined, user.location),
      if (user.blog.isNotEmpty) (Icons.link, user.blog),
      if (user.email.isNotEmpty) (Icons.email_outlined, user.email),
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: items
            .map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(t.$1,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(t.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ── Organizations row ─────────────────────────────────────────────────────────

class _OrgRow extends StatelessWidget {
  const _OrgRow({required this.orgs});
  final List<GithubOrg> orgs;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('所属组织',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              color: cs.surfaceContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: SizedBox(
                  height: 72,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: orgs.length,
                    itemBuilder: (context, i) => _OrgAvatar(org: orgs[i]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrgAvatar extends StatelessWidget {
  const _OrgAvatar({required this.org});
  final GithubOrg org;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.push('/user/${org.login}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cs.outlineVariant),
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: org.avatarUrl,
                  width: 44,
                  height: 44,
                  placeholder: (_, __) =>
                      Container(color: cs.surfaceContainerHighest),
                  errorWidget: (_, __, ___) => Icon(Icons.business,
                      size: 22, color: cs.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 52,
              child: Text(
                org.login,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Activity summary card ─────────────────────────────────────────────────────

class _ActivitySummaryCard extends StatelessWidget {
  const _ActivitySummaryCard(
      {required this.activity, required this.loading});
  final UserActivitySummary? activity;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (activity == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('近期动态',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primaryContainer.withValues(alpha: 0.55),
                    cs.secondaryContainer.withValues(alpha: 0.35),
                  ],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest
                            .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '近90天',
                        style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _ActivityMetric(
                          value: activity!.commitCount,
                          label: '提交',
                          icon: Icons.commit_rounded,
                          color: cs.primary,
                        ),
                      ),
                      Container(
                          width: 1,
                          height: 40,
                          color:
                              cs.outlineVariant.withValues(alpha: 0.5)),
                      Expanded(
                        child: _ActivityMetric(
                          value: activity!.repoCount,
                          label: '新仓库',
                          icon: Icons.folder_special_outlined,
                          color: cs.secondary,
                        ),
                      ),
                      Container(
                          width: 1,
                          height: 40,
                          color:
                              cs.outlineVariant.withValues(alpha: 0.5)),
                      Expanded(
                        child: _ActivityMetric(
                          value: activity!.prCount,
                          label: 'PR',
                          icon: Icons.call_merge_rounded,
                          color: cs.tertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityMetric extends StatelessWidget {
  const _ActivityMetric({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
  final int value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.toDouble()),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Text(
            _fmt(v.round()),
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 22, height: 1),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

// ── Pinned / Top repos carousel ───────────────────────────────────────────────

class _PinnedReposCarousel extends StatefulWidget {
  const _PinnedReposCarousel({
    required this.repos,
    required this.login,
    required this.isTopRepos,
  });
  final List<PinnedRepository> repos;
  final String login;
  final bool isTopRepos;

  @override
  State<_PinnedReposCarousel> createState() =>
      _PinnedReposCarouselState();
}

class _PinnedReposCarouselState extends State<_PinnedReposCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Icon(
                  widget.isTopRepos
                      ? Icons.star_outline_rounded
                      : Icons.push_pin_outlined,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.isTopRepos ? '热门仓库' : '置顶仓库',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 148,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.repos.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, i) {
                return AnimatedScale(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                  scale: _currentPage == i ? 1.0 : 0.94,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    child: _PinnedRepoCard(
                      repo: widget.repos[i],
                      onTap: () {
                        final parts =
                            widget.repos[i].fullName.split('/');
                        if (parts.length == 2) {
                          context.push(
                              '/repository/${parts[0]}/${parts[1]}');
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.repos.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.repos.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                  width: _currentPage == i ? 18 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: _currentPage == i
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PinnedRepoCard extends StatelessWidget {
  const _PinnedRepoCard({required this.repo, required this.onTap});
  final PinnedRepository repo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final langColor = repo.languageColor.isNotEmpty
        ? Color(int.tryParse(
                repo.languageColor.replaceFirst('#', '0xFF')) ??
            0xFF8b949e)
        : cs.onSurfaceVariant;

    return Material(
      color: cs.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.book_outlined,
                      size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      repo.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: cs.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (repo.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  repo.description,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  if (repo.languageName.isNotEmpty) ...[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: langColor),
                    ),
                    const SizedBox(width: 4),
                    Text(repo.languageName,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 12),
                  ],
                  Icon(Icons.star_border_rounded,
                      size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text(_fmt(repo.stargazerCount),
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 10),
                  Icon(Icons.call_split_rounded,
                      size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text(_fmt(repo.forkCount),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

// ── Menu section ──────────────────────────────────────────────────────────────

class _MenuSection extends StatelessWidget {
  const _MenuSection({
    required this.onMyRepos,
    required this.onStarred,
    required this.onSettings,
    required this.onLogout,
    required this.themeService,
  });
  final VoidCallback onMyRepos;
  final VoidCallback onStarred;
  final VoidCallback onSettings;
  final VoidCallback onLogout;
  final ThemeService themeService;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child:
                Text('内容', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          _MenuCard(children: [
            _MenuTile(
                icon: Icons.source_outlined,
                label: '我的仓库',
                onTap: onMyRepos),
            const Divider(height: 1, indent: 48),
            _MenuTile(
                icon: Icons.star_border,
                label: 'Star 仓库',
                onTap: onStarred),
          ]),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child:
                Text('设置', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          _MenuCard(children: [
            _ThemeToggleTile(themeService: themeService),
            const Divider(height: 1, indent: 48),
            _MenuTile(
                icon: Icons.settings_outlined,
                label: '应用设置',
                onTap: onSettings),
          ]),
          const SizedBox(height: 16),
          _MenuCard(children: [
            _MenuTile(
                icon: Icons.logout,
                label: '退出登录',
                color: cs.error,
                onTap: onLogout),
          ]),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: Column(children: children),
        ),
      );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effective = color ?? Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: effective),
      title: Text(label, style: TextStyle(color: effective)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
      dense: true,
    );
  }
}

class _ThemeToggleTile extends StatefulWidget {
  const _ThemeToggleTile({required this.themeService});
  final ThemeService themeService;

  @override
  State<_ThemeToggleTile> createState() => _ThemeToggleTileState();
}

class _ThemeToggleTileState extends State<_ThemeToggleTile> {
  @override
  Widget build(BuildContext context) {
    final mode = widget.themeService.themeMode;
    const modeLabels = {
      ThemeMode2.auto: '跟随系统',
      ThemeMode2.light: '浅色',
      ThemeMode2.dark: '深色',
    };
    return ListTile(
      leading: const Icon(Icons.brightness_6_outlined),
      title: const Text('外观'),
      trailing: DropdownButton<ThemeMode2>(
        value: mode,
        underline: const SizedBox.shrink(),
        items: ThemeMode2.values.map((m) {
          return DropdownMenuItem(
            value: m,
            child: Text(modeLabels[m] ?? m.name),
          );
        }).toList(),
        onChanged: (v) {
          if (v != null) {
            widget.themeService.setThemeMode(v);
            setState(() {});
          }
        },
      ),
      dense: true,
    );
  }
}
