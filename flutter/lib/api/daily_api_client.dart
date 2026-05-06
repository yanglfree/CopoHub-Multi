import 'package:dio/dio.dart';
import '../models/trending_item.dart';
import '../models/repo_analysis.dart';
import '../utils/constants.dart';
import 'api_cache.dart';
import 'api_response.dart';

class TrendingListResult {
  final List<TrendingItem> items;
  final int total;
  final int page;
  final int limit;
  final bool hasMore;

  const TrendingListResult({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.hasMore,
  });
}

class DailyApiClient {
  static DailyApiClient? _instance;
  static DailyApiClient get instance =>
      _instance ??= DailyApiClient._();

  DailyApiClient._()
      : _dio = Dio(BaseOptions(
          baseUrl: Constants.dailyBaseUrl,
          connectTimeout: Constants.connectTimeout,
          receiveTimeout: Constants.receiveTimeout,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ));

  final Dio _dio;

  // ── TTLs ────────────────────────────────────────────────────────────────────
  static const _trendingTtl = Duration(minutes: 10);
  static const _reportTtl = Duration(minutes: 30);
  static const _languagesTtl = Duration(hours: 6);
  static const _datesTtl = Duration(hours: 1);

  /// Drop daily-domain cache entries. If [date] is provided, only entries
  /// that mention it are removed; otherwise every daily entry is dropped.
  Future<void> clearCache({String? date}) async {
    if (date != null) {
      await ApiCache.instance.invalidateMatching(date);
    } else {
      await ApiCache.instance.invalidateMatching('/api/v1/trending');
      await ApiCache.instance.invalidateMatching('/reports');
    }
  }

  // ── Trending ─────────────────────────────────────────────────────────────────

