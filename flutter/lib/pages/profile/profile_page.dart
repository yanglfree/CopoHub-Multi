import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/github_api_client.dart';
import '../../components/feedback/api_error_view.dart';
import '../../components/contribution/contribution_calendar.dart';
import '../../components/dialogs/app_dialog.dart';
import '../../models/github_org.dart';
import '../../models/pinned_repository.dart';
import '../../models/user.dart';
import '../../models/user_activity.dart';
import '../../models/user_status.dart';
import '../../router/app_router.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_localizations.dart';
import '../../components/skeleton/skeleton.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = AuthService.instance;
  final _api = GitHubApiClient.instance;

  List<GithubOrg> _orgs = [];
  bool _orgsLoading = true;

  List<PinnedRepository> _pinnedRepos = [];
  bool _pinnedLoading = true;
  bool _pinnedIsTopRepos = false;

  UserActivitySummary? _activity;
  bool _activityLoading = true;

  GithubUserStatus? _status;

  List<GithubUser> _followers = [];
  List<GithubUser> _following = [];
  bool _socialLoading = true;
  String _socialError = '';

  @override
  void initState() {
    super.initState();
    final login = _auth.currentUser?.login ?? '';
    if (login.isNotEmpty) {
      _loadOrgs(login);
      _loadPinnedOrTopRepos(login);
      _loadActivity();
      _loadStatus(login);
      _loadSocial(login);
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
      debugPrint('Loaded ${events.length} events from /user/events');
      int commitCount = 0;
      int repoCount = 0;
      int prCount = 0;

      for (final event in events) {
        final type = event['type'] as String? ?? '';
        final payload = event['payload'] as Map<String, dynamic>?;
        // debugPrint('Event type: $type');
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

      debugPrint('Calculated activity: commits=$commitCount, repos=$repoCount, prs=$prCount');

      setState(() {
        _activity = UserActivitySummary(
          commitCount: commitCount,
          repoCount: repoCount,
          prCount: prCount,
        );
        _activityLoading = false;
      });
    } else {
      debugPrint('Failed to load events: ${result.message}');
      setState(() => _activityLoading = false);
    }
  }

  Future<void> _loadStatus(String login) async {
    final result = await _api.getUserStatus(login);
    if (!mounted) return;
    if (result.success) {
      setState(() => _status = result.data);
    }
  }

  Future<void> _showEditProfileDialog(GithubUser user) async {
    final updated = await showDialog<GithubUser>(
      context: context,
      builder: (context) => _EditProfileDialog(user: user),
    );
    if (updated == null || !mounted) return;
    setState(() {});
  }

  Future<void> _showEditStatusDialog() async {
    final updated = await showDialog<GithubUserStatus?>(
      context: context,
      builder: (context) => _EditStatusDialog(status: _status),
    );
    if (updated == null || !mounted) return;
    setState(() => _status = updated.isEmpty ? null : updated);
  }

  Future<void> _loadSocial(String login) async {
    setState(() {
      _socialLoading = true;
      _socialError = '';
    });

    final results = await Future.wait([
      _api.getUserFollowers(login, perPage: 20),
      _api.getUserFollowing(login, perPage: 20),
    ]);

    if (!mounted) return;
    final followers = results[0];
    final following = results[1];
    setState(() {
      _socialLoading = false;
      _followers = followers.data ?? [];
      _following = following.data ?? [];
      if (!followers.success || !following.success) {
        _socialError = followers.message ??
            following.message ??
            AppLocalizations.of(context).loadFailed;
      }
    });
  }

  Future<void> _refreshProfile(String login) async {
    await Future.wait([
      _loadOrgs(login),
      _loadPinnedOrTopRepos(login),
      _loadActivity(),
      _loadStatus(login),
      _loadSocial(login),
    ]);
  }

  Future<void> _refreshSocial(String login) async {
    await _loadSocial(login);
  }

  SliverAppBar _buildAppBar(GithubUser user) {
    return SliverAppBar(
      pinned: true,
      title: const Text(
        '我的',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      actions: [
        IconButton(
          tooltip: AppLocalizations.of(context).settings,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push(AppRoutes.settings),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _refreshProfile(user.login),
              child: CustomScrollView(
                slivers: [
                  // ── Simple pinned app bar (no expandedHeight) ──────────────
                  _buildAppBar(user),

                  // ── User card (auto-sizes to content, no fixed height) ─────
                  SliverToBoxAdapter(
                    child: _UserCard(
                      user: user,
                      status: _status,
                      onEditProfile: () => _showEditProfileDialog(user),
                      onEditStatus: _showEditStatusDialog,
                    ),
                  ),

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

                  SliverToBoxAdapter(
                    child: _SocialSection(
                      username: user.login,
                      followers: _followers,
                      following: _following,
                      followersCount: user.followers,
                      followingCount: user.following,
                      loading: _socialLoading,
                      error: _socialError,
                      onRetry: () => _refreshSocial(user.login),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text('CopoHub',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.outlineVariant,
                                fontSize: 12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ── User card (自适应高度，无 fixed expandedHeight) ─────────────────────────

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.status,
    required this.onEditProfile,
    required this.onEditStatus,
  });
  final GithubUser user;
  final GithubUserStatus? status;
  final VoidCallback onEditProfile;
  final VoidCallback onEditStatus;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: CachedNetworkImage(
                  imageUrl: user.avatarUrl,
                  width: 72,
                  height: 72,
                  placeholder: (_, __) => Container(
                      width: 72, height: 72, color: cs.surfaceContainerHighest),
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
                    if (status?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      _StatusPill(status: status!, onTap: onEditStatus),
                    ],
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
          const SizedBox(height: 14),
          _ProfileActionButtons(
            status: status,
            onEditProfile: onEditProfile,
            onEditStatus: onEditStatus,
          ),
        ],
      ),
    );
  }
}

class _ProfileActionButtons extends StatelessWidget {
  const _ProfileActionButtons({
    required this.status,
    required this.onEditProfile,
    required this.onEditStatus,
  });

  final GithubUserStatus? status;
  final VoidCallback onEditProfile;
  final VoidCallback onEditStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _ProfileActionButton(
            icon: Icons.edit_outlined,
            label: l10n.editProfile,
            onPressed: onEditProfile,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ProfileActionButton(
            icon: Icons.emoji_emotions_outlined,
            label: status?.isNotEmpty == true ? l10n.changeStatus : l10n.setStatus,
            onPressed: onEditStatus,
          ),
        ),
      ],
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, this.onTap});
  final GithubUserStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = [
      if (status.emoji.isNotEmpty) _displayEmoji(status.emoji),
      if (status.message.isNotEmpty) status.message,
    ].join(' ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
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
      ),
    );
  }
}

