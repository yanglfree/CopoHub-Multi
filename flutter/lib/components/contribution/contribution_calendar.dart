import 'package:flutter/material.dart';
import '../../../services/contribution_service.dart';

/// GitHub-style contribution heatmap calendar.
/// Mirrors HarmonyOS ContributionCalendar.ets.
///
/// Usage:
/// ```dart
/// ContributionCalendar(
///   summary: summary,
///   onYearChanged: (y) { ... },
/// )
/// ```
class ContributionCalendar extends StatefulWidget {
  const ContributionCalendar({
    super.key,
    required this.username,
    this.initialYear,
  });

  final String username;
  final int? initialYear;

  @override
  State<ContributionCalendar> createState() => _ContributionCalendarState();
}

class _ContributionCalendarState extends State<ContributionCalendar> {
  late int _year;
  final _service = ContributionService.instance;

  ContributionSummary? _summary;
  bool _loading = true;
  String _error = '';

  static const _minYear = 2008; // GitHub founding year

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear ?? DateTime.now().year;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final summary =
        await _service.getSummary(year: _year, username: widget.username);
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

  void _changeYear(int delta) {
    final next = _year + delta;
    if (next > DateTime.now().year || next < _minYear) return;
    setState(() => _year = next);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header row (title + year switcher) ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: Row(
            children: [
              Text(
                '贡献热力图',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (_summary != null)
                Text(
                  '${_summary!.totalContributions} contributions',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              const SizedBox(width: 8),
              _YearStepper(
                year: _year,
                onPrev: _year > _minYear ? () => _changeYear(-1) : null,
                onNext:
                    _year < DateTime.now().year ? () => _changeYear(1) : null,
              ),
            ],
          ),
        ),

        // ── Calendar grid ────────────────────────────────────────────────────
        if (_loading)
          const SizedBox(
            height: 90,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_error.isNotEmpty)
          SizedBox(
            height: 90,
            child: Center(
              child: Text(_error,
                  style: TextStyle(
                      color: cs.error, fontSize: 12)),
            ),
          )
        else if (_summary != null)
          _CalendarGrid(summary: _summary!, isDark: isDark),

        // ── Legend ──────────────────────────────────────────────────────────
        const SizedBox(height: 6),
        _Legend(isDark: isDark),
      ],
    );
  }
}

// ── Year stepper ──────────────────────────────────────────────────────────────

class _YearStepper extends StatelessWidget {
  const _YearStepper({
    required this.year,
    required this.onPrev,
    required this.onNext,
  });
  final int year;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBtn(icon: Icons.chevron_left, onTap: onPrev),
        const SizedBox(width: 4),
        Text('$year',
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(width: 4),
        _StepBtn(icon: Icons.chevron_right, onTap: onNext),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Icon(
        icon,
        size: 18,
        color: onTap != null ? cs.onSurface : cs.onSurface.withOpacity(0.3),
      ),
    );
  }
}

// ── Calendar grid ─────────────────────────────────────────────────────────────

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.summary, required this.isDark});
  final ContributionSummary summary;
  final bool isDark;

  static const _cellSize = 10.0;
  static const _cellGap = 2.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 7 * (_cellSize + _cellGap),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: summary.weeks.map((week) {
            return Padding(
              padding: const EdgeInsets.only(right: _cellGap),
              child: Column(
                children: List.generate(7, (i) {
                  final day = i < week.days.length ? week.days[i] : null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: _cellGap),
                    child: _Cell(
                      level: day?.level ?? 0,
                      count: day?.count ?? 0,
                      date: day?.date ?? '',
                      isDark: isDark,
                      size: _cellSize,
                    ),
                  );
                }),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.level,
    required this.count,
    required this.date,
    required this.isDark,
    required this.size,
  });
  final int level;
  final int count;
  final String date;
  final bool isDark;
  final double size;

  static const _lightColors = [
    Color(0xFFEBEDF0),
    Color(0xFF9BE9A8),
    Color(0xFF40C463),
    Color(0xFF30A14E),
    Color(0xFF216E39),
  ];

  static const _darkColors = [
    Color(0xFF161B22),
    Color(0xFF0E4429),
    Color(0xFF006D32),
    Color(0xFF26A641),
    Color(0xFF39D353),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = isDark ? _darkColors : _lightColors;
    final color = colors[level.clamp(0, 4)];

    return Tooltip(
      message: count > 0 ? '$count contributions on $date' : 'No contributions on $date',
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
  const _Legend({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? _Cell._darkColors
        : _Cell._lightColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Less',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant)),
        const SizedBox(width: 4),
        ...colors.map((c) => Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(2),
              ),
            )),
        const SizedBox(width: 2),
        Text('More',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant)),
      ],
    );
  }
}
