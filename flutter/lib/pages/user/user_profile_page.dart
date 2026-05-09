import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/github_api_client.dart';
import '../../components/contribution/contribution_calendar.dart';
import '../../components/repository/repo_context_menu.dart';
import '../../models/github_org.dart';
import '../../models/pinned_repository.dart';
import '../../models/user.dart';
import '../../models/repository.dart';
import '../../models/user_activity.dart';
import '../../models/user_status.dart';
import '../../services/auth_service.dart';
import '../../services/share_service.dart';
import '../../utils/constants.dart';

/// Public user profile page — mirrors HarmonyOS UserProfileView.
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key, required this.username});
  final String username;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _api = GitHubApiClient.instance;
  final GlobalKey _shareButtonKey = GlobalKey();

  GithubUser? _user;
  bool _userLoading = true;
  String _userError = '';

  bool _isFollowing = false;
  bool _followActionLoading = false;

  List<Repository> _repos = [];
  bool _reposLoading = false;
  bool _reposHasMore = true;
  int _reposPage = 1;

  List<GithubOrg> _orgs = [];
  bool _orgsLoading = true;

  List<Map<String, dynamic>> _orgMembers = [];
  bool _orgMembersLoading = false;

  List<PinnedRepository> _pinnedRepos = [];
  bool _pinnedLoading = true;

  UserActivitySummary? _activity;
  bool _activityLoading = true;
  GithubUserStatus? _status;

  bool get _isCurrentUser =>
      AuthService.instance.currentUser?.login == widget.username;

  @override
  void initState() {
    super.initState();
    _loadUser();
    if (!_isCurrentUser) _checkFollowing();
  }

  Future<void> _loadUser() async {
    setState(() {
      _userLoading = true;
      _userError = '';
    });

    final result = await _api.getUser(widget.username);
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _user = result.data;
        _userLoading = false;
      });
      // 用户加载成功后并行拉取其他数据
      _loadRepos();
      _loadPinnedRepos();
      if (_user!.type == 'Organization') {
        _loadOrgMembers();
      } else {
        _loadOrgs();
        _loadActivity();
        _loadStatus();
      }
    } else {
      setState(() {
        _userError = result.message ?? '加载失败';
        _userLoading = false;
      });
    }
  }

  Future<void> _checkFollowing() async {
    final result = await _api.checkUserFollowing(widget.username);
    if (mounted && result.isSuccess) {
      setState(() => _isFollowing = result.data ?? false);
    }
  }

  Future<void> _loadRepos({bool refresh = false}) async {
    if (_reposLoading) return;
    if (refresh) {
      _reposPage = 1;
      _reposHasMore = true;
    }
    setState(() => _reposLoading = true);

    final result = await _api.getUserPublicRepositories(
      widget.username,
      sort: 'updated',
      page: _reposPage,
      perPage: 20,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final items = result.data ?? [];
      setState(() {
        _reposLoading = false;
        if (refresh) {
          _repos = items;
        } else {
          _repos = [..._repos, ...items];
        }
        _reposHasMore = items.length >= 20;
        _reposPage++;
      });
    } else {
      setState(() => _reposLoading = false);
    }
  }

  Future<void> _loadOrgMembers() async {
    setState(() => _orgMembersLoading = true);
    final result = await _api.getOrgPublicMembers(widget.username);
    if (!mounted) return;
    setState(() {
      _orgMembers = result.data ?? [];
      _orgMembersLoading = false;
    });
  }

  Future<void> _loadOrgs() async {
    setState(() => _orgsLoading = true);
    final result = await _api.getUserOrgs(widget.username);
    if (!mounted) return;
    setState(() {
      _orgs = result.data ?? [];
      _orgsLoading = false;
    });
  }

  Future<void> _loadPinnedRepos() async {
    setState(() => _pinnedLoading = true);
    final result = await _api.getUserPinnedRepos(widget.username);
    if (!mounted) return;
    setState(() {
      _pinnedRepos = result.data ?? [];
      _pinnedLoading = false;
    });
  }

  Future<void> _loadActivity() async {
    setState(() => _activityLoading = true);
    final result = await _api.getUserEvents(widget.username, perPage: 100);
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
            commitCount += (payload?['size'] as int? ?? 0);
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

  Future<void> _loadStatus() async {
    final result = await _api.getUserStatus(widget.username);
    if (!mounted) return;
    if (result.success) {
      setState(() => _status = result.data);
    }
  }

  Future<void> _toggleFollow() async {
    if (_followActionLoading) return;
    setState(() => _followActionLoading = true);

    if (_isFollowing) {
      await _api.unfollowUser(widget.username);
      setState(() {
        _isFollowing = false;
        _followActionLoading = false;
      });
    } else {
      await _api.followUser(widget.username);
      setState(() {
        _isFollowing = true;
        _followActionLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.username)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_userError.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.username)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(_userError),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _loadUser, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    final user = _user!;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadUser();
        },
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              pinned: true,
              title: Text(
                user.name.isNotEmpty ? user.name : user.login,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              actions: [
                IconButton(
                  key: _shareButtonKey,
                  icon: const Icon(Icons.share_outlined),
                  tooltip: '分享',
                  onPressed: () async {
                    final box = _shareButtonKey.currentContext
                        ?.findRenderObject() as RenderBox?;
                    final origin = box != null
                        ? box.localToGlobal(Offset.zero) & box.size
                        : null;
                    try {
                      await ShareService.shareProfile(
                        username: widget.username,
                        bio: _user?.bio,
                        sharePositionOrigin: origin,
                      );
                    } catch (_) {}
                  },
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: _UserHeader(
                user: user,
                status: _status,
                isCurrentUser: _isCurrentUser,
                isFollowing: _isFollowing,
                followLoading: _followActionLoading,
                onFollow: _toggleFollow,
              ),
            ),

            // Stats bar
            SliverToBoxAdapter(
              child: _StatsBar(
                repos: user.publicRepos,
                followers: user.followers,
                following: user.following,
                onFollowersTap: () =>
                    context.push('/social/${widget.username}/followers'),
                onFollowingTap: () =>
                    context.push('/social/${widget.username}/following'),
              ),
            ),

            const SliverToBoxAdapter(child: Divider(height: 1)),

            // Organizations row — only for personal users
            if (!_orgsLoading && _orgs.isNotEmpty && (_user?.type != 'Organization')) ...[
              SliverToBoxAdapter(child: _OrgRow(orgs: _orgs)),
              const SliverToBoxAdapter(child: Divider(height: 1)),
            ],

            // Org members — only for organization accounts
            if (user.type == 'Organization') ...[
              SliverToBoxAdapter(
                child: _OrgMembersSection(
                  members: _orgMembers,
                  loading: _orgMembersLoading,
                  onMemberTap: (login) => context.push('/user/$login'),
                ),
              ),
              const SliverToBoxAdapter(child: Divider(height: 1)),
            ],

            // Contribution calendar — personal users only
            if (user.type != 'Organization') ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: ContributionCalendar(
                    username: widget.username,
                    showThemeMenu: false,
                  ),
                ),
              ),

              // Activity summary card
              SliverToBoxAdapter(
                child: _ActivitySummaryCard(
                  activity: _activity,
                  loading: _activityLoading,
                ),
              ),

              const SliverToBoxAdapter(child: Divider(height: 1)),
            ],

            // Pinned repos carousel（有数据时才显示）
            if (!_pinnedLoading && _pinnedRepos.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _PinnedReposCarousel(
                  repos: _pinnedRepos,
                  username: widget.username,
                ),
              ),
              const SliverToBoxAdapter(child: Divider(height: 1)),
            ],

            // Starred repos shortcut
            SliverToBoxAdapter(
              child: ListTile(
                leading: const Icon(Icons.star_border),
                title: const Text('Starred 仓库'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/starred/${widget.username}'),
              ),
            ),

            const SliverToBoxAdapter(child: Divider(height: 1)),

            // Repos section header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  '公开仓库',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),

            // Repos list
            _reposLoading && _repos.isEmpty
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()))
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        if (i >= _repos.length) {
                          if (_reposHasMore) _loadRepos();
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final repo = _repos[i];
                        return _RepoTile(
                          repo: repo,
                          onTap: () => context.push(
                              '/repository/${widget.username}/${repo.name}'),
                        );
                      },
                      childCount: _repos.length + (_reposHasMore ? 1 : 0),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

