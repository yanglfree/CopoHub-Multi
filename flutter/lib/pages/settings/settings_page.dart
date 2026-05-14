import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/api_cache.dart';
import '../../api/github_api_client.dart';
import '../../components/dialogs/app_dialog.dart';
import '../../components/policy/policy_dialog.dart';
import '../../services/app_info_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../utils/constants.dart';

/// App settings page — mirrors HarmonyOS SettingsView.
/// Theme mode, contribution color theme, cache clear, about, logout.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _themeService = ThemeService.instance;
  late String _cacheSize;

  @override
  void initState() {
    super.initState();
    _cacheSize = ApiCache.instance.formattedSize;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = AuthService.instance.currentUser;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('设置', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // ── Account section ──────────────────────────────────────────────────
          const _SectionHeader(title: '账号'),
          if (user != null)
            _SettingsSection(
              children: [
                _SettingsTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundImage: user.avatarUrl.isNotEmpty
                        ? NetworkImage(user.avatarUrl)
                        : null,
                    child: user.avatarUrl.isEmpty
                        ? const Icon(Icons.person_outline)
                        : null,
                  ),
                  title: user.name.isNotEmpty ? user.name : user.login,
                  subtitle: '@${user.login}',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/user/${user.login}'),
                ),
              ],
            ),

          // ── Appearance section ───────────────────────────────────────────────
          const _SectionHeader(title: '外观'),
          _SettingsSection(
            children: [
              _ThemeModeTile(themeService: _themeService),
              const _SectionDivider(),
              _ContributionThemeTile(themeService: _themeService),
            ],
          ),

          // ── Data section ─────────────────────────────────────────────────────
          const _SectionHeader(title: '数据'),
          _SettingsSection(
            children: [
              _SettingsTile(
                leading: const _IconBadge(
                  icon: Icons.cleaning_services_outlined,
                ),
                title: '清除缓存',
                subtitle: '接口缓存数据',
                value: _cacheSize,
                onTap: () => _clearCache(context),
              ),
            ],
          ),

          // ── Pro membership ───────────────────────────────────────────────────
          const _SectionHeader(title: 'Pro'),
          _SettingsSection(
            children: [
              _SettingsTile(
                leading: const _IconBadge(
                  icon: Icons.workspace_premium_outlined,
                ),
                title: 'CopoHub Pro',
                subtitle: '解锁全部高级功能',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/member'),
              ),
            ],
          ),

          // ── About section ────────────────────────────────────────────────────
          const _SectionHeader(title: '关于'),
          _SettingsSection(
            children: [
              FutureBuilder<AppInfo>(
                future: AppInfoService.instance.info,
                builder: (context, snapshot) {
                  return _SettingsTile(
                    leading: const _IconBadge(icon: Icons.info_outline),
                    title: '版本',
                    value: snapshot.data?.version ?? '',
                  );
                },
              ),
              const _SectionDivider(),
              const _SettingsTile(
                leading: _IconBadge(icon: Icons.mail_outline),
                title: '联系方式',
                subtitle: 'youdroid2048@gmail.com',
              ),
              const _SectionDivider(),
              _SettingsTile(
                leading: const _IconBadge(icon: Icons.feedback_outlined),
                title: '用户反馈',
                subtitle: '通过邮箱发送您的意见和建议',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openFeedbackEmail(context),
              ),
              const _SectionDivider(),
              _SettingsTile(
                leading: const _IconBadge(icon: Icons.privacy_tip_outlined),
                title: '隐私政策与协议',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog(
                  context: context,
                  builder: (_) =>
                      const PolicyDialog(initialTab: PolicyTab.privacy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingsSection(
            children: [
              _SettingsTile(
                leading: _IconBadge(
                  icon: Icons.logout,
                  color: cs.error,
                ),
                title: '退出登录',
                titleColor: cs.error,
                onTap: () => _confirmLogout(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openFeedbackEmail(BuildContext context) async {
    final version = await AppInfoService.instance.fullVersion;
    final login = AuthService.instance.currentUser?.login ?? 'Unknown';
    final subject = Uri.encodeComponent('CopoHub 用户反馈');
    final body = Uri.encodeComponent(
      'App 版本：$version\n'
      'GitHub 账号：$login\n\n'
      '问题描述：\n（请描述您遇到的问题或建议）\n\n'
      '复现步骤：\n1. \n2. \n3. \n',
    );
    final uri = Uri.parse(
      'mailto:youdroid2048@gmail.com?subject=$subject&body=$body',
    );
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到邮件应用，请手动联系 youdroid2048@gmail.com')),
      );
    }
  }

  Future<void> _clearCache(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '清除缓存',
      message: '确定要清除所有接口缓存数据吗？',
      confirmLabel: '清除',
      icon: Icons.cleaning_services_outlined,
    );
    if (confirmed) {
      await GitHubApiClient.instance.clearAllCaches();
      if (context.mounted) {
        setState(() => _cacheSize = ApiCache.instance.formattedSize);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('缓存已清除')));
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '退出登录',
      message: '确定要退出登录吗？',
      confirmLabel: '退出',
      icon: Icons.logout,
      isDestructive: true,
    );
    if (confirmed) {
      await AuthService.instance.logout();
    }
  }
}

// ── Theme mode tile ───────────────────────────────────────────────────────────

class _ThemeModeTile extends StatefulWidget {
  const _ThemeModeTile({required this.themeService});
  final ThemeService themeService;

  @override
  State<_ThemeModeTile> createState() => _ThemeModeTileState();
}

class _ThemeModeTileState extends State<_ThemeModeTile> {
  @override
  void initState() {
    super.initState();
    widget.themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    widget.themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  static const _labels = {
    ThemeMode2.auto: '跟随系统',
    ThemeMode2.light: '浅色',
    ThemeMode2.dark: '深色',
  };

  static const _icons = {
    ThemeMode2.auto: Icons.brightness_auto,
    ThemeMode2.light: Icons.light_mode_outlined,
    ThemeMode2.dark: Icons.dark_mode_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final current = widget.themeService.themeMode;
    return _SettingsExpansionTile(
      leading: _IconBadge(icon: _icons[current] ?? Icons.brightness_auto),
      title: const Text('主题模式'),
      trailing: Text(
        _labels[current] ?? '',
        style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13),
      ),
      children: ThemeMode2.values
          .map((m) => ListTile(
                leading: Icon(_icons[m], size: 20),
                contentPadding: const EdgeInsets.only(left: 72, right: 16),
                title: Text(_labels[m] ?? ''),
                trailing: m == current
                    ? Icon(Icons.check,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => widget.themeService.setThemeMode(m),
              ))
          .toList(),
    );
  }
}

// ── Contribution theme tile ───────────────────────────────────────────────────

class _ContributionThemeTile extends StatefulWidget {
  const _ContributionThemeTile({required this.themeService});
  final ThemeService themeService;

  @override
  State<_ContributionThemeTile> createState() => _ContributionThemeTileState();
}

class _ContributionThemeTileState extends State<_ContributionThemeTile> {
  @override
  void initState() {
    super.initState();
    widget.themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    widget.themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final current = widget.themeService.contributionTheme;
    const themes = Constants.contributionThemes;

    return _SettingsExpansionTile(
      leading: const _IconBadge(icon: Icons.palette_outlined),
      title: const Text('贡献图颜色'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Preview dots
          ...(() {
            final theme = themes.where((t) => t.name == current).firstOrNull;
            return (theme?.colors ?? themes.first.colors)
                .skip(1)
                .map((hex) => Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: Color(
                            int.tryParse(hex.replaceFirst('#', '0xFF')) ??
                                0xFF000000),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ))
                .toList();
          })(),
        ],
      ),
      children: themes
          .map((t) => ListTile(
                contentPadding: const EdgeInsets.only(left: 72, right: 16),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...t.colors.skip(1).map((hex) => Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.only(right: 3),
                          decoration: BoxDecoration(
                            color: Color(
                                int.tryParse(hex.replaceFirst('#', '0xFF')) ??
                                    0xFF000000),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        )),
                  ],
                ),
                title: Text(t.name),
                trailing: t.name == current
                    ? Icon(Icons.check,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => widget.themeService.setContributionTheme(t.name),
              ))
          .toList(),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    if (title.isEmpty) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(children: children),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.leading,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.titleColor,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final Color? titleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveTrailing = trailing ??
        (value == null
            ? null
            : Text(
                value!,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ));

    return ListTile(
      minVerticalPadding: 10,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: leading,
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? cs.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13,
                height: 1.25,
              ),
            ),
      trailing: effectiveTrailing,
      onTap: onTap,
    );
  }
}

class _SettingsExpansionTile extends StatelessWidget {
  const _SettingsExpansionTile({
    required this.leading,
    required this.title,
    required this.trailing,
    required this.children,
  });

  final Widget leading;
  final Widget title;
  final Widget trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.only(bottom: 6),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: leading,
        title: DefaultTextStyle.merge(
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          child: title,
        ),
        trailing: trailing,
        children: children,
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    this.color,
  });

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconColor = color ?? cs.onSurfaceVariant;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: iconColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: iconColor, size: 22),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 66,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
