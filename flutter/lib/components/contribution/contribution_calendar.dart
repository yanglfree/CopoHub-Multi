import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';
import '../../services/contribution_service.dart';
import '../../utils/constants.dart';
import '../../l10n/app_localizations.dart';
import '../skeleton/skeleton.dart';

/// GitHub-style contribution heatmap calendar.
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
        _error = AppLocalizations.of(context).loadFailed;
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
    final l10n = AppLocalizations.of(context);
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
                l10n.contributionHeatmap,
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
                          ? l10n.contributionsInLastYear(_summary!.totalContributions)
                          : l10n.contributionsInYear(_summary!.totalContributions, _year),
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
          const _HeatmapSkeleton()
        else if (_error.isNotEmpty)
          SizedBox(
            height: 100,
            child: Center(
              child:
                  Text(_error, style: TextStyle(color: cs.error, fontSize: 12)),
            ),
          )
        else if (_summary != null)
          // LayoutBuilder mirrors _CalendarGrid's cell-size formula so that
          // _YearTabs gets the correct height even when cells are scaled up.
          LayoutBuilder(
            builder: (context, constraints) {
              const yearTabAndGap = 64.0; // 54 (tab) + 10 (gap)
              const weekdayAreaW = 24.0;  // ~20 px labels + 4 px SizedBox
              const cellGap = 2.0;
              const minCell = 10.0;
              const maxCell = 18.0;
              final numWeeks = _summary!.weeks.length;

              var cellSize = minCell;
              if (numWeeks > 0) {
                final gridAvailable = constraints.maxWidth -
                    yearTabAndGap -
                    weekdayAreaW;
                final computed = gridAvailable / numWeeks - cellGap;
                if (computed > minCell) {
                  cellSize = computed.clamp(minCell, maxCell);
                }
              }

              return Row(
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
                    height: _CalendarGrid.totalHeightForCellSize(cellSize),
                    onTap: _selectYear,
                  ),
                ],
              );
            },
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
    final l10n = AppLocalizations.of(context);
    const themes = Constants.contributionThemes;
    final current =
        themes.where((theme) => theme.name == selectedTheme).firstOrNull ??
            themes.first;

    return PopupMenuButton<String>(
      tooltip: l10n.changeHeatmapColor,
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

  static const _minCellSize = 10.0;
  static const _maxCellSize = 18.0;
  static const _cellGap = 2.0;
  static const _monthLabelH = 16.0;
  // Approximate width consumed by weekday labels column + the SizedBox(4) gap.
  static const _weekdayAreaW = 24.0;

  /// Calendar height for a given cell size (used by parent to size _YearTabs).
  static double totalHeightForCellSize(double cellSize) =>
      _monthLabelH + 7 * (cellSize + _cellGap);

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder gives us the exact width of this Expanded slot so we can
    // compute the optimal cell size in one place (weekday labels + grid row).
    return LayoutBuilder(
      builder: (context, constraints) {
        final numWeeks = summary.weeks.length;
        var cellSize = _minCellSize;
        if (numWeeks > 0) {
          final gridAvailable = constraints.maxWidth - _weekdayAreaW;
          final computed = gridAvailable / numWeeks - _cellGap;
          if (computed > _minCellSize) {
            cellSize = computed.clamp(_minCellSize, _maxCellSize);
          }
        }

        final grid = _GridWithMonths(
          weeks: summary.weeks,
          colors: colors,
          cellSize: cellSize,
          cellGap: _cellGap,
          monthLabelH: _monthLabelH,
          filterYear: summary.isLastYear ? null : summary.year,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Weekday labels rendered at the actual (possibly scaled) cell size.
            _WeekdayLabels(
              cellSize: cellSize,
              monthLabelH: _monthLabelH,
              cellGap: _cellGap,
            ),
            const SizedBox(width: 4),
            Expanded(
              // On small screens the grid is wider than the container –
              // keep horizontal scrolling.  On large screens it fills exactly.
              child: cellSize <= _minCellSize
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: grid,
                    )
                  : grid,
            ),
          ],
        );
      },
    );
  }
}

// ── Weekday labels ────────────────────────────────────────────────────────────

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
    final l10n = AppLocalizations.of(context);
    final style = TextStyle(
      fontSize: 9,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1,
    );

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
          slot(l10n.mon),
          slot(null), // Tuesday
          slot(l10n.wed),
          slot(null), // Thursday
          slot(l10n.fri),
          slot(null), // Saturday
        ],
      ),
    );
  }
}

// ── Month labels + cell grid ──────────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final monthNames = l10n.months;
    final style = TextStyle(
      fontSize: 9,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1,
    );

    const minColGap = 3;
    final labels = <(int, String)>[];
    int? lastMonth;
    int lastLabelCol = -minColGap;
    for (int col = 0; col < weeks.length; col++) {
      for (final day in weeks[col].days) {
        if (day.date.length >= 7) {
          final dayYear = int.tryParse(day.date.substring(0, 4));
          final month = int.tryParse(day.date.substring(5, 7));
          if (month != null && month != lastMonth) {
            if (filterYear == null || dayYear == filterYear) {
              if (col - lastLabelCol >= minColGap) {
                labels.add((col, monthNames[month - 1]));
                lastLabelCol = col;
              }
            }
            lastMonth = month;
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
    final l10n = AppLocalizations.of(context);
    final color = colors[level.clamp(0, 4)];

    return Tooltip(
      message: count > 0
          ? l10n.contributionsOnDate(count, date)
          : l10n.noContributionsOnDate(date),
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
    final l10n = AppLocalizations.of(context);
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(l10n.less, style: labelStyle),
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
        Text(l10n.more, style: labelStyle),
      ],
    );
  }
}

class _HeatmapSkeleton extends StatelessWidget {
  const _HeatmapSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                for (int i = 0; i < 7; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        for (int j = 0; j < 20; j++)
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(right: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: List.generate(
              5,
              (index) => Container(
                width: 54,
                height: 20,
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
