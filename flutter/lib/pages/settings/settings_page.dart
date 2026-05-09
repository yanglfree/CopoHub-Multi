import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/github_api_client.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../utils/constants.dart';
import '../../components/dialogs/app_dialog.dart';
import '../../components/policy/policy_dialog.dart';

/// App settings page — mirrors HarmonyOS SettingsView.
/// Theme mode, contribution color theme, cache clear, about, logout.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _themeService = ThemeService.instance;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = AuthService.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        children: [
          // ── Account section ──────────────────────────────────────────────────
          const _SectionHeader(title: '账号'),
          if (user != null)
            ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(user.avatarUrl),
              ),
              title: Text(user.name.isNotEmpty ? user.name : user.login,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('@${user.login}'),
              onTap: () => context.push('/user/${user.login}'),
            ),

          // ── Appearance section ───────────────────────────────────────────────
          const _SectionHeader(title: '外观'),
          _ThemeModeTile(themeService: _themeService),
          const Divider(height: 1, indent: 16),
          _ContributionThemeTile(themeService: _themeService),

          // ── Data section ─────────────────────────────────────────────────────
          const _SectionHeader(title: '数据'),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('清除缓存'),
            subtitle: const Text('清除接口缓存数据'),
            onTap: () => _clearCache(context),
          ),

          // ── Pro membership ───────────────────────────────────────────────────
          const _SectionHeader(title: 'Pro'),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('CopoHub Pro'),
            subtitle: const Text('解锁全部高级功能'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/member'),
          ),

          // ── About section ────────────────────────────────────────────────────
          const _SectionHeader(title: '关于'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('版本'),
            trailing: Text(Constants.appVersion,
                style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('联系方式'),
            subtitle: Text(
              'youdroid2048@gmail.com',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('用户反馈'),
            subtitle: const Text('通过邮箱发送您的意见和建议'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openFeedbackEmail(context),
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('隐私政策与协议'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDialog(
              context: context,
              builder: (_) => const PolicyDialog(initialTab: PolicyTab.privacy),
            ),
          ),

          // ── Danger zone ──────────────────────────────────────────────────────
          const _SectionHeader(title: ''),
          ListTile(
            leading: Icon(Icons.logout, color: cs.error),
            title: Text('退出登录', style: TextStyle(color: cs.error)),
            onTap: () => _confirmLogout(context),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _openFeedbackEmail(BuildContext context) async {
    const version = Constants.appVersion;
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
    return ExpansionTile(
      leading: Icon(_icons[current]),
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

    return ExpansionTile(
      leading: const Icon(Icons.palette_outlined),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
