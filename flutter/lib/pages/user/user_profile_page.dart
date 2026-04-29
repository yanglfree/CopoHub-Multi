import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/github_api_client.dart';
import '../../components/contribution/contribution_calendar.dart';
import '../../models/user.dart';
import '../../models/repository.dart';
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

  GithubUser? _user;
  bool _userLoading = true;
  String _userError = '';

  bool _isFollowing = false;
  bool _followActionLoading = false;

  List<Repository> _repos = [];
  bool _reposLoading = false;
  bool _reposHasMore = true;
  int _reposPage = 1;

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
      _loadRepos();
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
              expandedHeight: 260,
              actions: [
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: '分享',
                  onPressed: () => ShareService.shareProfile(
                    username: widget.username,
                    bio: _user?.bio,
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _UserHeader(
                  user: user,
                  isCurrentUser: _isCurrentUser,
                  isFollowing: _isFollowing,
                  followLoading: _followActionLoading,
                  onFollow: _toggleFollow,
                ),
              ),
            ),

            // Stats bar
            SliverToBoxAdapter(
              child: _StatsBar(
                repos: user.publicRepos,
                followers: user.followers,
                following: user.following,
                onFollowersTap: () => context
                    .push('/social/${widget.username}/followers'),
                onFollowingTap: () => context
                    .push('/social/${widget.username}/following'),
              ),
            ),

            const SliverToBoxAdapter(child: Divider(height: 1)),

            // Contribution calendar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: ContributionCalendar(username: widget.username),
              ),
            ),

            const SliverToBoxAdapter(child: Divider(height: 1)),

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
                padding:
                    const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                            child:
                                Center(child: CircularProgressIndicator()),
                          );
                        }
                        final repo = _repos[i];
                        return _RepoTile(
                          repo: repo,
                          onTap: () => context.push(
                              '/repository/${widget.username}/${repo.name}'),
                        );
                      },
                      childCount:
                          _repos.length + (_reposHasMore ? 1 : 0),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

// ── User header (avatar, bio, location, etc.) ─────────────────────────────────

class _UserHeader extends StatelessWidget {
  const _UserHeader({
    required this.user,
    required this.isCurrentUser,
    required this.isFollowing,
    required this.followLoading,
    required this.onFollow,
  });
  final GithubUser user;
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
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Avatar
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
                      const Icon(Icons.account_circle, size: 72),
                ),
              ),
              const Spacer(),
              // Follow button
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
          // Name & login
          Text(
            user.name.isNotEmpty ? user.name : user.login,
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 18),
          ),
          if (user.name.isNotEmpty)
            Text(user.login,
                style: TextStyle(
                    fontSize: 13, color: cs.onSurfaceVariant)),
          // Bio
          if (user.bio.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(user.bio,
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
          // Meta (company / location / blog / email)
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 2,
            children: [
              if (user.company.isNotEmpty)
                _MetaChip(
                    icon: Icons.business_outlined, label: user.company),
              if (user.location.isNotEmpty)
                _MetaChip(
                    icon: Icons.location_on_outlined,
                    label: user.location),
              if (user.blog.isNotEmpty)
                _MetaChip(
                    icon: Icons.link_outlined, label: user.blog),
              if (user.email.isNotEmpty)
                _MetaChip(
                    icon: Icons.mail_outline, label: user.email),
            ],
          ),
        ],
      ),
    );
  }
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
        Icon(icon, size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
        const _Divider(),
        Expanded(
            child: _StatItem(
                value: followers, label: '粉丝', onTap: onFollowersTap)),
        const _Divider(),
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
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 18),
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

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 36, color: Theme.of(context).colorScheme.outlineVariant);
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
                                style:
                                    Theme.of(context).textTheme.bodySmall),
                            const SizedBox(width: 10),
                          ],
                          const Icon(Icons.star_border, size: 13),
                          const SizedBox(width: 2),
                          Text(_fmt(repo.stargazersCount),
                              style:
                                  Theme.of(context).textTheme.bodySmall),
                          if (repo.fork) ...[
                            const SizedBox(width: 10),
                            Icon(Icons.fork_right,
                                size: 13, color: cs.onSurfaceVariant),
                            Text(' Fork',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant)),
                          ],
                        ],
                      ),
                    ],
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
          ),
        ),
        const Divider(height: 1, indent: 16),
      ],
    );
  }

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}