String _displayEmoji(String raw) {
  final normalized = _canonicalStatusEmoji(raw);
  return _statusEmojiOptions
          .where((option) => option.value == normalized)
          .firstOrNull
          ?.emoji ??
      raw.trim();
}

String _canonicalStatusEmoji(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  final match = _statusEmojiOptions.where((option) {
    return option.value == value ||
        option.emoji == value ||
        option.value.replaceAll(':', '') == value.toLowerCase();
  }).firstOrNull;
  return match?.value ?? value;
}

class _StatusEmojiOption {
  const _StatusEmojiOption({
    required this.value,
    required this.emoji,
    required this.label,
  });

  final String value;
  final String emoji;
  final String label;
}

const _statusEmojiOptions = [
  _StatusEmojiOption(value: '', emoji: '·', label: '不显示 Emoji'),
  _StatusEmojiOption(value: ':palm_tree:', emoji: '🌴', label: '休假'),
  _StatusEmojiOption(value: ':house:', emoji: '🏠', label: '在家'),
  _StatusEmojiOption(value: ':office:', emoji: '🏢', label: '办公'),
  _StatusEmojiOption(value: ':rocket:', emoji: '🚀', label: '推进中'),
  _StatusEmojiOption(value: ':eyes:', emoji: '👀', label: '关注中'),
  _StatusEmojiOption(value: ':coffee:', emoji: '☕', label: '喝咖啡'),
  _StatusEmojiOption(value: ':memo:', emoji: '📝', label: '记录'),
  _StatusEmojiOption(value: ':computer:', emoji: '💻', label: '编码'),
  _StatusEmojiOption(value: ':wave:', emoji: '👋', label: '打招呼'),
  _StatusEmojiOption(value: ':sleeping:', emoji: '😴', label: '休息'),
];

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.user});
  final GithubUser user;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _blog;
  late final TextEditingController _twitter;
  late final TextEditingController _company;
  late final TextEditingController _location;
  late final TextEditingController _bio;
  late bool _hireable;
  bool _saving = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _name = TextEditingController(text: user.name);
    _email = TextEditingController(text: user.email);
    _blog = TextEditingController(text: user.blog);
    _twitter = TextEditingController(text: user.twitterUsername);
    _company = TextEditingController(text: user.company);
    _location = TextEditingController(text: user.location);
    _bio = TextEditingController(text: user.bio);
    _hireable = user.hireable ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _blog.dispose();
    _twitter.dispose();
    _company.dispose();
    _location.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = '';
    });

    final result = await AuthService.instance.updateCurrentUserProfile(
      name: _name.text.trim(),
      email: _email.text.trim(),
      blog: _blog.text.trim(),
      twitterUsername: _twitter.text.trim(),
      company: _company.text.trim(),
      location: _location.text.trim(),
      hireable: _hireable,
      bio: _bio.text.trim(),
    );

    if (!mounted) return;
    if (result.success && result.user != null) {
      Navigator.pop(context, result.user);
      return;
    }
    setState(() {
      _saving = false;
      _error = result.message ?? AppLocalizations.of(context).loadFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: l10n.editProfileTitle,
      icon: Icons.edit_outlined,
      actions: [
        AppDialogAction(
          label: l10n.cancel,
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        AppDialogAction(
          label: l10n.save,
          isPrimary: true,
          isLoading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProfileTextField(
                controller: _name, label: l10n.nameLabel, hint: l10n.notFilled),
            _ProfileTextField(
              controller: _email,
              label: l10n.emailLabel,
              hint: l10n.notFilled,
            ),
            _ProfileTextField(
                controller: _blog, label: l10n.blogLabel, hint: l10n.notFilled),
            _ProfileTextField(
              controller: _twitter,
              label: 'Twitter username',
              hint: l10n.notFilled,
            ),
            _ProfileTextField(
              controller: _company,
              label: l10n.companyLabel,
              hint: l10n.notFilled,
            ),
            _ProfileTextField(
              controller: _location,
              label: l10n.locationLabel,
              hint: l10n.notFilled,
            ),
            _ProfileTextField(
              controller: _bio,
              label: l10n.bioLabel,
              hint: l10n.notFilled,
              maxLines: 3,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _hireable,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _hireable = value ?? false),
              title: Text(l10n.availableForHire),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditStatusDialog extends StatefulWidget {
  const _EditStatusDialog({required this.status});
  final GithubUserStatus? status;

  @override
  State<_EditStatusDialog> createState() => _EditStatusDialogState();
}

class _EditStatusDialogState extends State<_EditStatusDialog> {
  late final TextEditingController _message;
  late String _selectedEmoji;
  late bool _limitedAvailability;
  bool _saving = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _selectedEmoji = _canonicalStatusEmoji(widget.status?.emoji ?? '');
    _message = TextEditingController(text: widget.status?.message ?? '');
    _limitedAvailability = widget.status?.indicatesLimitedAvailability ?? false;
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await _submit(clear: false);
  }

  Future<void> _clear() async {
    await _submit(clear: true);
  }

  Future<void> _submit({required bool clear}) async {
    if (_saving) return;
    final shouldClear =
        clear || (_selectedEmoji.isEmpty && _message.text.trim().isEmpty);
    setState(() {
      _saving = true;
      _error = '';
    });

    final result = await GitHubApiClient.instance.changeUserStatus(
      emoji: shouldClear ? '' : _selectedEmoji,
      message: shouldClear ? '' : _message.text.trim(),
      limitedAvailability: shouldClear ? false : _limitedAvailability,
    );

    if (!mounted) return;
    if (result.success) {
      Navigator.pop(
        context,
        shouldClear ? const GithubUserStatus() : result.data,
      );
      return;
    }
    setState(() {
      _saving = false;
      _error = result.message ?? AppLocalizations.of(context).loadFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: l10n.setStatus,
      icon: Icons.emoji_emotions_outlined,
      actions: [
        AppDialogAction(
          label: l10n.clear,
          onPressed: _saving ? null : _clear,
        ),
        AppDialogAction(
          label: l10n.cancel,
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        AppDialogAction(
          label: l10n.save,
          isPrimary: true,
          isLoading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusEmojiDropdown(
              value: _selectedEmoji,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _selectedEmoji = value ?? ''),
            ),
            _ProfileTextField(
              controller: _message,
              label: l10n.statusMessageLabel,
              hint: l10n.notFilled,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _limitedAvailability,
              onChanged: _saving
                  ? null
                  : (value) => setState(
                        () => _limitedAvailability = value ?? false,
                      ),
              title: Text(l10n.busyLabel),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusEmojiDropdown extends StatelessWidget {
  const _StatusEmojiDropdown({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: _statusEmojiOptions.any((option) => option.value == value)
            ? value
            : '',
        decoration: InputDecoration(
          labelText: 'Emoji',
          border: const OutlineInputBorder(),
          isDense: true,
          hintStyle: TextStyle(
            color: cs.onSurfaceVariant.withAlpha(107),
          ),
        ),
        items: _statusEmojiOptions.map((option) {
          return DropdownMenuItem(
            value: option.value,
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    option.emoji,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Text(option.label),
              ],
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
          hintStyle: TextStyle(
            color: cs.onSurfaceVariant.withAlpha(107),
          ),
          labelStyle: TextStyle(
            color: cs.onSurfaceVariant.withAlpha(199),
          ),
        ),
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
    final l10n = AppLocalizations.of(context);
    final login = user.login;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              _StatItem(
                label: l10n.repositories,
                value: '${user.publicRepos}',
                onTap: () => context.push('/repos/$login'),
              ),
              const VerticalDivider(width: 1),
              _StatItem(
                label: l10n.followers,
                value: _fmt(user.followers),
                onTap: () => context.push('/social/$login/followers'),
              ),
              const VerticalDivider(width: 1),
              _StatItem(
                label: l10n.following,
                value: '${user.following}',
                onTap: () => context.push('/social/$login/following'),
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

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
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
      if (user.location.isNotEmpty) (Icons.location_on_outlined, user.location),
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
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
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
          Text(AppLocalizations.of(context).organizations,
              style: const TextStyle(fontWeight: FontWeight.w600)),
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
  const _ActivitySummaryCard({required this.activity, required this.loading});
  final UserActivitySummary? activity;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    if (loading) {
      return const _ActivitySummarySkeleton();
    }
    if (activity == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.recentActivity,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primaryContainer.withAlpha(140),
                    cs.secondaryContainer.withAlpha(89),
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
                        color: cs.surfaceContainerHighest.withAlpha(153),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l10n.last90Days,
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
                          label: l10n.commits,
                          icon: Icons.commit_rounded,
                          color: cs.primary,
                        ),
                      ),
                      Container(
                          width: 1,
                          height: 40,
                          color: cs.outlineVariant.withAlpha(128)),
                      Expanded(
                        child: _ActivityMetric(
                          value: activity!.repoCount,
                          label: l10n.newRepos,
                          icon: Icons.folder_special_outlined,
                          color: cs.secondary,
                        ),
                      ),
                      Container(
                          width: 1,
                          height: 40,
                          color: cs.outlineVariant.withAlpha(128)),
                      Expanded(
                        child: _ActivityMetric(
                          value: activity!.prCount,
                          label: l10n.pullRequests,
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
                  widget.isTopRepos ? AppLocalizations.of(context).topRepos : AppLocalizations.of(context).pinnedRepos,
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
        ? Color(int.tryParse(repo.languageColor.replaceFirst('#', '0xFF')) ??
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

// ── Social section ───────────────────────────────────────────────────────────

class _SocialSection extends StatefulWidget {
  const _SocialSection({
    required this.username,
    required this.followers,
    required this.following,
    required this.followersCount,
    required this.followingCount,
    required this.loading,
    required this.error,
    required this.onRetry,
  });
  final String username;
  final List<GithubUser> followers;
  final List<GithubUser> following;
  final int followersCount;
  final int followingCount;
  final bool loading;
  final String error;
  final VoidCallback onRetry;

  @override
  State<_SocialSection> createState() => _SocialSectionState();
}

class _SocialSectionState extends State<_SocialSection> {
  int _selectedIndex = 0;

  List<GithubUser> get _visibleUsers =>
      _selectedIndex == 0 ? widget.followers : widget.following;
  int get _visibleTotal =>
      _selectedIndex == 0 ? widget.followersCount : widget.followingCount;
  String get _visibleType => _selectedIndex == 0 ? 'followers' : 'following';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: cs.surfaceContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 20, color: cs.onSurface),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).social,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SocialTabs(
                  selectedIndex: _selectedIndex,
                  followersCount: widget.followersCount,
                  followingCount: widget.followingCount,
                  onSelected: (index) => setState(() => _selectedIndex = index),
                ),
                if (widget.loading)
                  const _SocialSectionSkeleton()
                else if (widget.error.isNotEmpty && _visibleUsers.isEmpty)
                  _SocialError(message: widget.error, onRetry: widget.onRetry)
                else if (_visibleUsers.isEmpty)
                  _SocialEmpty(isFollowers: _selectedIndex == 0)
                else
                  Column(
                    children: [
                      for (final user in _visibleUsers)
                        _SocialUserTile(
                          user: user,
                          onTap: () => context.push('/user/${user.login}'),
                        ),
                      if (_visibleTotal > _visibleUsers.length)
                        _SocialMoreTile(
                          onTap: () => context
                              .push('/social/${widget.username}/$_visibleType'),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialTabs extends StatelessWidget {
  const _SocialTabs({
    required this.selectedIndex,
    required this.followersCount,
    required this.followingCount,
    required this.onSelected,
  });
  final int selectedIndex;
  final int followersCount;
  final int followingCount;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          _SocialTab(
            title: l10n.followers,
            count: followersCount,
            selected: selectedIndex == 0,
            onTap: () => onSelected(0),
          ),
          _SocialTab(
            title: l10n.following,
            count: followingCount,
            selected: selectedIndex == 1,
            onTap: () => onSelected(1),
          ),
        ],
      ),
    );
  }
}

class _SocialTab extends StatelessWidget {
  const _SocialTab({
    required this.title,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = selected ? cs.primary : cs.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$title ($count)',
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 3,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: selected ? cs.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialUserTile extends StatelessWidget {
  const _SocialUserTile({required this.user, required this.onTap});
  final GithubUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: user.avatarUrl,
                width: 44,
                height: 44,
                placeholder: (_, __) => Container(
                  width: 44,
                  height: 44,
                  color: cs.surfaceContainerHighest,
                ),
                errorWidget: (_, __, ___) =>
                    Icon(Icons.account_circle, size: 44, color: cs.outline),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                user.name.isNotEmpty ? user.name : user.login,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.arrow_forward, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _SocialMoreTile extends StatelessWidget {
  const _SocialMoreTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppLocalizations.of(context).viewAll,
              style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward, size: 16, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

class _SocialError extends StatelessWidget {
  const _SocialError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ApiErrorView(
      message: message,
      onRetry: onRetry,
      title: l10n.socialLoadFailed,
      compact: true,
    );
  }
}

class _SocialEmpty extends StatelessWidget {
  const _SocialEmpty({required this.isFollowers});
  final bool isFollowers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 152,
      child: Center(
        child: Text(
          isFollowers ? l10n.noFollowers : l10n.noFollowing,
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _ActivitySummarySkeleton extends StatelessWidget {
  const _ActivitySummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 80, height: 18),
            const SizedBox(height: 10),
            SkeletonBox(
              height: 104,
              radius: 12,
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialSectionSkeleton extends StatelessWidget {
  const _SocialSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const SkeletonBox(width: 44, height: 44, radius: 22),
                const SizedBox(width: 14),
                const Expanded(
                  child: SkeletonBox(height: 16),
                ),
                const SizedBox(width: 40),
                SkeletonBox(
                  width: 18,
                  height: 18,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
