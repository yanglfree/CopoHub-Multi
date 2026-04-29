import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import '../../api/copohub_api_client.dart';
import '../../api/daily_api_client.dart';
import '../../models/copohub_curated_item.dart';
import '../../models/trending_item.dart';
import '../../utils/constants.dart';

/// "精选" tab page — mirrors HarmonyOS DailyView.
/// Contains two top-level tabs:
///   0: GitHub精选 — trending + daily report
///   1: CopoHub精选 — editorial curated list
class FeaturedPage extends StatefulWidget {
  const FeaturedPage({super.key});

  @override
  State<FeaturedPage> createState() => _FeaturedPageState();
}

class _FeaturedPageState extends State<FeaturedPage> {
  // ── Top-level tab ─────────────────────────────────────────────────────────
  int _topTab = 0; // 0: GitHub精选, 1: CopoHub精选

  // ── GitHub精选 state ──────────────────────────────────────────────────────
  final _dailyApi = DailyApiClient.instance;
  String _selectedDate = _todayStr();
  int _segment = 0; // 0: 热门项目, 1: 每日报告

  List<TrendingItem> _trending = [];
  bool _trendingLoading = false;
  String _trendingError = '';
  String _language = '';
  String _since = 'daily';
  List<String> _languages = [];

  Map<String, dynamic>? _report;
  bool _reportLoading = false;
  String _reportError = '';

  // ── CopoHub精选 state ─────────────────────────────────────────────────────
  final _copoApi = CopoHubApiClient.instance;
  List<CopoHubCuratedItem> _curated = [];
  bool _curatedLoading = false;
  String _curatedError = '';

  static String _todayStr() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadTrending();
    _loadLanguages();
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  Future<void> _loadTrending({bool force = false}) async {
    if (_trendingLoading) return;
    if (force) await _dailyApi.clearCache(date: _selectedDate);
    setState(() {
      _trendingLoading = true;
      _trendingError = '';
    });
    final result = await _dailyApi.getTrending(
      _selectedDate,
      language: _language.isEmpty ? null : _language,
      since: _since,
      limit: 25,
    );
    if (!mounted) return;
    setState(() {
      _trendingLoading = false;
      if (result.isSuccess) {
        _trending = result.data?.items ?? [];
      } else {
        _trendingError = result.message ?? '加载失败';
      }
    });
  }

  Future<void> _loadReport({bool force = false}) async {
    if (_reportLoading) return;
    if (force) await _dailyApi.clearCache(date: _selectedDate);
    setState(() {
      _reportLoading = true;
      _reportError = '';
    });
    final result = await _dailyApi.getLatestReport();
    if (!mounted) return;
    setState(() {
      _reportLoading = false;
      if (result.isSuccess) {
        _report = result.data;
      } else {
        _reportError = result.message ?? '加载失败';
      }
    });
  }

  Future<void> _loadLanguages() async {
    final result = await _dailyApi.getLanguages();
    if (mounted && result.isSuccess) {
      setState(() => _languages = result.data ?? []);
    }
  }

  Future<void> _loadCurated({bool force = false}) async {
    if (_curatedLoading) return;
    if (force) await _copoApi.clearCache();
    setState(() {
      _curatedLoading = true;
      _curatedError = '';
    });
    final result = await _copoApi.getCuratedList();
    if (!mounted) return;
    setState(() {
      _curatedLoading = false;
      if (result.isSuccess) {
        _curated = result.data ?? [];
      } else {
        _curatedError = result.message ?? '加载失败';
      }
    });
  }