// ── User header ───────────────────────────────────────────────────────────────

class _UserHeader extends StatelessWidget {
  const _UserHeader({
    required this.user,
    required this.status,
    required this.isCurrentUser,
    required this.isFollowing,
    required this.followLoading,
    required this.onFollow,
  });
  final GithubUser user;
  final GithubUserStatus? status;
  final bool isCurrentUser;
  final bool isFollowing;
  final bool followLoading;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cs.surfaceContainer, cs.surface],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: user.avatarUrl,
                      width: 72,
                      height: 72,
                      placeholder: (_, __) => Container(
                          width: 72, height: 72, color: cs.surfaceContainerHighest),
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.account_circle, size: 72),
                    ),
                  ),
                  if (user.type == 'Organization')
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: cs.surface, width: 1.5),
                        ),
                        child: Text(
                          'Org',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimaryContainer,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              if (!isCurrentUser)
                FilledButton.tonal(
                  onPressed: followLoading ? null : onFollow,
                  child: followLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(isFollowing ? '已关注' : '关注'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            user.name.isNotEmpty ? user.name : user.login,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          if (user.name.isNotEmpty)
            Text(user.login,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          if (status?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            _StatusPill(status: status!),
          ],
          if (user.bio.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              user.bio,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 2,
            children: [
              if (user.company.isNotEmpty)
                _MetaChip(icon: Icons.business_outlined, label: user.company),
              if (user.location.isNotEmpty)
                _MetaChip(
                    icon: Icons.location_on_outlined, label: user.location),
              if (user.blog.isNotEmpty)
                _MetaChip(icon: Icons.link_outlined, label: user.blog),
              if (user.email.isNotEmpty)
                _MetaChip(icon: Icons.mail_outline, label: user.email),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final GithubUserStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = [
      if (status.emoji.isNotEmpty) _displayEmoji(status.emoji),
      if (status.message.isNotEmpty) status.message,
    ].join(' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.indicatesLimitedAvailability
            ? cs.tertiaryContainer
            : cs.surfaceContainerHighest,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: status.indicatesLimitedAvailability
              ? cs.onTertiaryContainer
              : cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _displayEmoji(String raw) {
  const named = {
    ':palm_tree:': '🌴',
    ':house:': '🏠',
    ':office:': '🏢',
    ':rocket:': '🚀',
    ':eyes:': '👀',
    ':coffee:': '☕',
    ':memo:': '📝',
    ':computer:': '💻',
    ':wave:': '👋',
    ':sleeping:': '😴',
  };
  return named[raw] ?? raw;
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

// ── Stats bar ─────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  const _StatsBar({
    required this.repos,
    required this.followers,
    required this.following,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });
  final int repos;
  final int followers;
  final int following;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatItem(value: repos, label: '仓库', onTap: null)),
        const _VerticalDivider(),
        Expanded(
            child: _StatItem(
                value: followers, label: '粉丝', onTap: onFollowersTap)),
        const _VerticalDivider(),
        Expanded(
            child: _StatItem(
                value: following, label: '关注', onTap: onFollowingTap)),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem(
      {required this.value, required this.label, required this.onTap});
  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(
              _fmt(value),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();
  @override
  Widget build(BuildContext context) => Container(
      width: 1,
      height: 36,
      color: Theme.of(context).colorScheme.outlineVariant);
}

// ── Organizations row ─────────────────────────────────────────────────────────

class _OrgRow extends StatelessWidget {
  const _OrgRow({required this.orgs});
  final List<GithubOrg> orgs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Text(
            '所属组织',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
          ),
        ),
        SizedBox(
          height: 76,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: orgs.length,
            itemBuilder: (context, i) => _OrgAvatar(org: orgs[i]),
          ),
        ),
        const SizedBox(height: 10),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cs.outlineVariant, width: 1),
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
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
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
  const _ActivitySummaryCard({
    required this.activity,
    required this.loading,
  });
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
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (activity == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primaryContainer.withOpacity(0.55),
              cs.secondaryContainer.withOpacity(0.35),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: cs.outlineVariant.withOpacity(0.6), width: 1),
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  '近期动态',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.6),
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
              ],
            ),
            const SizedBox(height: 16),
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
                    color: cs.outlineVariant.withOpacity(0.5)),
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
                    color: cs.outlineVariant.withOpacity(0.5)),
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

