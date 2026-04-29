import 'package:dio/dio.dart';
import '../models/copohub_curated_item.dart';
import '../utils/constants.dart';
import 'api_cache.dart';
import 'api_response.dart';

class CopoHubApiClient {
  static CopoHubApiClient? _instance;
  static CopoHubApiClient get instance =>
      _instance ??= CopoHubApiClient._();

  CopoHubApiClient._()
      : _dio = Dio(BaseOptions(
          baseUrl: Constants.copoHubBaseUrl,
          connectTimeout: Constants.connectTimeout,
          receiveTimeout: Constants.receiveTimeout,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ));

  final Dio _dio;
  static const _curatedTtl = Duration(minutes: 30);

  Future<void> clearCache() async {
    await ApiCache.instance.invalidateMatching('/api/v1/featured');
  }

  // ── Curated list ─────────────────────────────────────────────────────────────

  Future<ApiResponse<List<CopoHubCuratedItem>>> getCuratedList(
      {int limit = 20}) async {
    final params = {'limit': limit};
    final cacheKey = ApiCache.keyFor('GET', '/api/v1/featured', params);
    final cached = ApiCache.instance.get(cacheKey);
    if (cached != null && cached.isFreshFor(_curatedTtl)) {
      return ApiResponse.ok(_parseCurated(cached.body));
    }

    try {
      final response = await _dio.get<dynamic>(
        '/api/v1/featured',
        queryParameters: params,
      );
      await ApiCache.instance.put(
        cacheKey,
        CachedEntry(
            etag: null, body: response.data, fetchedAt: DateTime.now()),
      );
      return ApiResponse.ok(_parseCurated(response.data));
    } on DioException catch (e) {
      return ApiResponse.fail(e.message ?? '网络请求失败');
    }
  }

  List<CopoHubCuratedItem> _parseCurated(dynamic body) {
    final data = (body as Map<String, dynamic>)['data']
        as Map<String, dynamic>?;
    if (data == null) return [];
    final algorithmPicks = (data['algorithm_picks'] as List<dynamic>? ?? [])
        .map((e) =>
            CopoHubCuratedItem.fromFeaturedJson(e as Map<String, dynamic>))
        .toList();
    final manualPicks = (data['manual_picks'] as List<dynamic>? ?? [])
        .map((e) =>
            CopoHubCuratedItem.fromFeaturedJson(e as Map<String, dynamic>))
        .toList();
    return [...algorithmPicks, ...manualPicks]
      ..sort((a, b) => a.rank.compareTo(b.rank));
  }

  Future<ApiResponse<CopoHubCuratedItem>> getCuratedDetail(String id) async {
    final listResult = await getCuratedList();
    if (listResult.isSuccess) {
      final item = listResult.data!.where((i) => i.id == id).firstOrNull;
      if (item != null) return ApiResponse.ok(item);
    }
    return ApiResponse.fail('精选项目不存在');
  }
}
