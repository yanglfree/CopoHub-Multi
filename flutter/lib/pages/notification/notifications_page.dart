import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/github_api_client.dart';
import '../../models/notification.dart';
import '../../l10n/app_localizations.dart';

/// "Notifications" tab — GitHub notifications list.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _api = GitHubApiClient.instance;

  List<GithubNotification> _all = [];
  String _filter = 'all'; // all | unread | pr | issue
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<(String, String)> _getFilterTabs(AppLocalizations l10n) => [
        ('all', l10n.filterAll),
        ('unread', l10n.unread),
        ('pr', 'PR'),
        ('issue', 'Issue'),
      ];

  List<GithubNotification> get _filtered {
    if (_filter == 'all') return _all;
    if (_filter == 'unread') return _all.where((n) => n.unread).toList();
    if (_filter == 'pr') {
      return _all.where((n) => n.subject.type == 'PullRequest').toList();
    }
    if (_filter == 'issue') {
      return _all.where((n) => n.subject.type == 'Issue').toList();
    }
    return _all;
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading || _loadingMore) return;
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }
    if (_page == 1) {
      setState(() {
        _loading = true;
        _error = '';
      });
    } else {
      setState(() => _loadingMore = true);
    }

    final result = await _api.getNotifications(
      all: true,
      page: _page,
      perPage: 30,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final raw = result.data ?? [];
      final items = raw
          .map((e) => GithubNotification.fromJson(e))
          .toList();
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (refresh || _page == 1) {
          _all = items;
        } else {
          _all = [..._all, ...items];
        }
        _hasMore = items.length >= 30;
        _page++;
      });
    } else {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = result.message ?? '加载失败';
      });
    }
  }

  Future<void> _markAllRead() async {
    await _api.markAllNotificationsRead();
    await _load(refresh: true);
  }

  Future<void> _markRead(String threadId) async {
    await _api.markThreadRead(threadId);
    setState(() {
      _all = _all.map((n) {
        if (n.id == threadId) {
          return GithubNotification(
            id: n.id,
            unread: false,
            reason: n.reason,
            updatedAt: n.updatedAt,
            lastReadAt: n.lastReadAt,
            subject: n.subject,
            repository: n.repository,
          );
        }
        return n;
      }).toList();
    });
  }

  void _openNotification(GithubNotification n) {
    final owner = n.repository?.ownerLogin ?? '';
    final repo = n.repository?.name ?? '';
    if (owner.isEmpty || repo.isEmpty) return;

    if (n.unread) _markRead(n.id);

    switch (n.subject.type) {
      case 'Issue':
        final num = _extractNumber(n.subject.url);
        if (num != null) context.push('/issue/$owner/$repo/$num');
      case 'PullRequest':
        final num = _extractNumber(n.subject.url);
        if (num != null) context.push('/pr/$owner/$repo/$num');
      default:
        context.push('/repository/$owner/$repo');
    }
  }

  int? _extractNumber(String? url) {
    if (url == null) return null;
    final parts = url.split('/');
    return int.tryParse(parts.last);
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _all.where((n) => n.unread).length;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            forceElevated: innerBoxIsScrolled,
            title: Row(
              children: [
                Text(l10n.notificationsTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$unreadCount',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (unreadCount > 0)
                IconButton(
                  icon: const Icon(Icons.done_all),
                  tooltip: l10n.markAllAsRead,
                  onPressed: _markAllRead,
                ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: _FilterBar(
                selected: _filter,
                tabs: _getFilterTabs(l10n),
                onSelect: (v) => setState(() => _filter = v),
              ),
            ),
          ),
        ],
        body: _buildBody(l10n),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _filtered;

    if (_error.isNotEmpty && items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(_error, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed: () => _load(refresh: true),
                  child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notifications_none, size: 64),
                  const SizedBox(height: 12),
                  Text(l10n.noNotifications),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView.separated(
        itemCount: items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, i) {
          if (i >= items.length) {
            _load();
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _NotificationTile(
            notification: items[i],
            onTap: () => _openNotification(items[i]),
            onMarkRead: () => _markRead(items[i].id),
          );
        },
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.tabs,
    required this.onSelect,
  });
  final String selected;
  final List<(String, String)> tabs;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: tabs.map((t) {
          final (key, label) = t;
          final active = key == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: active,
              onSelected: (_) => onSelect(key),
              side: active ? BorderSide.none : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Notification tile ─────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onMarkRead,
  });
  final GithubNotification notification;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;

  IconData get _subjectIcon {
    switch (notification.subject.type) {
      case 'PullRequest':
        return Icons.call_merge;
      case 'Release':
        return Icons.new_releases_outlined;
      case 'Commit':
        return Icons.commit;
      default:
        return Icons.bug_report_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unread = notification.unread;
    final avatar = notification.repository?.ownerAvatarUrl ?? '';

    return InkWell(
      onTap: onTap,
      child: Container(
        color: unread
            ? cs.primaryContainer.withAlpha(50)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unread dot
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unread ? cs.primary : Colors.transparent,
                ),
              ),
            ),
            // Repo avatar
            if (avatar.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: avatar,
                    width: 36,
                    height: 36,
                    placeholder: (_, __) => Container(
                        width: 36,
                        height: 36,
                        color: cs.surfaceContainerHighest),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.account_circle, size: 36),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Repo name
                  Text(
                    notification.repository?.fullName ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Subject title
                  Row(
                    children: [
                      Icon(_subjectIcon, size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          notification.subject.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: unread
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _ReasonChip(reason: notification.reason),
                      const Spacer(),
                      if (unread)
                        GestureDetector(
                          onTap: onMarkRead,
                          child: Icon(Icons.check_circle_outline,
                              size: 18, color: cs.outline),
                        ),
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

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.reason});
  final String reason;

  Map<String, String> _getLabels(AppLocalizations l10n) => {
        'mention': l10n.reasonMention,
        'assign': l10n.reasonAssign,
        'author': l10n.reasonAuthor,
        'comment': l10n.reasonComment,
        'subscribed': l10n.reasonSubscribed,
        'review_requested': l10n.reasonReviewRequested,
        'state_change': l10n.reasonStateChange,
        'team_mention': l10n.reasonTeamMention,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = _getLabels(l10n)[reason] ?? reason;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontSize: 11)),
    );
  }
}