// ── Pinned repos carousel ─────────────────────────────────────────────────────

class _PinnedReposCarousel extends StatefulWidget {
  const _PinnedReposCarousel({required this.repos, required this.username});
  final List<PinnedRepository> repos;
  final String username;

  @override
  State<_PinnedReposCarousel> createState() => _PinnedReposCarouselState();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              const Icon(Icons.push_pin_outlined, size: 15),
              const SizedBox(width: 6),
              Text(
                '置顶仓库',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: _PinnedRepoCard(
                    repo: widget.repos[i],
                    onTap: () {
                      final parts = widget.repos[i].fullName.split('/');
                      if (parts.length == 2) {
                        context.push('/repository/${parts[0]}/${parts[1]}');
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
        // Page indicator dots
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
        const SizedBox(height: 12),
      ],
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
        ? Color(int.tryParse(repo.languageColor.replaceFirst('#', '0xFF')) ??
            0xFF8b949e)
        : cs.onSurfaceVariant;

    return Material(
      color: cs.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
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
                        color: cs.primary,
                      ),
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
                        shape: BoxShape.circle,
                        color: langColor,
                      ),
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

// ── Repo tile ─────────────────────────────────────────────────────────────────

class _RepoTile extends StatelessWidget {
  const _RepoTile({required this.repo, required this.onTap});
  final Repository repo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          onLongPress: () => showRepoContextMenu(context, repo),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        repo.name,
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
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
                      Row(
                        children: [
                          if (repo.language.isNotEmpty) ...[
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(int.tryParse(
                                        Constants.getLanguageColor(
                                                repo.language)
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
                          if (repo.fork) ...[
                            const SizedBox(width: 10),
                            Icon(Icons.fork_right,
                                size: 13, color: cs.onSurfaceVariant),
                            Text(' Fork',
                                style: TextStyle(
                                    fontSize: 11, color: cs.onSurfaceVariant)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (repo.private)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          ),
        ),
        const Divider(height: 1, indent: 16),
      ],
    );
  }

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

// ── Org members section ───────────────────────────────────────────────────────

class _OrgMembersSection extends StatelessWidget {
  const _OrgMembersSection({
    required this.members,
    required this.loading,
    required this.onMemberTap,
  });
  final List<Map<String, dynamic>> members;
  final bool loading;
  final void Function(String) onMemberTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Text(
            '公开成员',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
          ),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (members.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              '暂无公开成员',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          SizedBox(
            height: 76,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: members.length,
              itemBuilder: (context, i) => _OrgMemberAvatar(
                member: members[i],
                onTap: onMemberTap,
              ),
            ),
          ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _OrgMemberAvatar extends StatelessWidget {
  const _OrgMemberAvatar({required this.member, required this.onTap});
  final Map<String, dynamic> member;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final login = member['login'] as String? ?? '';
    final avatarUrl = member['avatar_url'] as String? ?? '';
    return GestureDetector(
      onTap: login.isNotEmpty ? () => onTap(login) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cs.outlineVariant, width: 1),
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: avatarUrl,
                  width: 44,
                  height: 44,
                  placeholder: (_, __) =>
                      Container(color: cs.surfaceContainerHighest),
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.account_circle, size: 44),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 56,
              child: Text(
                login,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
