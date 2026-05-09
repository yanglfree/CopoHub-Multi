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
import '../../components/repository/repo_context_menu.dart';
import '../../services/pro_member_service.dart';
import '../../components/skeleton/repo_list_skeleton.dart';
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

class _FeaturedPageState extends State<FeaturedPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
  // Actual date returned by the report API when it differs from _selectedDate
  // (e.g. today's report uses yesterday's data). Only used for the report tab
  // header — does NOT affect _selectedDate or trending requests.
  String? _reportActualDate;

  List<DeduplicatedRepoItem> _deduped = [];
  bool _dedupedLoading = false;
  bool _dedupedLoadingMore = false;
  bool _dedupedHasMore = false;
  int _dedupedPage = 1;
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
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    ProMemberService.instance.addListener(_onProStatusChanged);
    _loadTrending();
    _loadLanguages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    ProMemberService.instance.removeListener(_onProStatusChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1 && _curated.isEmpty && !_curatedLoading) {
      _loadCurated();
    }
  }

  void _onProStatusChanged() => setState(() {});

  Future<void> _loadDeduped({bool force = false, bool loadMore = false}) async {
    if (loadMore) {
      if (_dedupedLoadingMore || !_dedupedHasMore) return;
    } else {
      if (_dedupedLoading) return;
    }
    if (force) {
      await ApiCache.instance.invalidateMatching('/api/v1/trending/deduplicated');
    }
    final page = loadMore ? _dedupedPage + 1 : 1;
    if (loadMore) {
      setState(() => _dedupedLoadingMore = true);
    } else {
      setState(() {
        _dedupedLoading = true;
        _dedupedError = '';
        if (!loadMore) {
          _deduped = [];
          _dedupedPage = 1;
          _dedupedHasMore = false;
        }
      });
    }
    final result = await _dailyApi.getDeduplicated(
      sort: _dedupedSort,
      language: _dedupedLanguage,
      page: page,
    );
    if (!mounted) return;
    setState(() {
      _dedupedLoading = false;
      _dedupedLoadingMore = false;
      if (result.isSuccess) {
        final data = result.data!;
        if (loadMore) {
          _deduped = [..._deduped, ...data.items];
        } else {
          _deduped = data.items;
        }
        _dedupedPage = data.page;
        _dedupedHasMore = data.hasMore;
      } else {
        _dedupedError = result.message ?? '加载失败';
      }
    });
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  // On the daily-report tab (segment 1) the period is always 'daily',
  // regardless of the trending filter selected on segment 0.
  String get _effectiveSince => _segment == 1 ? 'daily' : _since;

  // Date shown in the header. On the report tab, show the report's actual date
  // (which may be yesterday if today's report isn't ready yet); everywhere else
  // show the user's selected date so trending/deduped are unaffected.
  String get _effectiveDisplayDate =>
      _segment == 1 && _reportActualDate != null
          ? _reportActualDate!
          : _selectedDate;

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
    final isToday = _selectedDate == _todayStr();
    // 当选中日期是今天时，今日报告可能尚未生成，直接使用 latest 接口获取最新报告
    final result = isToday
        ? await _dailyApi.getLatestReport()
        : await _dailyApi.getDailyReport(_selectedDate);
    final reportDate =
        result.isSuccess ? result.data!['date'] as String? : null;
    final trendingDate =
        (reportDate != null && reportDate.isNotEmpty) ? reportDate : _selectedDate;
    final trendingResult = result.isSuccess
        ? await _dailyApi.getTrending(trendingDate, limit: 50)
        : null;
    if (!mounted) return;
    setState(() {
      _reportLoading = false;
      if (result.isSuccess) {
        _reportNotFound = false;
        // Update the report-tab header to the actual report date without
        // touching _selectedDate (which belongs to the trending tab).
        if (reportDate != null && reportDate.isNotEmpty && isToday) {
          _reportActualDate = reportDate;
        }
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
    switch (_effectiveSince) {
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
    if (!ProMemberService.instance.isPro) {
      context.push('/member');
      return;
    }
    final today = DateTime.now();
    final current = DateTime.tryParse(_selectedDate) ?? today;
    final DateTime? picked;
    switch (_effectiveSince) {
      case 'weekly':
        picked = await showDialog<DateTime>(
          context: context,
          builder: (ctx) => _WeekPickerDialog(
            initialDate: current,
            firstDate: DateTime(2020),
            lastDate: today,
          ),
        );
      case 'monthly':
        picked = await showDialog<DateTime>(
          context: context,
          builder: (ctx) => _MonthPickerDialog(
            initialDate: current,
            firstDate: DateTime(2020),
            lastDate: today,
          ),
        );
      default:
        picked = await showDialog<DateTime>(
          context: context,
          builder: (ctx) => _DayPickerDialog(
            initialDate: current.isAfter(today) ? today : current,
            firstDate: DateTime(2020),
            lastDate: today,
          ),
        );
    }
    if (picked == null || !mounted) return;
    _setDate(picked);
  }

  void _setDate(DateTime date) {
    final nextDate = _formatDate(date);
    if (_selectedDate == nextDate) return;
    // Paywall: non-pro users can only view today's data.
    if (!ProMemberService.instance.isPro && nextDate != _todayStr()) {
      context.push('/member');
      return;
    }
    setState(() {
      _selectedDate = nextDate;
      _trending = [];
      _report = null;
      _reportActualDate = null;
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



  void _refresh() {
    if (_tabController.index == 0) {
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
      appBar: AppBar(
        title: const Text(
          '精选',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: cs.primary),
            onPressed: _refresh,
            tooltip: '刷新',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department_outlined, size: 15),
                  SizedBox(width: 5),
                  Text('GitHub精选'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_outline, size: 15),
                  SizedBox(width: 5),
                  Text('CopoHub精选'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _GitHubTab(
            date: _effectiveDisplayDate,
            segment: _segment,
            isPro: ProMemberService.instance.isPro,
            trending: _trending,
            trendingLoading: _trendingLoading,
            trendingError: _trendingError,
            language: _language,
            languages: _languages,
            since: _effectiveSince,
            report: _report,
            reportLoading: _reportLoading,
            reportError: _reportError,
            reportNotFound: _reportNotFound,
            deduped: _deduped,
            dedupedLoading: _dedupedLoading,
            dedupedError: _dedupedError,
            dedupedSort: _dedupedSort,
            dedupedLanguage: _dedupedLanguage,
            dedupedHasMore: _dedupedHasMore,
            dedupedLoadingMore: _dedupedLoadingMore,
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
            onLoadMoreDeduped: () => _loadDeduped(loadMore: true),
            onRefresh: () async => _refresh(),
          ),
          _CopoHubTab(
            items: _curated,
            loading: _curatedLoading,
            error: _curatedError,
            onRetry: () => _loadCurated(force: true),
          ),
        ],
      ),
    );
  }
}



// ── GitHub精选 tab ────────────────────────────────────────────────────────────

// Pinned sliver header delegate for non-collapsing sticky headers.
class _SliverPinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _SliverPinnedHeaderDelegate({
    required this.child,
    required this.height,
  });
  final Widget child;
  final double height;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverPinnedHeaderDelegate oldDelegate) =>
      height != oldDelegate.height || child != oldDelegate.child;
}

class _GitHubTab extends StatefulWidget {
  const _GitHubTab({
    required this.date,
    required this.segment,
    required this.isPro,
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
    required this.dedupedHasMore,
    required this.dedupedLoadingMore,
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
    required this.onLoadMoreDeduped,
    required this.onRefresh,
  });

  final String date;
  final int segment;
  final bool isPro;
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
  final bool dedupedHasMore;
  final bool dedupedLoadingMore;
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
  final VoidCallback onLoadMoreDeduped;
  final Future<void> Function() onRefresh;

  @override
  State<_GitHubTab> createState() => _GitHubTabState();
}

class _GitHubTabState extends State<_GitHubTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // ── Frequent-tab search state (lifted from old _FrequentView) ───────────
  bool _searchVisible = false;
  final _searchController = TextEditingController();
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DeduplicatedRepoItem> get _filteredDeduped {
    if (_searchText.isEmpty) return widget.deduped;
    final q = _searchText.toLowerCase();
    return widget.deduped.where((item) {
      return item.fullName.toLowerCase().contains(q) ||
          item.owner.toLowerCase().contains(q) ||
          item.description.toLowerCase().contains(q);
    }).toList();
  }

  static const _sinceLabels = {'daily': '日', 'weekly': '周', 'monthly': '月'};

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    return NestedScrollView(
      key: const PageStorageKey<String>('github-tab-scroll'),
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        // ── Collapsible headers (scroll away with content) ──────────
        if (widget.segment != 2)
          SliverToBoxAdapter(
            child: _DatePickerHeader(
              date: widget.date,
              since: widget.since,
              isPro: widget.isPro,
              onPrev: widget.onPrevDate,
              onNext: widget.onNextDate,
              onTap: widget.onPickDate,
            ),
          ),
        if (!widget.isPro && widget.segment != 2)
          SliverToBoxAdapter(child: _ProBanner(onTap: widget.onPickDate)),

        // ── Pinned segment control ─────────────────────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _SliverPinnedHeaderDelegate(
            height: 48,
            child: _SegmentControl(
              selected: widget.segment,
              onSelect: widget.onSegmentChanged,
            ),
          ),
        ),

        // ── Pinned filter bar (trending / frequent only) ──────────
        if (widget.segment == 0)
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverPinnedHeaderDelegate(
              height: 48,
              child: Container(
                color: cs.surface,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _LanguageMenu(
                        selectedLanguage: widget.language,
                        languages: widget.languages,
                        onChanged: widget.onLanguageChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...['daily', 'weekly', 'monthly'].map((s) {
                      final active = widget.since == s;
                      return Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: ChoiceChip(
                          label: Text(_sinceLabels[s]!,
                              style: const TextStyle(fontSize: 12)),
                          selected: active,
                          onSelected: (_) => widget.onSinceChanged(s),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        if (widget.segment == 2)
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverPinnedHeaderDelegate(
              height: 48,
              child: Container(
                color: cs.surface,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _LanguageMenu(
                        selectedLanguage: widget.dedupedLanguage,
                        languages: widget.languages,
                        onChanged: widget.onDedupedLanguageChanged,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        icon: Icon(
                          _searchVisible ? Icons.search_off : Icons.search,
                          size: 20,
                          color: _searchVisible
                              ? cs.primary
                              : cs.onSurfaceVariant,
                        ),
                        onPressed: () {
                          setState(() {
                            _searchVisible = !_searchVisible;
                            if (!_searchVisible) {
                              _searchController.clear();
                              _searchText = '';
                            }
                          });
                        },
                        tooltip: '搜索仓库',
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      label:
                          const Text('累计', style: TextStyle(fontSize: 12)),
                      selected: widget.dedupedSort == 'total',
                      onSelected: (_) =>
                          widget.onDedupedSortChanged('total'),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      label:
                          const Text('最近', style: TextStyle(fontSize: 12)),
                      selected: widget.dedupedSort == 'recent',
                      onSelected: (_) =>
                          widget.onDedupedSortChanged('recent'),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Search bar for frequent tab (non-pinned)
        if (widget.segment == 2 && _searchVisible)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索仓库名、作者或描述...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchText = '';
                            });
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (v) => setState(() => _searchText = v),
              ),
            ),
          ),
      ],
      body: _buildBody(cs),
    );
  }

  // ── Body for each segment ───────────────────────────────────────────────

  Widget _buildBody(ColorScheme cs) {
    switch (widget.segment) {
      case 0:
        return _buildTrendingBody();
      case 1:
        return _buildReportBody();
      default:
        return _buildFrequentBody();
    }
  }

  Widget _buildTrendingBody() {
    if (widget.trendingLoading && widget.trending.isEmpty) {
      return const TrendingListSkeleton();
    }
    if (widget.trendingError.isNotEmpty && widget.trending.isEmpty) {
      return _ErrorRetry(
        message: widget.trendingError,
        onRetry: widget.onRetryTrending,
      );
    }
    if (widget.trending.isEmpty) {
      return const _Empty(message: '暂无 Trending 数据');
    }
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: widget.trending.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, i) =>
            _TrendingCard(item: widget.trending[i]),
      ),
    );
  }

  Widget _buildReportBody() {
    if (widget.reportLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.reportError.isNotEmpty) {
      if (widget.reportNotFound) {
        return _ReportNotReady(message: widget.reportError);
      }
      return _ErrorRetry(
        message: widget.reportError,
        onRetry: widget.onRetryReport,
      );
    }
    if (widget.report == null) {
      return const _Empty(message: '暂无报告数据');
    }
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: DailyReportView(
        report: widget.report!,
        onShare: () => showDailyReportShareSheet(context, widget.report!),
      ),
    );
  }

  Widget _buildFrequentBody() {
    final filtered = _filteredDeduped;
    if (widget.dedupedLoading && widget.deduped.isEmpty) {
      return const TrendingListSkeleton();
    }
    if (widget.dedupedError.isNotEmpty && widget.deduped.isEmpty) {
      return _ErrorRetry(
        message: widget.dedupedError,
        onRetry: widget.onRetryDeduped,
      );
    }
    if (filtered.isEmpty) {
      return _Empty(
        message:
            _searchText.isNotEmpty ? '未找到匹配的仓库' : '暂无高频项目数据',
      );
    }
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (_searchText.isEmpty &&
              notification is ScrollEndNotification &&
              notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200) {
            widget.onLoadMoreDeduped();
          }
          return false;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: filtered.length +
              (_searchText.isEmpty &&
                      (widget.dedupedHasMore || widget.dedupedLoadingMore)
                  ? 1
                  : 0),
          separatorBuilder: (_, i) => i < filtered.length - 1
              ? const Divider(height: 1, indent: 16, endIndent: 16)
              : const SizedBox.shrink(),
          itemBuilder: (context, i) {
            if (i >= filtered.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: widget.dedupedLoadingMore
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: widget.onLoadMoreDeduped,
                          child: const Text('加载更多'),
                        ),
                ),
              );
            }
            return _FrequentCard(item: filtered[i], rank: i + 1);
          },
        ),
      ),
    );
  }
}