  void _changeDate(int delta) {
    final current = DateTime.tryParse(_selectedDate) ?? DateTime.now();
    final next = current.add(Duration(days: delta));
    if (next.isAfter(DateTime.now())) return;
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

  void _switchTopTab(int index) {
    if (_topTab == index) return;
    setState(() => _topTab = index);
    if (index == 1 && _curated.isEmpty && !_curatedLoading) {
      _loadCurated();
    }
  }

  void _refresh() {
    if (_topTab == 0) {
      if (_segment == 0) {
        _loadTrending(force: true);
      } else {
        _loadReport(force: true);
      }
    } else {
      _loadCurated(force: true);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Custom header ─────────────────────────────────────────────
            Container(
              color: cs.surface,
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Text(
                    '精选',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.refresh, color: cs.primary),
                    onPressed: _refresh,
                    tooltip: '刷新',
                  ),
                ],
              ),
            ),
            // ── Top tab bar ───────────────────────────────────────────────
            _TopTabBar(
              selectedIndex: _topTab,
              onTap: _switchTopTab,
            ),
            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: _topTab == 0
                  ? _GitHubTab(
                      date: _selectedDate,
                      segment: _segment,
                      trending: _trending,
                      trendingLoading: _trendingLoading,
                      trendingError: _trendingError,
                      language: _language,
                      languages: _languages,
                      since: _since,
                      report: _report,
                      reportLoading: _reportLoading,
                      reportError: _reportError,
                      onPrevDate: () => _changeDate(-1),
                      onNextDate: () => _changeDate(1),
                      onSegmentChanged: _switchSegment,
                      onLanguageChanged: (l) {
                        setState(() {
                          _language = l;
                          _trending = [];
                        });
                        _loadTrending();
                      },
                      onSinceChanged: (s) {
                        setState(() {
                          _since = s;
                          _trending = [];
                        });
                        _loadTrending();
                      },
                      onRetryTrending: () => _loadTrending(force: true),
                      onRetryReport: () => _loadReport(force: true),
                    )
                  : _CopoHubTab(
                      items: _curated,
                      loading: _curatedLoading,
                      error: _curatedError,
                      onRetry: () => _loadCurated(force: true),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top tab bar ───────────────────────────────────────────────────────────────

class _TopTabBar extends StatelessWidget {
  const _TopTabBar({required this.selectedIndex, required this.onTap});
  final int selectedIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      child: Row(
        children: [
          _TopTabItem(
            label: 'GitHub精选',
            icon: Icons.local_fire_department_outlined,
            selected: selectedIndex == 0,
            onTap: () => onTap(0),
          ),
          _TopTabItem(
            label: 'CopoHub精选',
            icon: Icons.star_outline,
            selected: selectedIndex == 1,
            onTap: () => onTap(1),
          ),
        ],
      ),
    );
  }
}

class _TopTabItem extends StatelessWidget {
  const _TopTabItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? cs.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── GitHub精选 tab ────────────────────────────────────────────────────────────

class _GitHubTab extends StatelessWidget {
  const _GitHubTab({
    required this.date,
    required this.segment,
    required this.trending,
    required this.trendingLoading,
    required this.trendingError,
    required this.language,
    required this.languages,
    required this.since,
    required this.report,
    required this.reportLoading,
    required this.reportError,
    required this.onPrevDate,
    required this.onNextDate,
    required this.onSegmentChanged,
    required this.onLanguageChanged,
    required this.onSinceChanged,
    required this.onRetryTrending,
    required this.onRetryReport,
  });

  final String date;
  final int segment;
  final List<TrendingItem> trending;
  final bool trendingLoading;
  final String trendingError;
  final String language;
  final List<String> languages;
  final String since;
  final Map<String, dynamic>? report;
  final bool reportLoading;
  final String reportError;
  final VoidCallback onPrevDate;
  final VoidCallback onNextDate;
  final void Function(int) onSegmentChanged;
  final void Function(String) onLanguageChanged;
  final void Function(String) onSinceChanged;
  final VoidCallback onRetryTrending;
  final VoidCallback onRetryReport;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DatePickerHeader(
          date: date,
          onPrev: onPrevDate,
          onNext: onNextDate,
        ),
        _SegmentControl(
          selected: segment,
          onSelect: onSegmentChanged,
        ),
        Expanded(
          child: segment == 0
              ? _TrendingView(
                  trending: trending,
                  loading: trendingLoading,
                  error: trendingError,
                  language: language,
                  languages: languages,
                  since: since,
                  onLanguageChanged: onLanguageChanged,
                  onSinceChanged: onSinceChanged,
                  onRetry: onRetryTrending,
                )
              : _ReportView(
                  report: report,
                  loading: reportLoading,
                  error: reportError,
                  onRetry: onRetryReport,
                ),
        ),
      ],
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

  bool _isToday() {
    final today = DateTime.now();
    final current = DateTime.tryParse(date);
    return current != null &&
        current.year == today.year &&
        current.month == today.month &&
        current.day == today.day;
  }

