import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../components/contribution/contribution_calendar.dart';
import '../../models/user.dart';
import '../../router/app_router.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';

/// "我的" (Profile) tab — user card, stats, menu, logout.
/// Mirrors HarmonyOS ProfileView.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = AuthService.instance;
  final _theme = ThemeService.instance;

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
    if (confirmed == true && mounted) {
      _auth.logout();
      // go_router redirect handles navigation to login
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _ProfileHeader(user: user),
                SliverToBoxAdapter(
                  child: _StatsBar(user: user),
                ),
                SliverToBoxAdapter(
                  child: _InfoSection(user: user),
                ),
                // Contribution heatmap
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: ContributionCalendar(username: user.login),
                  ),
                ),
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
                // Footer
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'CopoHub',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Profile header (avatar + name + bio) ─────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final GithubUser user;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      title: Text(
        user.name.isNotEmpty ? user.name : '@${user.login}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cs.primaryContainer,
                cs.surface,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 48), // space for status bar
                  Row(
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
                          errorWidget: (_, __, ___) => Icon(
                              Icons.person, size: 36, color: cs.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (user.bio.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      user.bio,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stats bar (repos / followers / following) ─────────────────────────────────

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
            _StatItem(
                label: '关注者',
                value: _fmt(user.followers)),
            const VerticalDivider(width: 1),
            _StatItem(
                label: '正在关注',
                value: '${user.following}'),
          ],
        ),
      ),
    );
  }

  static String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
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
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}

// ── Info (location / company / blog) ─────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.user});
  final GithubUser user;

  @override
  Widget build(BuildContext context) {
    final items = [
      if (user.company.isNotEmpty)
        (Icons.business_outlined, user.company),
      if (user.location.isNotEmpty)
        (Icons.location_on_outlined, user.location),
      if (user.blog.isNotEmpty)
        (Icons.link, user.blog),
      if (user.email.isNotEmpty)
        (Icons.email_outlined, user.email),
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
                      Icon(t.$1, size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
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

// ── Menu section ─────────────────────────────────────────────────────────────

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
            child: Text('内容', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          _MenuCard(
            children: [
              _MenuTile(
                icon: Icons.source_outlined,
                label: '我的仓库',
                onTap: onMyRepos,
              ),
              const Divider(height: 1, indent: 48),
              _MenuTile(
                icon: Icons.star_border,
                label: 'Star 仓库',
                onTap: onStarred,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('设置', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          _MenuCard(
            children: [
              _ThemeToggleTile(themeService: themeService),
              const Divider(height: 1, indent: 48),
              _MenuTile(
                icon: Icons.settings_outlined,
                label: '应用设置',
                onTap: onSettings,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MenuCard(
            children: [
              _MenuTile(
                icon: Icons.logout,
                label: '退出登录',
                color: cs.error,
                onTap: onLogout,
              ),
            ],
          ),
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
