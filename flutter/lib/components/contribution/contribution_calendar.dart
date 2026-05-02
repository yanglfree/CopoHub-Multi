import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';
import '../../services/contribution_service.dart';
import '../../utils/constants.dart';

/// GitHub-style contribution heatmap calendar.
///
/// Default behaviour mirrors GitHub's profile page:
///   - On first load the trailing-year (last 365 days) is shown, while the
///     current-year tab on the right appears highlighted.
///   - Tapping any year tab switches to that calendar year's data.
///
/// Layout:
///   header row  (title + count)
///   [weekday labels | scrollable month+grid | year tabs]
///   legend
class ContributionCalendar extends ConsumerStatefulWidget {
  const ContributionCalendar({
    super.key,
    required this.username,
    this.initialYear,
    this.showThemeMenu = true,
  });

  final String username;
  final int? initialYear;
  final bool showThemeMenu;

  @override
  ConsumerState<ContributionCalendar> createState() =>
      _ContributionCalendarState();
}

class _ContributionCalendarState extends ConsumerState<ContributionCalendar> {
  late int _year;

  /// True  → show trailing 365-day data (GitHub default).
  /// False → show the selected calendar year.
  bool _isLastYear = true;

  final _service = ContributionService.instance;

  ContributionSummary? _summary;
  bool _loading = true;
  String _error = '';

  static const _minYear = 2008;

  int get _currentYear => DateTime.now().year;

  List<int> get _availableYears {
    final years = <int>[];
    for (int y = _currentYear; y >= _minYear; y--) {
      years.add(y);
    }
    return years;
  }

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear ?? _currentYear;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    final ContributionSummary? summary;
    if (_isLastYear) {
      summary = await _service.getSummaryLastYear(username: widget.username);
    } else {
      summary =
          await _service.getSummary(year: _year, username: widget.username);
    }

    if (!mounted) return;
    if (summary == null) {
      setState(() {
        _loading = false;
        _error = '加载失败';
      });
    } else {
      setState(() {
        _loading = false;
        _summary = summary;
      });
    }
  }

  void _selectYear(int year) {
    if (!_isLastYear && _year == year) return;
    setState(() {
      _isLastYear = false;
      _year = year;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _ContributionColors.fromHex(
      ref.watch(contributionColorsProvider),
      isDark: isDark,
    );
    final selectedTheme = ref.watch(contributionThemeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                '贡献热力图',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              if (widget.showThemeMenu) ...[
                _ContributionThemeMenu(
                  selectedTheme: selectedTheme,
                  onSelected: (themeName) {
                    ref
                        .read(themeServiceProvider)
                        .setContributionTheme(themeName);
                  },
                ),
                const SizedBox(width: 8),
              ],
              if (_summary != null)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _isLastYear
                          ? '${_summary!.totalContributions} contributions in the last year'
                          : '${_summary!.totalContributions} contributions in $_year',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                    ),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
        ),

        // ── Body: calendar + year tabs ───────────────────────────────────────
        if (_loading)
          const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_error.isNotEmpty)
          SizedBox(
            height: 100,
            child: Center(
              child:
                  Text(_error, style: TextStyle(color: cs.error, fontSize: 12)),
            ),
          )
        else if (_summary != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CalendarGrid(
                  summary: _summary!,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 10),
              _YearTabs(
                years: _availableYears,
                selectedYear: _year,
                isLastYear: _isLastYear,
                height: _CalendarGrid.totalHeight,
                onTap: _selectYear,
              ),
            ],
          ),

        // ── Legend ──────────────────────────────────────────────────────────
        const SizedBox(height: 6),
        _Legend(colors: colors),
      ],
    );
  }
}

class _ContributionThemeMenu extends StatelessWidget {
  const _ContributionThemeMenu({
    required this.selectedTheme,
    required this.onSelected,
  });

  final String selectedTheme;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const themes = Constants.contributionThemes;
    final current =
        themes.where((theme) => theme.name == selectedTheme).firstOrNull ??
            themes.first;