  String _displayDate() {
    if (_isToday()) return '今天';
    try {
      final dt = DateTime.parse(date);
      return '${dt.year}年${dt.month.toString().padLeft(2, '0')}月${dt.day.toString().padLeft(2, '0')}日';
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 52,
      color: cs.surfaceContainer,
      child: Row(
        children: [
          IconButton(
              icon: const Icon(Icons.chevron_left), onPressed: onPrev),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _displayDate(),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down,
                      size: 18, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: _isToday() ? cs.onSurface.withOpacity(0.3) : null,
            ),
            onPressed: _isToday() ? null : onNext,
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
      height: 48,
      color: cs.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _SegBtn(
              label: '热门项目',
              icon: Icons.local_fire_department,
              active: selected == 0,
              onTap: () => onSelect(0),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SegBtn(
              label: '每日报告',
              icon: Icons.bar_chart_outlined,
              active: selected == 1,
              onTap: () => onSelect(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  const _SegBtn({
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
    return Material(
      color: active ? cs.primary : cs.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 15,
                  color: active ? Colors.white : cs.onSurface),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: active ? Colors.white : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Trending view ─────────────────────────────────────────────────────────────

class _TrendingView extends StatelessWidget {
  const _TrendingView({
    required this.trending,
    required this.loading,
    required this.error,
    required this.language,
    required this.languages,
    required this.since,
    required this.onLanguageChanged,
    required this.onSinceChanged,
    required this.onRetry,
  });
  final List<TrendingItem> trending;
  final bool loading;
  final String error;
  final String language;
  final List<String> languages;
  final String since;
  final void Function(String) onLanguageChanged;
  final void Function(String) onSinceChanged;
  final VoidCallback onRetry;

  static const _sinceLabels = {'daily': '日', 'weekly': '周', 'monthly': '月'};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter bar
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: language.isEmpty ? '' : language,
                    isExpanded: true,
                    hint: const Text('语言', style: TextStyle(fontSize: 13)),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('全部语言')),
                      ...languages.map((l) => DropdownMenuItem(
                            value: l,
                            child: Text(l,
                                style: const TextStyle(fontSize: 13)),
                          )),
                    ],
                    onChanged: (v) => onLanguageChanged(v ?? ''),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
        ),
        Expanded(
          child: loading && trending.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : error.isNotEmpty && trending.isEmpty
                  ? _ErrorRetry(message: error, onRetry: onRetry)
                  : trending.isEmpty
                      ? const _Empty(message: '暂无 Trending 数据')
                      : RefreshIndicator(
                          onRefresh: () async => onRetry(),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: trending.length,
                            separatorBuilder: (_, __) => const Divider(
                                height: 1, indent: 16, endIndent: 16),
                            itemBuilder: (context, i) =>
                                _TrendingCard(item: trending[i]),
                          ),
                        ),
        ),
      ],
    );
  }
}

// ── Trending card ─────────────────────────────────────────────────────────────

class _TrendingCard extends StatelessWidget {
  const _TrendingCard({required this.item});
  final TrendingItem item;

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                    ? (item.rank == 1
                        ? const Color(0xFFFFD700)
                        : item.rank == 2
                            ? const Color(0xFFC0C0C0)
                            : const Color(0xFFCD7F32))
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${item.rank}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: item.rank <= 3 ? Colors.white : cs.onSurfaceVariant,
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
                        _RankDelta(delta: item.rankDiff),
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
                        _LangDot(language: item.language),
                        const SizedBox(width: 12),
                      ],
                      const Icon(Icons.star_border, size: 13),
                      const SizedBox(width: 2),
                      Text(_fmt(item.stars),
                          style:
                              Theme.of(context).textTheme.bodySmall),
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
                      const Icon(Icons.fork_right, size: 13),
                      const SizedBox(width: 2),
                      Text(_fmt(item.forks),
                          style:
                              Theme.of(context).textTheme.bodySmall),
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

class _RankDelta extends StatelessWidget {
  const _RankDelta({required this.delta});
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

class _LangDot extends StatelessWidget {
  const _LangDot({required this.language});
  final String language;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Color(int.tryParse(
                      Constants.getLanguageColor(language)
                          .replaceFirst('#', '0xFF')) ??
                  0xFF8b949e),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(language,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

// ── Daily report view ─────────────────────────────────────────────────────────

class _ReportView extends StatelessWidget {
  const _ReportView({
    required this.report,
    required this.loading,
    required this.error,
    required this.onRetry,
  });
  final Map<String, dynamic>? report;
  final bool loading;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error.isNotEmpty) return _ErrorRetry(message: error, onRetry: onRetry);
    if (report == null) return const _Empty(message: '暂无报告数据');

    final data = report!;
    final summary = data['summary'] as String? ?? '';
    final topics = (data['topics'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList();
    final langSummaries =
        (data['language_summaries'] as Map<String, dynamic>? ?? {})
            .entries
            .toList();
    final topRepos = (data['top_repositories'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (summary.isNotEmpty) ...[
          Text('摘要',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          MarkdownBody(data: summary),
          const SizedBox(height: 20),
        ],
        if (topics.isNotEmpty) ...[
          Text('热门话题',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: topics
                .map((t) => Chip(
                      label: Text(t,
                          style: const TextStyle(fontSize: 12)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
        ],
        if (langSummaries.isNotEmpty) ...[
          Text('语言动态',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: langSummaries.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final entry = langSummaries[i];
                return _LanguageCard(
                    language: entry.key,
                    summary: entry.value as String? ?? '');
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (topRepos.isNotEmpty) ...[
          Text('精选仓库',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...topRepos.take(5).map((r) => _TopRepoTile(data: r)),
        ],
      ],
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.language, required this.summary});
  final String language;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = Color(int.tryParse(
            Constants.getLanguageColor(language)
                .replaceFirst('#', '0xFF')) ??
        0xFF8b949e);
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: color.withAlpha(80), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(language,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              summary,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopRepoTile extends StatelessWidget {
  const _TopRepoTile({required this.data});
  final Map<String, dynamic> data;

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  @override
  Widget build(BuildContext context) {
    final owner = data['owner'] as String? ?? '';
    final name = data['name'] as String? ?? '';
    final description = data['description'] as String? ?? '';
    final stars = data['stars'] as int? ?? 0;
    final language = data['language'] as String? ?? '';

    return InkWell(
      onTap: () {
        if (owner.isNotEmpty && name.isNotEmpty) {
          context.push('/repository/$owner/$name');
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$owner/$name',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                if (language.isNotEmpty) ...[
                  _LangDot(language: language),
                  const SizedBox(width: 10),
                ],
                const Icon(Icons.star_border, size: 13),
                const SizedBox(width: 2),
                Text(_fmt(stars),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── CopoHub精选 tab ───────────────────────────────────────────────────────────

class _CopoHubTab extends StatelessWidget {
  const _CopoHubTab({
    required this.items,
    required this.loading,
    required this.error,
    required this.onRetry,
  });
  final List<CopoHubCuratedItem> items;
  final bool loading;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error.isNotEmpty) return _ErrorRetry(message: error, onRetry: onRetry);
    if (items.isEmpty) return const _Empty(message: '暂无精选项目');

    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '由 CopoHub 编辑团队精心挑选',
                    style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Text(
                    '共 ${items.length} 个项目',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }
          return _CuratedCard(item: items[i - 1]);
        },
      ),
    );
  }
}

// ── Curated item card ─────────────────────────────────────────────────────────

class _CuratedCard extends StatelessWidget {
  const _CuratedCard({required this.item});
  final CopoHubCuratedItem item;

  static String _fmtStars(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  Color _rankBadgeColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return const Color(0xFF0969da);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => context.push(
          '/curated',
          extra: item,
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rank badge
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _rankBadgeColor(item.rank),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${item.rank}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Repo name + owner
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.repo,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          item.owner,
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  // Type tag
                  _TypeTag(item: item),
                ],
              ),

              // ── Description ────────────────────────────────────────────
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.description,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // ── Curator note ───────────────────────────────────────────
              if (item.curatorNote.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(8),
                    border: const Border(
                      left: BorderSide(
                          color: Color(0xFF0969da), width: 3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          size: 14, color: Color(0xFF0969da)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.curatorNote,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF0969da),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Bottom stats ───────────────────────────────────────────
              const SizedBox(height: 8),
              Row(
                children: [
                  if (item.language.isNotEmpty) ...[
                    _LangDot(language: item.language),
                    const SizedBox(width: 10),
                  ],
                  const Spacer(),
                  const Icon(Icons.star_border, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _fmtStars(item.stars),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant),
                  ),
                  if (item.forks > 0) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.fork_right, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _fmtStars(item.forks),
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeTag extends StatelessWidget {
  const _TypeTag({required this.item});
  final CopoHubCuratedItem item;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color bg;

    if (item.isPromoted) {
      label = '推广';
      bg = const Color(0xFFFF9500);
    } else if (item.rank == 0) {
      label = '新星';
      bg = const Color(0xFF8250df);
    } else if (item.stars > 10000) {
      label = '优质';
      bg = const Color(0xFF1a7f37);
    } else {
      label = '精选';
      bg = const Color(0xFF0969da);
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          message,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
}
