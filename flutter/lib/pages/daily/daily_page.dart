import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/daily_api_client.dart';
import '../../components/daily/daily_report_share_card.dart';
import '../../components/daily/daily_report_view.dart';
import '../../models/trending_item.dart';
import '../../utils/constants.dart';
import '../../utils/repo_metadata_style.dart';

/// "/daily" page — Trending repos + Daily Report.
/// Mirrors HarmonyOS DailyView.
class DailyPage extends StatefulWidget {
  const DailyPage({super.key});

  @override
  State<DailyPage> createState() => _DailyPageState();
}

class _DailyPageState extends State<DailyPage> {
  final _api = DailyApiClient.instance;

  String _selectedDate = _todayStr();
  int _segment = 0; // 0: Trending, 1: Daily Report

  // Trending state
  String _language = '';
  String _since = 'daily';
  List<TrendingItem> _trending = [];
  List<String> _languages = [];
  bool _trendingLoading = false;
  String _trendingError = '';

  // Report state
  Map<String, dynamic>? _report;
  bool _reportLoading = false;
  String _reportError = '';
  bool _reportNotFound = false;

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadTrending();
    _loadLanguages();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _loadTrending({bool forceRefresh = false}) async {
    if (_trendingLoading) return;
    if (forceRefresh) await _api.clearCache(date: _selectedDate);

    setState(() {
      _trendingLoading = true;
      _trendingError = '';
    });

    final result = await _api.getTrending(
      _selectedDate,
      language: _language.isEmpty ? null : _language,
      since: _since,
      limit: 25,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _trending = result.data?.items ?? [];
        _trendingLoading = false;
      });
    } else {
      setState(() {
        _trendingError = result.message ?? '加载失败';
        _trendingLoading = false;
      });
    }
  }

  Future<void> _loadReport({bool forceRefresh = false}) async {
    if (_reportLoading) return;
    if (forceRefresh) await _api.clearCache(date: _selectedDate);

    setState(() {
      _reportLoading = true;
      _reportError = '';
    });

    final result = await _api.getDailyReport(_selectedDate);
    final trendingResult = result.isSuccess
        ? await _api.getTrending(_selectedDate, limit: 50)
        : null;
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _reportNotFound = false;
        _report = dailyReportWithRepositoryData(
          result.data!,
          trendingResult?.data?.items
                  .map((item) => {
                        'owner': item.owner,
                        'name': item.name,
                        'description': item.description,
                        'stars': item.stars,
                        'language': item.language,
                        'url': item.url,
                      })
                  .toList() ??
              const <Map<String, dynamic>>[],
        );
        _reportLoading = false;
      });
    } else if (result.error == 'not_found') {
      setState(() {
        _reportNotFound = true;
        final isToday = _selectedDate == _todayStr();
        _reportError = isToday ? '今日报告尚未生成\n通常于每天下午发布，请稍后再来' : '该日期暂无报告数据';
        _reportLoading = false;
      });
    } else {
      setState(() {
        _reportNotFound = false;
        _reportError = result.message ?? '加载失败';
        _reportLoading = false;
      });
    }
  }

  Future<void> _loadLanguages() async {
    final result = await _api.getLanguages();
    if (mounted && result.isSuccess) {
      setState(() => _languages = result.data ?? []);
    }
  }

  void _changeDate(int delta) {
    final current = DateTime.tryParse(_selectedDate) ?? DateTime.now();
    final next = current.add(Duration(days: delta));
    final today = DateTime.now();
    if (next.isAfter(today)) return;

    setState(() {
      _selectedDate =
          '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
      _trending = [];
      _report = null;
    });

    if (_segment == 0) {
      _loadTrending();
    } else {
      _loadReport();
    }
  }

  void _switchSegment(int index) {
    if (_segment == index) return;
    setState(() => _segment = index);
    if (index == 0 && _trending.isEmpty) _loadTrending();
    if (index == 1 && _report == null) _loadReport();
  }

  // ── UI ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Daily', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_segment == 0) {
                _loadTrending(forceRefresh: true);
              } else {
                _loadReport(forceRefresh: true);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _DatePickerHeader(
            date: _selectedDate,
            onPrev: () => _changeDate(-1),
            onNext: () => _changeDate(1),
          ),
          _SegmentControl(
            selected: _segment,
            onSelect: _switchSegment,
          ),
          Expanded(
            child: _segment == 0 ? _buildTrending() : _buildReport(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrending() {
    return Column(
      children: [
        _FilterBar(
          selectedLanguage: _language,
          languages: _languages,
          since: _since,
          onLanguageChanged: (lang) {
            setState(() {
              _language = lang;
              _trending = [];
            });
            _loadTrending();
          },
          onSinceChanged: (since) {
            setState(() {
              _since = since;
              _trending = [];
            });
            _loadTrending();
          },
        ),
        Expanded(
          child: _trendingLoading && _trending.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _trendingError.isNotEmpty && _trending.isEmpty
                  ? _ErrorView(
                      message: _trendingError,
                      onRetry: () => _loadTrending(forceRefresh: true))
                  : _trending.isEmpty
                      ? const _EmptyView(message: '暂无 Trending 数据')
                      : RefreshIndicator(
                          onRefresh: () => _loadTrending(forceRefresh: true),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _trending.length,
                            separatorBuilder: (_, __) => const Divider(
                                height: 1, indent: 16, endIndent: 16),
                            itemBuilder: (context, i) =>
                                _TrendingCard(item: _trending[i]),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildReport() {
    if (_reportLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reportError.isNotEmpty) {
      if (_reportNotFound) return _ReportNotReadyView(message: _reportError);
      return _ErrorView(
          message: _reportError,
          onRetry: () => _loadReport(forceRefresh: true));
    }
    if (_report == null) {
      return const _EmptyView(message: '暂无报告数据');
    }
    return DailyReportView(
      report: _report!,
      onShare: () => showDailyReportShareSheet(context, _report!),
    );
  }
}

// ── Date picker header ────────────────────────────────────────────────────────

class _DatePickerHeader extends StatelessWidget {
  const _DatePickerHeader({
    required this.date,
    required this.onPrev,
    required this.onNext,
  });
  final String date;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final current = DateTime.tryParse(date);
    final isToday = current != null &&
        current.year == today.year &&
        current.month == today.month &&
        current.day == today.day;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
          GestureDetector(
            onTap: () {},
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatDailyReportDateLabel(date),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isToday ? null : onNext,
          ),
        ],
      ),
    );
  }
}

// ── Segment control ───────────────────────────────────────────────────────────

class _SegmentControl extends StatelessWidget {
  const _SegmentControl({required this.selected, required this.onSelect});
  final int selected;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 44,
      color: cs.surfaceContainer,
      child: Row(
        children: [
          Expanded(
            child: _SegTab(
                label: 'Trending',
                icon: Icons.trending_up,
                active: selected == 0,
                onTap: () => onSelect(0)),
          ),
          Expanded(
            child: _SegTab(
                label: 'Daily Report',
                icon: Icons.article_outlined,
                active: selected == 1,
                onTap: () => onSelect(1)),
          ),
        ],
      ),
    );
  }
}

class _SegTab extends StatelessWidget {
  const _SegTab({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? cs.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16, color: active ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedLanguage,
    required this.languages,
    required this.since,
    required this.onLanguageChanged,
    required this.onSinceChanged,
  });
  final String selectedLanguage;
  final List<String> languages;
  final String since;
  final void Function(String) onLanguageChanged;
  final void Function(String) onSinceChanged;

  static const _sinceLabels = {
    'daily': '日',
    'weekly': '周',
    'monthly': '月',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Language dropdown
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedLanguage.isEmpty ? '' : selectedLanguage,
                isExpanded: true,
                hint: const Text('语言', style: TextStyle(fontSize: 13)),
                items: [
                  const DropdownMenuItem(value: '', child: Text('全部语言')),
                  ...languages.map((l) => DropdownMenuItem(
                        value: l,
                        child: Text(l, style: const TextStyle(fontSize: 13)),
                      )),
                ],
                onChanged: (v) => onLanguageChanged(v ?? ''),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Time range pills
          ...['daily', 'weekly', 'monthly'].map((s) {
            final active = since == s;
            return Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ChoiceChip(
                label: Text(_sinceLabels[s]!,
                    style: const TextStyle(fontSize: 12)),
                selected: active,
                onSelected: (_) => onSinceChanged(s),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Trending card ─────────────────────────────────────────────────────────────

class _TrendingCard extends StatelessWidget {
  const _TrendingCard({required this.item});
  final TrendingItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final metadataColor = repoMetadataColor(cs);
    final metadataStyle = repoMetadataTextStyle(context);

    return InkWell(
      onTap: () => context.push('/repository/${item.owner}/${item.name}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rank badge
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: item.rank <= 3
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${item.rank}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: item.rank <= 3 ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.fullName,
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.rankDiff != 0)
                        _RankDeltaBadge(delta: item.rankDiff),
                    ],
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (item.language.isNotEmpty) ...[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Color(int.tryParse(
                                    Constants.getLanguageColor(item.language)
                                        .replaceFirst('#', '0xFF')) ??
                                0xFF8b949e),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(item.language, style: metadataStyle),
                        const SizedBox(width: 12),
                      ],
                      Icon(Icons.star_border, size: 13, color: metadataColor),
                      const SizedBox(width: 2),
                      Text(_fmt(item.stars), style: metadataStyle),
                      if (item.starsDelta > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '+${_fmt(item.starsDelta)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(width: 10),
                      Icon(Icons.fork_right, size: 13, color: metadataColor),
                      const SizedBox(width: 2),
                      Text(_fmt(item.forks), style: metadataStyle),
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

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

class _RankDeltaBadge extends StatelessWidget {
  const _RankDeltaBadge({required this.delta});
  final int delta;

  @override
  Widget build(BuildContext context) {
    final up = delta > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: (up ? Colors.green : Colors.red).withAlpha(30),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.arrow_upward : Icons.arrow_downward,
            size: 10,
            color: up ? Colors.green.shade700 : Colors.red.shade700,
          ),
          Text(
            '${delta.abs()}',
            style: TextStyle(
              fontSize: 10,
              color: up ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _ReportNotReadyView extends StatelessWidget {
  const _ReportNotReadyView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_outlined,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message),
          ],
        ),
      );
}