  Future<ApiResponse<TrendingListResult>> getTrending(
    String date, {
    String? language,
    String since = 'daily',
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{
      'date': date,
      'since': since,
      'page': page,
      'limit': limit,
      'include_diff': true,
    };
    if (language != null && language.isNotEmpty) params['language'] = language;

    final cacheKey = ApiCache.keyFor('GET', '/api/v1/trending', params);
    final cached = ApiCache.instance.get(cacheKey);
    if (cached != null && cached.isFreshFor(_trendingTtl)) {
      return ApiResponse.ok(_parseTrending(cached.body, page, limit));
    }

    try {
      final response =
          await _dio.get<dynamic>('/api/v1/trending', queryParameters: params);
      await ApiCache.instance.put(
        cacheKey,
        CachedEntry(
            etag: null, body: response.data, fetchedAt: DateTime.now()),
      );
      return ApiResponse.ok(_parseTrending(response.data, page, limit));
    } on DioException catch (e) {
      return ApiResponse.fail(e.message ?? '网络请求失败');
    }
  }

  TrendingListResult _parseTrending(dynamic body, int page, int limit) {
    final map = body as Map<String, dynamic>;
    final dataArray = map['data'] as List<dynamic>? ?? [];
    final pagination = map['pagination'] as Map<String, dynamic>? ?? {};
    final items = dataArray
        .map((e) => TrendingItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final total = pagination['total'] as int? ?? items.length;
    final currentPage = pagination['page'] as int? ?? page;
    final currentLimit = pagination['limit'] as int? ?? limit;
    return TrendingListResult(
      items: items,
      total: total,
      page: currentPage,
      limit: currentLimit,
      hasMore: currentPage * currentLimit < total,
    );
  }

  // ── Available dates ───────────────────────────────────────────────────────────

  Future<ApiResponse<List<String>>> getAvailableDates() async {
    final cacheKey = ApiCache.keyFor('GET', '/api/v1/trending/dates');
    final cached = ApiCache.instance.get(cacheKey);
    if (cached != null && cached.isFreshFor(_datesTtl)) {
      return ApiResponse.ok((cached.body as Map<String, dynamic>)['dates']
              ?.cast<String>() ??
          <String>[]);
    }

    try {
      final response =
          await _dio.get<dynamic>('/api/v1/trending/dates');
      await ApiCache.instance.put(
        cacheKey,
        CachedEntry(
            etag: null, body: response.data, fetchedAt: DateTime.now()),
      );
      final body = response.data as Map<String, dynamic>;
      final dates = (body['dates'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList();
      return ApiResponse.ok(dates);
    } on DioException catch (e) {
      return ApiResponse.fail(e.message ?? '网络请求失败');
    }
  }

  // ── Available languages ───────────────────────────────────────────────────────

  Future<ApiResponse<List<String>>> getLanguages() async {
    final cacheKey = ApiCache.keyFor('GET', '/api/v1/trending/languages');
    final cached = ApiCache.instance.get(cacheKey);
    if (cached != null && cached.isFreshFor(_languagesTtl)) {
      return ApiResponse.ok((cached.body as Map<String, dynamic>)['languages']
              ?.cast<String>() ??
          <String>[]);
    }

    try {
      final response =
          await _dio.get<dynamic>('/api/v1/trending/languages');
      await ApiCache.instance.put(
        cacheKey,
        CachedEntry(
            etag: null, body: response.data, fetchedAt: DateTime.now()),
      );
      final body = response.data as Map<String, dynamic>;
      final languages = (body['languages'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList();
      return ApiResponse.ok(languages);
    } on DioException catch (e) {
      return ApiResponse.fail(e.message ?? '网络请求失败');
    }
  }

  // ── Daily report ─────────────────────────────────────────────────────────────

  Future<ApiResponse<Map<String, dynamic>>> getDailyReport(
    String date, {
    String lang = 'zh',
  }) async {
    final params = {'date': date, 'lang': lang};
    final cacheKey = ApiCache.keyFor('GET', '/reports', params);
    final cached = ApiCache.instance.get(cacheKey);
    if (cached != null && cached.isFreshFor(_reportTtl)) {
      return ApiResponse.ok(normalizeReportPayload(cached.body));
    }

    try {
      final response = await _dio.get<dynamic>(
        '/reports',
        queryParameters: params,
      );
      await ApiCache.instance.put(
        cacheKey,
        CachedEntry(
            etag: null, body: response.data, fetchedAt: DateTime.now()),
      );
      return ApiResponse.ok(normalizeReportPayload(response.data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const ApiResponse(success: false, error: 'not_found');
      }
      return ApiResponse.fail(e.message ?? '网络请求失败');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getLatestReport(
      {String lang = 'zh'}) async {
    final params = {'lang': lang};
    final cacheKey = ApiCache.keyFor('GET', '/reports/latest', params);
    final cached = ApiCache.instance.get(cacheKey);
    if (cached != null && cached.isFreshFor(_reportTtl)) {
      return ApiResponse.ok(normalizeReportPayload(cached.body));
    }

    try {
      final response = await _dio.get<dynamic>(
        '/reports/latest',
        queryParameters: params,
      );
      await ApiCache.instance.put(
        cacheKey,
        CachedEntry(
            etag: null, body: response.data, fetchedAt: DateTime.now()),
      );
      return ApiResponse.ok(normalizeReportPayload(response.data));
    } on DioException catch (e) {
      return ApiResponse.fail(e.message ?? '网络请求失败');
    }
  }

  static Map<String, dynamic> normalizeReportPayload(dynamic body) {
    final map = body as Map<String, dynamic>;
    return map['data'] as Map<String, dynamic>? ?? map;
  }

  // ── Repo analysis ─────────────────────────────────────────────────────────────

  Future<ApiResponse<RepoAnalysis>> getRepoAnalysis(
      String owner, String repo) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/v1/repo-analyses/$owner/$repo',
      );
      final body = response.data;
      final json = body is Map<String, dynamic> ? body : body['data'] as Map<String, dynamic>;
      return ApiResponse.ok(RepoAnalysis.fromJson(json));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return ApiResponse.fail('暂无分析数据');
      }
      return ApiResponse.fail(e.message ?? '网络请求失败');
    }
  }

  Future<ApiResponse<RepoAnalysis>> triggerRepoAnalysis(
      String owner, String repo) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/repo-analyses/$owner/$repo',
        options: Options(
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      final body = response.data;
      final json = body is Map<String, dynamic> ? body : body['data'] as Map<String, dynamic>;
      return ApiResponse.ok(RepoAnalysis.fromJson(json));
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        return ApiResponse.fail('请求过于频繁，请稍后再试');
      }
      return ApiResponse.fail(e.message ?? '网络请求失败');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> analyzeRepository(
      String owner, String repo) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/analyze',
        data: {'owner': owner, 'repo': repo},
      );
      return ApiResponse.ok(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse.fail(e.message ?? '网络请求失败');
    }
  }
}
