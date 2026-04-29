import '../api/github_api_client.dart';
import '../services/auth_service.dart';

/// Mirrors HarmonyOS ContributionService.
/// Fetches & caches contribution heatmap data per user/year.
class ContributionService {
  ContributionService._();
  static final instance = ContributionService._();

  final _api = GitHubApiClient.instance;

  // In-memory cache: '$username-$year' → (data, fetchedAt)
  final _cache = <String, _CacheEntry>{};

  static const _ttl = Duration(hours: 1);

  String _key(String username, int year) => '$username-$year';

  /// Returns contribution summary for [username] in [year].
  /// If [username] is omitted, uses the currently logged-in user.
  Future<ContributionSummary?> getSummary({
    int? year,
    String? username,
  }) async {
    final targetYear = year ?? DateTime.now().year;
    final targetUsername =
        username ?? AuthService.instance.currentUser?.login ?? '';
    if (targetUsername.isEmpty) return null;

    final key = _key(targetUsername, targetYear);
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _ttl) {
      return cached.summary;
    }

    final resp = await _api.getUserContributionStats(targetUsername, targetYear);
    if (!resp.isSuccess || resp.data == null) {
      return ContributionSummary(
        year: targetYear,
        username: targetUsername,
        weeks: _generateWeeks(targetYear, {}),
        totalContributions: 0,
        maxContributions: 0,
      );
    }

    final stats = resp.data!;
    final weeks = _generateWeeks(targetYear, stats.contributionsByDate);
    final summary = ContributionSummary(
      year: targetYear,
      username: targetUsername,
      weeks: weeks,
      totalContributions: stats.totalContributions,
      maxContributions: stats.maxContributions,
    );
    _cache[key] = _CacheEntry(summary: summary, fetchedAt: DateTime.now());
    return summary;
  }

  /// Returns contribution summary for the last ~52 weeks (trailing year).
  /// This mirrors GitHub's default "last year" view on profile pages.
  Future<ContributionSummary?> getSummaryLastYear({String? username}) async {
    final targetUsername =
        username ?? AuthService.instance.currentUser?.login ?? '';
    if (targetUsername.isEmpty) return null;

    final cacheKey = '$targetUsername-lastYear';
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _ttl) {
      return cached.summary;
    }

    final to = DateTime.now();
    final from = to.subtract(const Duration(days: 364));

    final resp =
        await _api.getUserContributionStatsByRange(targetUsername, from, to);
    if (!resp.isSuccess || resp.data == null) {
      return ContributionSummary(
        year: 0,
        isLastYear: true,
        username: targetUsername,
        weeks: _generateWeeksByRange(from, to, {}),
        totalContributions: 0,
        maxContributions: 0,
      );
    }

    final stats = resp.data!;
    final weeks = _generateWeeksByRange(from, to, stats.contributionsByDate);
    final summary = ContributionSummary(
      year: 0,
      isLastYear: true,
      username: targetUsername,
      weeks: weeks,
      totalContributions: stats.totalContributions,
      maxContributions: stats.maxContributions,
    );
    _cache[cacheKey] = _CacheEntry(summary: summary, fetchedAt: DateTime.now());
    return summary;
  }

  void clearCache() => _cache.clear();

  List<ContributionWeek> _generateWeeks(
      int year, Map<String, int> byDate) {
    return _generateWeeksByRange(
        DateTime(year, 1, 1), DateTime(year, 12, 31), byDate);
  }

  List<ContributionWeek> _generateWeeksByRange(
      DateTime from, DateTime to, Map<String, int> byDate) {
    // Find the Sunday on or before `from`
    var weekStart = from.subtract(Duration(days: from.weekday % 7));

    final weeks = <ContributionWeek>[];
    while (!weekStart.isAfter(to)) {
      final days = <ContributionDay>[];
      for (int i = 0; i < 7; i++) {
        final day = weekStart.add(Duration(days: i));
        final key =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final count = byDate[key] ?? 0;
        days.add(ContributionDay(
          date: key,
          count: count,
          level: _level(count),
        ));
      }
      weeks.add(ContributionWeek(days: days));
      weekStart = weekStart.add(const Duration(days: 7));
    }
    return weeks;
  }

  int _level(int count) {
    if (count == 0) return 0;
    if (count <= 2) return 1;
    if (count <= 5) return 2;
    if (count <= 10) return 3;
    return 4;
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

class ContributionDay {
  const ContributionDay({
    required this.date,
    required this.count,
    required this.level,
  });
  final String date; // yyyy-MM-dd
  final int count;
  final int level; // 0-4
}

class ContributionWeek {
  const ContributionWeek({required this.days});
  final List<ContributionDay> days;
}

class ContributionSummary {
  const ContributionSummary({
    required this.year,
    required this.username,
    required this.weeks,
    required this.totalContributions,
    required this.maxContributions,
    this.isLastYear = false,
  });
  final int year;
  final String username;
  final List<ContributionWeek> weeks;
  final int totalContributions;
  final int maxContributions;
  /// True when this summary represents a trailing-year range, not a calendar year.
  final bool isLastYear;
}

class _CacheEntry {
  const _CacheEntry({required this.summary, required this.fetchedAt});
  final ContributionSummary summary;
  final DateTime fetchedAt;
}