// ── Date picker header ────────────────────────────────────────────────────────

class _DatePickerHeader extends StatelessWidget {
  const _DatePickerHeader({
    required this.date,
    required this.since,
    required this.isPro,
    required this.onPrev,
    required this.onNext,
    required this.onTap,
  });
  final String date;
  final String since;
  final bool isPro;
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
    try {
      final dt = DateTime.parse(date);
      if (since == 'weekly') {
        final monday = dt.subtract(Duration(days: dt.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        final String rangeStr;
        if (monday.month == sunday.month) {
          rangeStr = '${monday.month}月${monday.day}日-${sunday.day}日';
        } else {
          rangeStr =
              '${monday.month}月${monday.day}日-${sunday.month}月${sunday.day}日';
        }
        return _isCurrentPeriod() ? '本周 ($rangeStr)' : rangeStr;
      }
      if (since == 'monthly') {
        final monthStr =
            '${dt.year}年${dt.month.toString().padLeft(2, '0')}月';
        return _isCurrentPeriod() ? '本月 ($monthStr)' : monthStr;
      }
      return formatDailyReportDateLabel(date);
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Non-pro users are locked to the current period; prev is visually locked.
    final prevLocked = !isPro;
    return Container(
      height: 52,
      color: cs.surfaceContainer,
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.chevron_left,
              color: prevLocked ? cs.onSurface.withAlpha(80) : null,
            ),
            onPressed: onPrev,
          ),
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
                        Icon(
                          isPro ? Icons.arrow_drop_down : Icons.lock_outline,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
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

// ── Pro paywall banner ────────────────────────────────────────────────────────

class _ProBanner extends StatelessWidget {
  const _ProBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primaryContainer.withOpacity(0.5),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 15, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '历史数据查看需要 Pro 会员',
                  style: TextStyle(
                      fontSize: 13,
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '解锁 Pro →',
                style: TextStyle(
                    fontSize: 13,
                    color: cs.primary,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
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
      onLongPress: () => showRepoContextMenuFor(
        context,
        owner: item.owner,
        name: item.name,
      ),
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
      onLongPress: () => showRepoContextMenuFor(
        context,
        owner: item.owner,
        name: item.name,
      ),
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

// ── CopoHub精选 tab ───────────────────────────────────────────────────────────

class _CopoHubTab extends StatefulWidget {
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
  State<_CopoHubTab> createState() => _CopoHubTabState();
}

class _CopoHubTabState extends State<_CopoHubTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.loading) return const CuratedListSkeleton();
    if (widget.error.isNotEmpty) return _ErrorRetry(message: widget.error, onRetry: widget.onRetry);
    if (widget.items.isEmpty) return const _Empty(message: '暂无精选项目');

    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async => widget.onRetry(),
      child: ListView.separated(
        key: const PageStorageKey<String>('copohub-tab-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        itemCount: widget.items.length + 1,
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
                  '共 ${widget.items.length} 个项目',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            );
          }
          return _CuratedCard(item: widget.items[i - 1]);
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

// ── Day Picker Dialog ─────────────────────────────────────────────────────────

class _DayPickerDialog extends StatefulWidget {
  const _DayPickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_DayPickerDialog> createState() => _DayPickerDialogState();
}

class _DayPickerDialogState extends State<_DayPickerDialog> {
  late DateTime _viewMonth;
  late DateTime _selected;

  static const _dayHeaders = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    _viewMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  bool _canPrevMonth() {
    final prev = DateTime(_viewMonth.year, _viewMonth.month - 1);
    return !prev.isBefore(
        DateTime(widget.firstDate.year, widget.firstDate.month));
  }

  bool _canNextMonth() {
    final next = DateTime(_viewMonth.year, _viewMonth.month + 1);
    return !next
        .isAfter(DateTime(widget.lastDate.year, widget.lastDate.month));
  }

  List<DateTime?> _buildDays() {
    final firstDay = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final lastDay = DateTime(_viewMonth.year, _viewMonth.month + 1, 0);
    final startPad = firstDay.weekday - 1;
    final days = <DateTime?>[
      ...List<DateTime?>.filled(startPad, null),
      for (int d = 1; d <= lastDay.day; d++)
        DateTime(_viewMonth.year, _viewMonth.month, d),
    ];
    while (days.length % 7 != 0) {
      days.add(null);
    }
    return days;
  }

  bool _isEnabled(DateTime? day) {
    if (day == null) return false;
    return !day.isBefore(DateTime(widget.firstDate.year,
            widget.firstDate.month, widget.firstDate.day)) &&
        !day.isAfter(DateTime(widget.lastDate.year, widget.lastDate.month,
            widget.lastDate.day));
  }

  bool _isSelected(DateTime? day) =>
      day != null &&
      day.year == _selected.year &&
      day.month == _selected.month &&
      day.day == _selected.day;

  bool _isToday(DateTime? day) {
    if (day == null) return false;
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final days = _buildDays();
    final numWeeks = days.length ~/ 7;

    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cs.surfaceContainerLowest,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '选择日期',
                style: tt.titleSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _PickerNavButton(
                  icon: Icons.chevron_left_rounded,
                  enabled: _canPrevMonth(),
                  onTap: () => setState(() => _viewMonth =
                      DateTime(_viewMonth.year, _viewMonth.month - 1)),
                  cs: cs,
                ),
                Text(
                  '${_viewMonth.year}年${_viewMonth.month}月',
                  style: tt.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                _PickerNavButton(
                  icon: Icons.chevron_right_rounded,
                  enabled: _canNextMonth(),
                  onTap: () => setState(() => _viewMonth =
                      DateTime(_viewMonth.year, _viewMonth.month + 1)),
                  cs: cs,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Day-of-week headers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                children: List.generate(_dayHeaders.length, (i) {
                  final isWeekend = i >= 5;
                  return Expanded(
                    child: Center(
                      child: Text(
                        _dayHeaders[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isWeekend
                              ? cs.error.withAlpha(160)
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 4),
            // Day grid rows
            for (int w = 0; w < numWeeks; w++)
              _buildDayRow(days.sublist(w * 7, (w + 1) * 7), cs),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayRow(List<DateTime?> row, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      child: Row(
        children: List.generate(row.length, (i) {
          final day = row[i];
          final enabled = _isEnabled(day);
          final selected = _isSelected(day);
          final today = _isToday(day);

          return Expanded(
            child: GestureDetector(
              onTap: enabled
                  ? () {
                      Navigator.of(context).pop(day);
                    }
                  : null,
              child: SizedBox(
                height: 38,
                child: Center(
                  child: day == null
                      ? const SizedBox.shrink()
                      : Container(
                          width: 34,
                          height: 34,
                          decoration: selected
                              ? BoxDecoration(
                                  color: cs.primary,
                                  shape: BoxShape.circle,
                                )
                              : today
                                  ? BoxDecoration(
                                      border: Border.all(
                                          color: cs.primary, width: 1.5),
                                      shape: BoxShape.circle,
                                    )
                                  : null,
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 14,
                                color: !enabled
                                    ? cs.onSurface.withAlpha(48)
                                    : selected
                                        ? cs.onPrimary
                                        : today
                                            ? cs.primary
                                            : null,
                                fontWeight: selected || today
                                    ? FontWeight.w700
                                    : null,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Month Picker Dialog ───────────────────────────────────────────────────────

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year;
  late int _selectedYear;
  late int _selectedMonth;

  static const _monthLabels = [
    '1月', '2月', '3月', '4月', '5月', '6月',
    '7月', '8月', '9月', '10月', '11月', '12月',
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.initialDate.year;
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
  }

  bool _isEnabled(int month) {
    final d = DateTime(_year, month);
    return !d.isBefore(
            DateTime(widget.firstDate.year, widget.firstDate.month)) &&
        !d.isAfter(DateTime(widget.lastDate.year, widget.lastDate.month));
  }

  bool _isSelected(int month) =>
      _year == _selectedYear && month == _selectedMonth;

  bool _isCurrentMonth(int month) {
    final now = DateTime.now();
    return _year == now.year && month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final canPrev = _year > widget.firstDate.year;
    final canNext = _year < widget.lastDate.year;

    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cs.surfaceContainerLowest,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header label
            Text(
              '选择月份',
              style: tt.titleSmall?.copyWith(
                  color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 14),
            // Year navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _PickerNavButton(
                  icon: Icons.chevron_left_rounded,
                  enabled: canPrev,
                  onTap: () => setState(() => _year--),
                  cs: cs,
                ),
                Text(
                  '$_year年',
                  style: tt.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                _PickerNavButton(
                  icon: Icons.chevron_right_rounded,
                  enabled: canNext,
                  onTap: () => setState(() => _year++),
                  cs: cs,
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Month grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 12,
              itemBuilder: (ctx, i) {
                final month = i + 1;
                final enabled = _isEnabled(month);
                final selected = _isSelected(month);
                final current = _isCurrentMonth(month);
                return _MonthCell(
                  label: _monthLabels[i],
                  selected: selected,
                  isCurrent: current,
                  enabled: enabled,
                  cs: cs,
                  onTap: enabled
                      ? () {
                          setState(() {
                            _selectedYear = _year;
                            _selectedMonth = month;
                          });
                          Navigator.of(ctx)
                              .pop(DateTime(_year, month, 1));
                        }
                      : null,
                );
              },
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.label,
    required this.selected,
    required this.isCurrent,
    required this.enabled,
    required this.cs,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool isCurrent;
  final bool enabled;
  final ColorScheme cs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color? bgColor;
    Color? textColor;
    BoxBorder? border;
    FontWeight fontWeight = FontWeight.w500;

    if (selected) {
      bgColor = cs.primary;
      textColor = cs.onPrimary;
      fontWeight = FontWeight.w700;
    } else if (isCurrent && enabled) {
      border = Border.all(color: cs.primary, width: 1.5);
      textColor = cs.primary;
      fontWeight = FontWeight.w600;
    } else if (!enabled) {
      textColor = cs.onSurface.withAlpha(56);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: border,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: fontWeight,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Week Picker Dialog ────────────────────────────────────────────────────────

class _WeekPickerDialog extends StatefulWidget {
  const _WeekPickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_WeekPickerDialog> createState() => _WeekPickerDialogState();
}

class _WeekPickerDialogState extends State<_WeekPickerDialog> {
  late DateTime _viewMonth;
  late DateTime _selectedMonday;

  static const _dayHeaders = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    _viewMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
    _selectedMonday = widget.initialDate
        .subtract(Duration(days: widget.initialDate.weekday - 1));
  }

  bool _canPrevMonth() {
    final prev = DateTime(_viewMonth.year, _viewMonth.month - 1);
    return !prev.isBefore(
        DateTime(widget.firstDate.year, widget.firstDate.month));
  }

  bool _canNextMonth() {
    final next = DateTime(_viewMonth.year, _viewMonth.month + 1);
    return !next
        .isAfter(DateTime(widget.lastDate.year, widget.lastDate.month));
  }

  List<DateTime?> _buildDays() {
    final firstDay = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final lastDay = DateTime(_viewMonth.year, _viewMonth.month + 1, 0);
    final startPad = firstDay.weekday - 1;
    final days = <DateTime?>[
      ...List<DateTime?>.filled(startPad, null),
      for (int d = 1; d <= lastDay.day; d++)
        DateTime(_viewMonth.year, _viewMonth.month, d),
    ];
    while (days.length % 7 != 0) {
      days.add(null);
    }
    return days;
  }

  bool _isDayEnabled(DateTime? day) {
    if (day == null) return false;
    return !day.isBefore(DateTime(widget.firstDate.year,
            widget.firstDate.month, widget.firstDate.day)) &&
        !day.isAfter(DateTime(widget.lastDate.year, widget.lastDate.month,
            widget.lastDate.day));
  }

  bool _isInSelectedWeek(DateTime? day) {
    if (day == null) return false;
    final sunday = _selectedMonday.add(const Duration(days: 6));
    return !day.isBefore(_selectedMonday) && !day.isAfter(sunday);
  }

  void _selectWeekContaining(List<DateTime?> weekRow) {
    DateTime? firstEnabled;
    for (final d in weekRow) {
      if (_isDayEnabled(d)) {
        firstEnabled = d;
        break;
      }
    }
    if (firstEnabled == null) return;
    final monday =
        firstEnabled.subtract(Duration(days: firstEnabled.weekday - 1));
    setState(() => _selectedMonday = monday);
    Navigator.of(context).pop(monday);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final days = _buildDays();
    final numWeeks = days.length ~/ 7;

    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cs.surfaceContainerLowest,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '选择周',
                style: tt.titleSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 12),
            // Month/year navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _PickerNavButton(
                  icon: Icons.chevron_left_rounded,
                  enabled: _canPrevMonth(),
                  onTap: () => setState(() => _viewMonth =
                      DateTime(_viewMonth.year, _viewMonth.month - 1)),
                  cs: cs,
                ),
                Text(
                  '${_viewMonth.year}年${_viewMonth.month}月',
                  style: tt.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                _PickerNavButton(
                  icon: Icons.chevron_right_rounded,
                  enabled: _canNextMonth(),
                  onTap: () => setState(() => _viewMonth =
                      DateTime(_viewMonth.year, _viewMonth.month + 1)),
                  cs: cs,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Day-of-week header row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                children: List.generate(_dayHeaders.length, (i) {
                  final isWeekend = i >= 5;
                  return Expanded(
                    child: Center(
                      child: Text(
                        _dayHeaders[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isWeekend
                              ? cs.error.withAlpha(160)
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 6),
            // Week rows
            for (int w = 0; w < numWeeks; w++)
              _buildWeekRow(days.sublist(w * 7, (w + 1) * 7), cs),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekRow(List<DateTime?> row, ColorScheme cs) {
    final hasEnabled = row.any(_isDayEnabled);
    final isSelected = row.any(_isInSelectedWeek);
    final today = DateTime.now();

    return GestureDetector(
      onTap: hasEnabled ? () => _selectWeekContaining(row) : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        height: 42,
        decoration: isSelected && hasEnabled
            ? BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              )
            : null,
        child: Row(
          children: List.generate(row.length, (i) {
            final day = row[i];
            final enabled = _isDayEnabled(day);
            final inSel = _isInSelectedWeek(day);
            final isToday = day != null &&
                day.year == today.year &&
                day.month == today.month &&
                day.day == today.day;

            return Expanded(
              child: Center(
                child: day == null
                    ? const SizedBox.shrink()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 14,
                              color: !enabled
                                  ? cs.onSurface.withAlpha(48)
                                  : inSel
                                      ? cs.onPrimaryContainer
                                      : null,
                              fontWeight: inSel || isToday
                                  ? FontWeight.w700
                                  : null,
                            ),
                          ),
                          if (isToday)
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                color: cs.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Shared picker nav button ──────────────────────────────────────────────────

class _PickerNavButton extends StatelessWidget {
  const _PickerNavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.cs,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? cs.onSurface : cs.onSurface.withAlpha(48),
        ),
      ),
    );
  }
}