    return PopupMenuButton<String>(
      tooltip: '更改贡献图颜色',
      initialValue: selectedTheme,
      onSelected: onSelected,
      itemBuilder: (context) => themes
          .map(
            (theme) => PopupMenuItem<String>(
              value: theme.name,
              child: Row(
                children: [
                  _ThemeSwatches(colors: theme.colors, size: 12),
                  const SizedBox(width: 10),
                  Text(theme.name),
                  const Spacer(),
                  if (theme.name == selectedTheme)
                    Icon(Icons.check, size: 18, color: cs.primary),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeSwatches(colors: current.colors, size: 10),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down,
                size: 16, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ThemeSwatches extends StatelessWidget {
  const _ThemeSwatches({required this.colors, required this.size});

  final List<String> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: colors.skip(1).map((hex) {
        final color = _ContributionColors.parseHex(hex) ?? Colors.transparent;
        return Container(
          width: size,
          height: size,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }).toList(),
    );
  }
}

class _ContributionColors {
  const _ContributionColors._();

  static const _lightFallback = [
    Color(0xFFEBEDF0),
    Color(0xFF9BE9A8),
    Color(0xFF40C463),
    Color(0xFF30A14E),
    Color(0xFF216E39),
  ];

  static const _darkEmpty = Color(0xFF161B22);

  static List<Color> fromHex(List<String> hexColors, {required bool isDark}) {
    final parsed = hexColors.map(parseHex).whereType<Color>().toList();
    if (parsed.length < 5) return _lightFallback;

    final colors = parsed.take(5).toList(growable: false);
    if (!isDark) return colors;

    return [_darkEmpty, ...colors.skip(1)];
  }

  static Color? parseHex(String hex) {
    final normalized = hex.replaceFirst('#', '');
    final value = int.tryParse('FF$normalized', radix: 16);
    return value == null ? null : Color(value);
  }
}

// ── Year tabs ─────────────────────────────────────────────────────────────────

class _YearTabs extends StatelessWidget {
  const _YearTabs({
    required this.years,
    required this.selectedYear,
    required this.isLastYear,
    required this.height,
    required this.onTap,
  });

  final List<int> years;
  final int selectedYear;
  final bool isLastYear;
  final double height;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 54,
      height: height,
      child: ListView.builder(
        primary: false,
        padding: EdgeInsets.zero,
        itemCount: years.length,
        itemBuilder: (context, index) {
          final year = years[index];
          // In last-year mode highlight the most-recent tab (mirrors GitHub).
          final isSelected =
              isLastYear ? year == years.first : year == selectedYear;

          return GestureDetector(
            onTap: () => onTap(year),
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? cs.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$year',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Calendar grid ─────────────────────────────────────────────────────────────

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.summary, required this.colors});

  final ContributionSummary summary;
  final List<Color> colors;

  static const _cellSize = 10.0;
  static const _cellGap = 2.0;
  static const _rowH = _cellSize + _cellGap; // 12 px
  static const _monthLabelH = 16.0;
  static const totalHeight = _monthLabelH + 7 * _rowH;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed weekday labels on the left (do not scroll).
        const _WeekdayLabels(
          cellSize: _cellSize,
          monthLabelH: _monthLabelH,
          cellGap: _cellGap,
        ),
        const SizedBox(width: 4),
        // Horizontally scrollable: month labels + cell grid.
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _GridWithMonths(
              weeks: summary.weeks,
              colors: colors,
              cellSize: _cellSize,
              cellGap: _cellGap,
              monthLabelH: _monthLabelH,
              filterYear: summary.isLastYear ? null : summary.year,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Weekday labels (周一 / 周三 / 周五) ────────────────────────────────────────

class _WeekdayLabels extends StatelessWidget {
  const _WeekdayLabels({
    required this.cellSize,
    required this.monthLabelH,
    required this.cellGap,
  });

  final double cellSize;
  final double monthLabelH;
  final double cellGap;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 9,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1,
    );

    // Mirror the grid's Padding(bottom: cellGap)+SizedBox(cellSize) structure
    // so labels align exactly with the centres of the corresponding cells.
    // Grid rows (Sunday-first): Sun(0) Mon(1) Tue(2) Wed(3) Thu(4) Fri(5) Sat(6)
    Widget slot(String? label) => Padding(
          padding: EdgeInsets.only(bottom: cellGap),
          child: SizedBox(
            height: cellSize,
            child: label == null
                ? null
                : Align(
                    alignment: Alignment.centerRight,
                    child: Text(label, style: style),
                  ),
          ),
        );

    return Padding(
      padding: EdgeInsets.only(top: monthLabelH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          slot(null), // Sunday
          slot('周一'), // Monday
          slot(null), // Tuesday
          slot('周三'), // Wednesday
          slot(null), // Thursday
          slot('周五'), // Friday
          slot(null), // Saturday
        ],
      ),
    );
  }
}

// ── Month labels + cell grid (rendered together so they scroll in sync) ────────

class _GridWithMonths extends StatelessWidget {
  const _GridWithMonths({
    required this.weeks,
    required this.colors,
    required this.cellSize,
    required this.cellGap,
    required this.monthLabelH,
    this.filterYear,
  });

  final List<ContributionWeek> weeks;
  final List<Color> colors;
  final double cellSize;
  final double cellGap;
  final double monthLabelH;

  /// When set, only month labels belonging to this year are shown.
  final int? filterYear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MonthLabels(
          weeks: weeks,
          cellSize: cellSize,
          cellGap: cellGap,
          height: monthLabelH,
          filterYear: filterYear,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: weeks.map((week) {
            return Padding(
              padding: EdgeInsets.only(right: cellGap),
              child: Column(
                children: List.generate(7, (i) {
                  final day = i < week.days.length ? week.days[i] : null;
                  return Padding(
                    padding: EdgeInsets.only(bottom: cellGap),
                    child: _Cell(
                      level: day?.level ?? 0,
                      count: day?.count ?? 0,
                      date: day?.date ?? '',
                      colors: colors,
                      size: cellSize,
                    ),
                  );
                }),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Month labels row ──────────────────────────────────────────────────────────

class _MonthLabels extends StatelessWidget {
  const _MonthLabels({
    required this.weeks,
    required this.cellSize,
    required this.cellGap,
    required this.height,
    this.filterYear,
  });

  final List<ContributionWeek> weeks;
  final double cellSize;
  final double cellGap;
  final double height;
  final int? filterYear;

  static const _monthNames = [
    '1月',
    '2月',
    '3月',
    '4月',
    '5月',
    '6月',
    '7月',
    '8月',
    '9月',
    '10月',
    '11月',
    '12月',
  ];

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 9,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1,
    );

    // Find the column index at which each new month first appears.
    // When filterYear is set, skip months from other years to prevent
    // "12月/1月" overlap at the start of a calendar-year view.
    // Also enforce a minimum column gap so labels never overlap each other
    // (e.g. when the range starts near month-end, two months land in the
    // same or adjacent columns).
    const minColGap = 3; // ≈ 36 px — enough to fit even a wide label
    final labels = <(int, String)>[];
    int? lastMonth;
    int lastLabelCol = -minColGap; // allow first label at col 0
    for (int col = 0; col < weeks.length; col++) {
      for (final day in weeks[col].days) {
        if (day.date.length >= 7) {
          final dayYear = int.tryParse(day.date.substring(0, 4));
          final month = int.tryParse(day.date.substring(5, 7));
          if (month != null && month != lastMonth) {
            if (filterYear == null || dayYear == filterYear) {
              if (col - lastLabelCol >= minColGap) {
                labels.add((col, _monthNames[month - 1]));
                lastLabelCol = col;
              }
            }
            lastMonth = month; // always advance, even when label is skipped
          }
          break;
        }
      }
    }

    final totalWidth = weeks.length * (cellSize + cellGap);
    return SizedBox(
      width: totalWidth,
      height: height,
      child: Stack(
        children: labels.map((entry) {
          final left = entry.$1 * (cellSize + cellGap);
          return Positioned(
            left: left,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(entry.$2, style: style),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Single contribution cell ──────────────────────────────────────────────────

class _Cell extends StatelessWidget {
  const _Cell({
    required this.level,
    required this.count,
    required this.date,
    required this.colors,
    required this.size,
  });

  final int level;
  final int count;
  final String date;
  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = colors[level.clamp(0, 4)];

    return Tooltip(
      message: count > 0
          ? '$count contributions on $date'
          : 'No contributions on $date',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ── Legend ────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Less', style: labelStyle),
        const SizedBox(width: 4),
        ...colors.map(
          (c) => Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 2),
        Text('More', style: labelStyle),
      ],
    );
  }
}
