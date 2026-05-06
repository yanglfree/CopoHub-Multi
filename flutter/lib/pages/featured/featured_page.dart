import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/api_cache.dart';
import '../../api/copohub_api_client.dart';
import '../../api/daily_api_client.dart';
import '../../components/daily/daily_report_share_card.dart';
import '../../components/daily/daily_report_view.dart';
import '../../models/copohub_curated_item.dart';
import '../../models/deduplicated_repo_item.dart';
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
  int _segment = 0; // 0: 热门项目, 1: 每日报告, 2: 高频项目

  List<TrendingItem> _trending = [];
  bool _trendingLoading = false;
  String _trendingError = '';
  String _language = '';
  String _since = 'daily';
  List<String> _languages = [];

  Map<String, dynamic>? _report;
  bool _reportLoading = false;
  String _reportError = '';
  bool _reportNotFound = false;

  List<DeduplicatedRepoItem> _deduped = [];
  bool _dedupedLoading = false;
  String _dedupedError = '';
  String _dedupedSort = 'total'; // 'total' | 'recent'
  String _dedupedLanguage = '';

  // ── CopoHub精选 state ─────────────────────────────────────────────────────
  final _copoApi = CopoHubApiClient.instance;
  List<CopoHubCuratedItem> _curated = [];
  bool _curatedLoading = false;
  String _curatedError = '';

  static String _todayStr() {
    final n = DateTime.now();
    return _formatDate(n);
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadTrending();
    _loadLanguages();
  }

  Future<void> _loadDeduped({bool force = false}) async {
    if (_dedupedLoading) return;
    if (force) {
      await ApiCache.instance.invalidateMatching('/api/v1/trending/deduplicated');
    }
    setState(() {
      _dedupedLoading = true;
      _dedupedError = '';
    });
    final result = await _dailyApi.getDeduplicated(
      sort: _dedupedSort,
      language: _dedupedLanguage,
    );
    if (!mounted) return;
    setState(() {
      _dedupedLoading = false;
      if (result.isSuccess) {
        _deduped = result.data ?? [];
      } else {
        _dedupedError = result.message ?? '加载失败';
      }
    });
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  // Normalize date for weekly/monthly API requests.
  // Weekly data is anchored to Monday; monthly to the 1st of the month.
  String _effectiveApiDate() {
    final dt = DateTime.tryParse(_selectedDate) ?? DateTime.now();
    switch (_since) {
      case 'weekly':
        return _formatDate(dt.subtract(Duration(days: dt.weekday - 1)));
      case 'monthly':
        return _formatDate(DateTime(dt.year, dt.month, 1));
      default:
        return _selectedDate;
    }
  }

  Future<void> _loadTrending({bool force = false}) async {
    if (_trendingLoading) return;
    if (force) await _dailyApi.clearCache(date: _selectedDate);
    setState(() {
      _trendingLoading = true;
      _trendingError = '';
    });
    final result = await _dailyApi.getTrending(
      _effectiveApiDate(),
      language: _language.isEmpty ? null : _language,
      since: _since,
      limit: 25,
    );
    if (!mounted) return;
    setState(() {
      _trendingLoading = false;
      if (result.isSuccess) {
        _trending = result.data?.items ?? [];
        // If the languages API returned nothing, derive from trending items.
        if (_languages.isEmpty && _trending.isNotEmpty) {
          _languages = _trending
              .map((t) => t.language)
              .where((l) => l.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
        }
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
    final result = await _dailyApi.getDailyReport(_selectedDate);
    final trendingResult = result.isSuccess
        ? await _dailyApi.getTrending(_selectedDate, limit: 50)
        : null;
    if (!mounted) return;
    setState(() {
      _reportLoading = false;
      if (result.isSuccess) {
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
      } else if (result.error == 'not_found') {
        _reportNotFound = true;
        final isToday = _selectedDate == _todayStr();
        _reportError = isToday ? '今日报告尚未生成\n通常于每天下午发布，请稍后再来' : '该日期暂无报告数据';
      } else {
        _reportNotFound = false;
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
    final DateTime next;
    switch (_since) {
      case 'weekly':
        next = current.add(Duration(days: 7 * delta));
      case 'monthly':
        next = DateTime(current.year, current.month + delta, 1);
      default:
        next = current.add(Duration(days: delta));
    }
    if (next.isAfter(DateTime.now())) return;
    _setDate(next);
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final current = DateTime.tryParse(_selectedDate) ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(today) ? today : current,
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    _setDate(picked);
  }

  void _setDate(DateTime date) {
    final nextDate = _formatDate(date);
    if (_selectedDate == nextDate) return;
    setState(() {
      _selectedDate = nextDate;
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
    if (index == 2 && _deduped.isEmpty) _loadDeduped();
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
      } else if (_segment == 1) {
        _loadReport(force: true);
      } else {
        _loadDeduped(force: true);
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
                      reportNotFound: _reportNotFound,
                      deduped: _deduped,
                      dedupedLoading: _dedupedLoading,
                      dedupedError: _dedupedError,
                      dedupedSort: _dedupedSort,
                      dedupedLanguage: _dedupedLanguage,
                      onPrevDate: () => _changeDate(-1),
                      onNextDate: () => _changeDate(1),
                      onPickDate: _pickDate,
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
                      onDedupedSortChanged: (s) {
                        setState(() {
                          _dedupedSort = s;
                          _deduped = [];
                        });
                        _loadDeduped();
                      },
                      onDedupedLanguageChanged: (l) {
                        setState(() {
                          _dedupedLanguage = l;
                          _deduped = [];
                        });
                        _loadDeduped();
                      },
                      onRetryDeduped: () => _loadDeduped(force: true),
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
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
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
    required this.reportNotFound,
    required this.deduped,
    required this.dedupedLoading,
    required this.dedupedError,
    required this.dedupedSort,
    required this.dedupedLanguage,
    required this.onPrevDate,
    required this.onNextDate,
    required this.onPickDate,
    required this.onSegmentChanged,
    required this.onLanguageChanged,
    required this.onSinceChanged,
    required this.onRetryTrending,
    required this.onRetryReport,
    required this.onDedupedSortChanged,
    required this.onDedupedLanguageChanged,
    required this.onRetryDeduped,
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
  final bool reportNotFound;
  final List<DeduplicatedRepoItem> deduped;
  final bool dedupedLoading;
  final String dedupedError;
  final String dedupedSort;
  final String dedupedLanguage;
  final VoidCallback onPrevDate;
  final VoidCallback onNextDate;
  final VoidCallback onPickDate;
  final void Function(int) onSegmentChanged;
  final void Function(String) onLanguageChanged;
  final void Function(String) onSinceChanged;
  final VoidCallback onRetryTrending;
  final VoidCallback onRetryReport;
  final void Function(String) onDedupedSortChanged;
  final void Function(String) onDedupedLanguageChanged;
  final VoidCallback onRetryDeduped;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (segment != 2)
          _DatePickerHeader(
            date: date,
            since: since,
            onPrev: onPrevDate,
            onNext: onNextDate,
            onTap: onPickDate,
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
              : segment == 1
                  ? _ReportView(
                      report: report,
                      loading: reportLoading,
                      error: reportError,
                      notFound: reportNotFound,
                      onRetry: onRetryReport,
                    )
                  : _FrequentView(
                      items: deduped,
                      loading: dedupedLoading,
                      error: dedupedError,
                      sort: dedupedSort,
                      language: dedupedLanguage,
                      languages: languages,
                      onSortChanged: onDedupedSortChanged,
                      onLanguageChanged: onDedupedLanguageChanged,
                      onRetry: onRetryDeduped,
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
    required this.since,
    required this.onPrev,
    required this.onNext,
    required this.onTap,
  });
  final String date;
  final String since;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTap;

  // True when the selected date falls within the current daily/weekly/monthly period.
  bool _isCurrentPeriod() {
    final today = DateTime.now();
    final current = DateTime.tryParse(date);
    if (current == null) return false;
    switch (since) {
      case 'weekly':
        final currentMonday =
            today.subtract(Duration(days: today.weekday - 1));
        final dateMonday =
            current.subtract(Duration(days: current.weekday - 1));
        return currentMonday.year == dateMonday.year &&
            currentMonday.month == dateMonday.month &&
            currentMonday.day == dateMonday.day;
      case 'monthly':
        return current.year == today.year && current.month == today.month;
      default:
        return current.year == today.year &&
            current.month == today.month &&
            current.day == today.day;
    }
  }

  String _displayDate() {
    if (_isCurrentPeriod()) {
      switch (since) {
        case 'weekly':
          return formatDailyReportDateLabel(date, todayLabel: '本周');
        case 'monthly':
          return formatDailyReportDateLabel(date, todayLabel: '本月');
        case 'daily':
        default:
          return formatDailyReportDateLabel(date);
      }
    }
    try {
      final dt = DateTime.parse(date);
      if (since == 'weekly') {
        final monday = dt.subtract(Duration(days: dt.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        if (monday.month == sunday.month) {
          return '${monday.month}月${monday.day}日-${sunday.day}日';
        }
        return '${monday.month}月${monday.day}日-${sunday.month}月${sunday.day}日';
      }
      if (since == 'monthly') {
        return '${dt.year}年${dt.month.toString().padLeft(2, '0')}月';
      }
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
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
          Expanded(
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: _isCurrentPeriod() ? cs.onSurface.withAlpha(77) : null,
            ),
            onPressed: _isCurrentPeriod() ? null : onNext,
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
          const SizedBox(width: 6),
          Expanded(
            child: _SegBtn(
              label: '每日报告',
              icon: Icons.bar_chart_outlined,
              active: selected == 1,
              onTap: () => onSelect(1),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SegBtn(
              label: '高频项目',
              icon: Icons.repeat_outlined,
              active: selected == 2,
              onTap: () => onSelect(2),
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
              Icon(icon, size: 15, color: active ? Colors.white : cs.onSurface),
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
                child: _LanguageMenu(
                  selectedLanguage: language,
                  languages: languages,
                  onChanged: onLanguageChanged,
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

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({
    required this.selectedLanguage,
    required this.languages,
    required this.onChanged,
  });

  final String selectedLanguage;
  final List<String> languages;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = selectedLanguage.isEmpty ? '全部语言' : selectedLanguage;
    final menuLanguages =
        selectedLanguage.isNotEmpty && !languages.contains(selectedLanguage)
            ? [selectedLanguage, ...languages]
            : languages;

    return PopupMenuButton<String>(
      tooltip: '选择语言',
      initialValue: selectedLanguage,
      onSelected: onChanged,
      itemBuilder: (context) => [
        _languageItem(context, value: '', label: '全部语言'),
        ...menuLanguages.map(
          (language) => _languageItem(
            context,
            value: language,
            label: language,
          ),
        ),
      ],
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _languageItem(
    BuildContext context, {
    required String value,
    required String label,
  }) {
    final cs = Theme.of(context).colorScheme;
    final selected = selectedLanguage == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (selected) Icon(Icons.check, size: 18, color: cs.primary),
        ],
      ),
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
                      if (item.rankDiff != 0) _RankDelta(delta: item.rankDiff),
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
                          style: Theme.of(context).textTheme.bodySmall),
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
                          style: Theme.of(context).textTheme.bodySmall),
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
              color: Color(int.tryParse(Constants.getLanguageColor(language)
                      .replaceFirst('#', '0xFF')) ??
                  0xFF8b949e),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(language, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

// ── 高频项目 view ─────────────────────────────────────────────────────────────

class _FrequentView extends StatelessWidget {
  const _FrequentView({
    required this.items,
    required this.loading,
    required this.error,
    required this.sort,
    required this.language,
    required this.languages,
    required this.onSortChanged,
    required this.onLanguageChanged,
    required this.onRetry,
  });

  final List<DeduplicatedRepoItem> items;
  final bool loading;
  final String error;
  final String sort;
  final String language;
  final List<String> languages;
  final void Function(String) onSortChanged;
  final void Function(String) onLanguageChanged;
  final VoidCallback onRetry;

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
                child: _LanguageMenu(
                  selectedLanguage: language,
                  languages: languages,
                  onChanged: onLanguageChanged,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('累计', style: TextStyle(fontSize: 12)),
                selected: sort == 'total',
                onSelected: (_) => onSortChanged('total'),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('最近', style: TextStyle(fontSize: 12)),
                selected: sort == 'recent',
                onSelected: (_) => onSortChanged('recent'),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
        Expanded(
          child: loading && items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : error.isNotEmpty && items.isEmpty
                  ? _ErrorRetry(message: error, onRetry: onRetry)
                  : items.isEmpty
                      ? const _Empty(message: '暂无高频项目数据')
                      : RefreshIndicator(
                          onRefresh: () async => onRetry(),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const Divider(
                                height: 1, indent: 16, endIndent: 16),
                            itemBuilder: (context, i) =>
                                _FrequentCard(item: items[i], rank: i + 1),
                          ),
                        ),
        ),
      ],
    );
  }
}

class _FrequentCard extends StatelessWidget {
  const _FrequentCard({required this.item, required this.rank});
  final DeduplicatedRepoItem item;
  final int rank;

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  String _lastSeenLabel() {
    final now = DateTime.now();
    final diff = now.difference(item.lastSeenDate);
    if (diff.inDays == 0) return '今天';
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    final d = item.lastSeenDate;
    return '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

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
                color: rank <= 3
                    ? (rank == 1
                        ? const Color(0xFFFFD700)
                        : rank == 2
                            ? const Color(0xFFC0C0C0)
                            : const Color(0xFFCD7F32))
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: rank <= 3 ? Colors.white : cs.onSurfaceVariant,
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
                      // 累计次数 badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.repeat,
                                size: 11, color: cs.onPrimaryContainer),
                            const SizedBox(width: 3),
                            Text(
                              '${item.totalOccurrences}次',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                        const SizedBox(width: 10),
                      ],
                      const Icon(Icons.star_border, size: 13),
                      const SizedBox(width: 2),
                      Text(_fmt(item.stars),
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(width: 10),
                      const Icon(Icons.fork_right, size: 13),
                      const SizedBox(width: 2),
                      Text(_fmt(item.forks),
                          style: Theme.of(context).textTheme.bodySmall),
                      const Spacer(),
                      Icon(Icons.schedule,
                          size: 11, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(
                        _lastSeenLabel(),
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant),
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

// ── Daily report view ─────────────────────────────────────────────────────────

class _ReportView extends StatelessWidget {
  const _ReportView({
    required this.report,
    required this.loading,
    required this.error,
    required this.onRetry,
    this.notFound = false,
  });
  final Map<String, dynamic>? report;
  final bool loading;
  final String error;
  final bool notFound;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error.isNotEmpty) {
      if (notFound) return _ReportNotReady(message: error);
      return _ErrorRetry(message: error, onRetry: onRetry);
    }
    if (report == null) return const _Empty(message: '暂无报告数据');

    return DailyReportView(
      report: report!,
      onShare: () => showDailyReportShareSheet(context, report!),
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
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        itemCount: items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Row(
              children: [
                Expanded(
                  child: Text(
                    '由 CopoHub 编辑团队精心挑选',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '共 ${items.length} 个项目',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
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

  Color _rankBadgeColor(int rank, ColorScheme cs) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return cs.primary;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push(
          '/curated',
          extra: item,
        ),
        borderRadius: BorderRadius.circular(8),
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
                      color: _rankBadgeColor(item.rank, cs),
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
                              fontSize: 12, color: cs.onSurfaceVariant),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1C2B3A)
                        : const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(color: cs.primary, width: 3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          size: 14, color: cs.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.curatorNote,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.primary,
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
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
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
    final cs = Theme.of(context).colorScheme;

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
      bg = cs.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
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
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      );
}

class _ReportNotReady extends StatelessWidget {
  const _ReportNotReady({required this.message});
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

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          message,
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
}
