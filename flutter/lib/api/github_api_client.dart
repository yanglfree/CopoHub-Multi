import 'package:dio/dio.dart';
import '../models/user.dart';
import '../models/user_status.dart';
import '../models/repository.dart';
import '../models/github_org.dart';
import '../models/pinned_repository.dart';
import '../utils/constants.dart';
import '../utils/api_error_message.dart';
import 'api_cache.dart';
import 'api_response.dart';
import 'rate_limit_status.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

/// Contribution heatmap data for a single [year].
class ContributionStatsData {
  const ContributionStatsData({
    required this.year,
    required this.contributionsByDate,
    required this.totalContributions,
    required this.maxContributions,
  });
  final int year;

  /// Map from date string (yyyy-MM-dd) to commit count.
  final Map<String, int> contributionsByDate;
  final int totalContributions;
  final int maxContributions;
}

// ── Typedef so callers can react to auth invalidation ──────────────────────────
typedef AuthInvalidationHandler = Future<void> Function(String message);

const _sessionExpiredMessage = '登录已过期，请重新登录';

/// Dart/dio equivalent of the HarmonyOS GitHubAPIClient.
///
/// All public methods return [ApiResponse<T>] and never throw.
class GitHubApiClient {
  static GitHubApiClient? _instance;
  static GitHubApiClient get instance => _instance ??= GitHubApiClient._();

  GitHubApiClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: Constants.apiBaseUrl,
      connectTimeout: Constants.connectTimeout,
      receiveTimeout: Constants.receiveTimeout,
      // Treat 304 as a normal response so the ETag flow can read it.
      validateStatus: (s) => s != null && (s >= 200 && s < 300 || s == 304),
      headers: {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': Constants.apiVersion,
        'User-Agent': Constants.userAgent,
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_accessToken.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        RateLimitStatus.instance.update(response.headers.map);
        handler.next(response);
      },
      onError: (err, handler) async {
        if (err.response?.headers.map != null) {
          RateLimitStatus.instance.update(err.response!.headers.map);
        }
        if (err.response?.statusCode == 401 && _accessToken.isNotEmpty) {
          await _notifyAuthInvalidation(_sessionExpiredMessage);
        }
        handler.next(err);
      },
    ));
  }

  late final Dio _dio;
  String _accessToken = '';
  AuthInvalidationHandler? _authInvalidationHandler;
  bool _isNotifyingAuth = false;

  /// In-flight GET requests by cache key, used to deduplicate concurrent
  /// callers (e.g. two widgets that mount at once and both fetch the same
  /// resource).
  final Map<String, Future<ApiResponse<dynamic>>> _inflight = {};

  /// Short-TTL memory cache for binary existence checks (star / follow).
  /// These endpoints reply 204/404 with no body, so the body cache layer
  /// can't help; this is a separate tiny map keyed by `path`.
  final Map<String, _BoolCacheEntry> _boolCache = {};
  static const _boolCacheTtl = Duration(minutes: 2);

  // ── Token management ──────────────────────────────────────────────────────────
  void setAccessToken(String token) => _accessToken = token;
  String getAccessToken() => _accessToken;

  /// Drop all per-user caches. Call on logout so the next session can't see
  /// the previous user's data.
  Future<void> clearAllCaches() async {
    _boolCache.clear();
    _inflight.clear();
    await ApiCache.instance.clearAll();
  }

  /// Drop cached entries for a specific repository (the listing pages and
  /// the detail page), so a follow-up navigation will refetch.
  Future<void> invalidateRepositoryCache(String owner, String repo) async {
    await ApiCache.instance.invalidateMatching('/repos/$owner/$repo');
    _boolCache.remove('/user/starred/$owner/$repo');
  }

  void setAuthInvalidationHandler(AuthInvalidationHandler? handler) {
    _authInvalidationHandler = handler;
  }

  Future<void> _notifyAuthInvalidation(String message) async {
    if (_authInvalidationHandler == null || _isNotifyingAuth) return;
    _isNotifyingAuth = true;
    try {
      await _authInvalidationHandler!(message);
    } catch (_) {
    } finally {
      _isNotifyingAuth = false;
    }
  }

  // ── Low-level helpers ─────────────────────────────────────────────────────────

  /// Cached + deduplicated GET.
  ///
  /// - If cached body is fresher than [ttl], returns it without hitting the
  ///   network at all.
  /// - Otherwise sends `If-None-Match` with the stored ETag; on 304 the cached
  ///   body is reused (304 responses don't count against the rate limit).
  /// - On 200 the body + new ETag are persisted.
  /// - Concurrent callers for the same `(path, params)` share one in-flight
  ///   future.
  Future<ApiResponse<T>> _get<T>(
    String path, {
    Map<String, dynamic>? params,
    T Function(dynamic)? parser,
    Duration ttl = Duration.zero,
    bool forceRefresh = false,
  }) async {
    final cacheKey = ApiCache.keyFor('GET', path, params);

    // Fast path: cache fresh, skip network entirely.
    if (!forceRefresh && ttl > Duration.zero) {
      final cached = ApiCache.instance.get(cacheKey);
      if (cached != null && cached.isFreshFor(ttl)) {
        return ApiResponse.ok(
            parser != null ? parser(cached.body) : cached.body as T);
      }
    }

    // Dedup concurrent identical requests.
    final existing = _inflight[cacheKey];
    if (existing != null) {
      final result = await existing;
      if (!result.isSuccess) {
        return ApiResponse.fail(result.error ?? 'request failed');
      }
      final body = result.data;
      return ApiResponse.ok(parser != null ? parser(body) : body as T);
    }

    final cachedForEtag = forceRefresh ? null : ApiCache.instance.get(cacheKey);

    final future = _performGet(
      path: path,
      params: params,
      cacheKey: cacheKey,
      etag: cachedForEtag?.etag,
      cachedBody: cachedForEtag?.body,
    );
    _inflight[cacheKey] = future;
    try {
      final raw = await future;
      if (!raw.isSuccess) {
        return ApiResponse.fail(raw.error ?? 'request failed');
      }
      final body = raw.data;
      return ApiResponse.ok(parser != null ? parser(body) : body as T);
    } finally {
      _inflight.remove(cacheKey);
    }
  }

  /// Network leg of [_get]. Returns the raw decoded body wrapped in
  /// [ApiResponse]. Caching side effects happen here.
  Future<ApiResponse<dynamic>> _performGet({
    required String path,
    Map<String, dynamic>? params,
    required String cacheKey,
    String? etag,
    dynamic cachedBody,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: params,
        options:
            etag != null ? Options(headers: {'If-None-Match': etag}) : null,
      );

      if (response.statusCode == 304 && cachedBody != null) {
        await ApiCache.instance.touch(cacheKey);
        return ApiResponse.ok(cachedBody);
      }

      final newEtag =
          response.headers.value('etag') ?? response.headers.value('ETag');
      await ApiCache.instance.put(
        cacheKey,
        CachedEntry(
          etag: newEtag,
          body: response.data,
          fetchedAt: DateTime.now(),
        ),
      );
      return ApiResponse.ok(response.data);
    } on DioException catch (e) {
      return _handleDioError<dynamic>(e);
    }
  }

  Future<ApiResponse<T>> _post<T>(
    String path, {
    Object? data,
    T Function(dynamic)? parser,
  }) async {
    try {
      final response = await _dio.post<dynamic>(path, data: data);
      return ApiResponse.ok(
          parser != null ? parser(response.data) : response.data as T);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ignore: unused_element
  Future<ApiResponse<T>> _put<T>(
    String path, {
    Object? data,
    T Function(dynamic)? parser,
  }) async {
    try {
      final response = await _dio.put<dynamic>(path, data: data);
      return ApiResponse.ok(
          parser != null ? parser(response.data) : response.data as T);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ignore: unused_element
  Future<ApiResponse<T>> _delete<T>(
    String path, {
    T Function(dynamic)? parser,
  }) async {
    try {
      final response = await _dio.delete<dynamic>(path);
      return ApiResponse.ok(
          parser != null ? parser(response.data) : response.data as T);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ignore: unused_element
  Future<ApiResponse<T>> _patch<T>(
    String path, {
    Object? data,
    T Function(dynamic)? parser,
  }) async {
    try {
      final response = await _dio.patch<dynamic>(path, data: data);
      return ApiResponse.ok(
          parser != null ? parser(response.data) : response.data as T);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// Existence-style endpoint helper: 204 → true, 404 → false. Result is
  /// cached for [_boolCacheTtl] in memory so repeated detail-page entries
  /// don't keep re-asking the same question.
  Future<ApiResponse<bool>> _checkExistence(
    String path, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _boolCache[path];
      if (cached != null &&
          DateTime.now().difference(cached.fetchedAt) < _boolCacheTtl) {
        return ApiResponse.ok(cached.value);
      }
    }
    try {
      await _dio.get<dynamic>(path);
      _boolCache[path] = _BoolCacheEntry(true, DateTime.now());
      return ApiResponse.ok(true);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        _boolCache[path] = _BoolCacheEntry(false, DateTime.now());
        return ApiResponse.ok(false);
      }
      return _handleDioError(e);
    }
  }

  ApiResponse<T> _handleDioError<T>(DioException e) {
    final statusCode = e.response?.statusCode;
    final message = friendlyDioErrorMessage(
      e,
      fallback: statusCode == null ? '网络请求失败，请稍后重试' : '请求失败，请稍后重试',
    );

    if (statusCode == 401 && _accessToken.isNotEmpty) {
      _notifyAuthInvalidation(_sessionExpiredMessage);
    }

    return ApiResponse.fail(message);
  }

  // ── User APIs ──────────────────────────────────────────────────────────────────

  Future<ApiResponse<GithubUser>> getCurrentUser({
    bool forceRefresh = false,
  }) =>
      _get<GithubUser>(
        '/user',
        parser: (d) => GithubUser.fromJson(d as Map<String, dynamic>),
        ttl: const Duration(seconds: 30),
        forceRefresh: forceRefresh,
      );

  Future<ApiResponse<GithubUser>> updateCurrentUserProfile({
    String? name,
    String? email,
    String? blog,
    String? twitterUsername,
    String? company,
    String? location,
    bool? hireable,
    String? bio,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (email != null) data['email'] = email;
    if (blog != null) data['blog'] = blog;
    if (twitterUsername != null) {
      data['twitter_username'] =
          twitterUsername.isEmpty ? null : twitterUsername;
    }
    if (company != null) data['company'] = company;
    if (location != null) data['location'] = location;
    if (hireable != null) data['hireable'] = hireable;
    if (bio != null) data['bio'] = bio;

    final result = await _patch<GithubUser>(
      '/user',
      data: data,
      parser: (d) => GithubUser.fromJson(d as Map<String, dynamic>),
    );
    if (result.isSuccess && result.data != null) {
      await ApiCache.instance.invalidate(ApiCache.keyFor('GET', '/user'));
      await ApiCache.instance.invalidate(
        ApiCache.keyFor('GET', '/users/${result.data!.login}'),
      );
    }
    return result;
  }

  Future<ApiResponse<GithubUser>> getUser(
    String username, {
    bool forceRefresh = false,
  }) =>
      _get<GithubUser>(
        '/users/$username',
        parser: (d) => GithubUser.fromJson(d as Map<String, dynamic>),
        ttl: const Duration(minutes: 1),
        forceRefresh: forceRefresh,
      );

  Future<ApiResponse<List<GithubUser>>> getUserFollowers(
    String username, {
    int page = 1,
    int perPage = 30,
  }) =>
      _get<List<GithubUser>>(
        '/users/$username/followers',
        params: {'page': page, 'per_page': perPage},
        parser: (d) => (d as List<dynamic>)
            .map((e) => GithubUser.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<ApiResponse<List<GithubUser>>> getUserFollowing(
    String username, {
    int page = 1,
    int perPage = 30,
  }) =>
      _get<List<GithubUser>>(
        '/users/$username/following',
        params: {'page': page, 'per_page': perPage},
        parser: (d) => (d as List<dynamic>)
            .map((e) => GithubUser.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<ApiResponse<GithubUserStatus?>> getUserStatus(String username) async {
    const query = r'''
query($login: String!) {
  user(login: $login) {
    status {
      emoji
      message
      indicatesLimitedAvailability
      expiresAt
      updatedAt
      organization { login }
    }
  }
}''';
    final result = await graphql(query, variables: {'login': username});
    if (!result.success || result.data == null) {
      return ApiResponse.fail(result.error ?? '加载状态失败');
    }
    final user = result.data!['user'] as Map<String, dynamic>?;
    final status = user?['status'] as Map<String, dynamic>?;
    return ApiResponse<GithubUserStatus?>(
      success: true,
      data: status == null ? null : GithubUserStatus.fromJson(status),
    );
  }

  Future<ApiResponse<GithubUserStatus?>> changeUserStatus({
    String? emoji,
    String? message,
    bool? limitedAvailability,
    String? expiresAt,
    String? organizationId,
  }) async {
    const mutation = r'''
mutation($input: ChangeUserStatusInput!) {
  changeUserStatus(input: $input) {
    status {
      emoji
      message
      indicatesLimitedAvailability
      expiresAt
      updatedAt
      organization { login }
    }
  }
}''';
    final input = <String, dynamic>{};
    if (emoji != null) input['emoji'] = emoji.isEmpty ? null : emoji;
    if (message != null) input['message'] = message.isEmpty ? null : message;
    if (limitedAvailability != null) {
      input['limitedAvailability'] = limitedAvailability;
    }
    if (expiresAt != null) input['expiresAt'] = expiresAt;
    if (organizationId != null) input['organizationId'] = organizationId;

    final result = await graphql(mutation, variables: {'input': input});
    if (!result.success || result.data == null) {
      return ApiResponse.fail(result.error ?? '更新状态失败');
    }
    final payload = result.data!['changeUserStatus'] as Map<String, dynamic>?;
    final status = payload?['status'] as Map<String, dynamic>?;
    return ApiResponse<GithubUserStatus?>(
      success: true,
      data: status == null ? null : GithubUserStatus.fromJson(status),
    );
  }

  Future<ApiResponse<bool>> checkUserFollowing(
    String username, {
    bool forceRefresh = false,
  }) =>
      _checkExistence('/user/following/$username', forceRefresh: forceRefresh);

  Future<ApiResponse<void>> followUser(String username) async {
    try {
      await _dio.put<dynamic>('/user/following/$username', data: {});
      _boolCache['/user/following/$username'] =
          _BoolCacheEntry(true, DateTime.now());
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  Future<ApiResponse<void>> unfollowUser(String username) async {
    try {
      await _dio.delete<dynamic>('/user/following/$username');
      _boolCache['/user/following/$username'] =
          _BoolCacheEntry(false, DateTime.now());
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  Future<ApiResponse<List<GithubOrg>>> getUserOrgs(String username) =>
      _get<List<GithubOrg>>(
        '/users/$username/orgs',
        parser: (d) => (d as List<dynamic>)
            .map((e) => GithubOrg.fromJson(e as Map<String, dynamic>))
            .toList(),
        ttl: const Duration(minutes: 10),
      );

  Future<ApiResponse<List<Map<String, dynamic>>>> getUserEvents(
    String username, {
    int page = 1,
    int perPage = 100,
  }) =>
      _get<List<Map<String, dynamic>>>(
        '/users/$username/events',
        params: {'page': page, 'per_page': perPage},
        parser: (d) =>
            (d as List<dynamic>).map((e) => e as Map<String, dynamic>).toList(),
        ttl: const Duration(minutes: 5),
      );

  /// Authenticated user's own events, including private repo events.
  Future<ApiResponse<List<Map<String, dynamic>>>> getMyEvents({
    int page = 1,
    int perPage = 100,
  }) =>
      _get<List<Map<String, dynamic>>>(
        '/user/events',
        params: {'page': page, 'per_page': perPage},
        parser: (d) =>
            (d as List<dynamic>).map((e) => e as Map<String, dynamic>).toList(),
        ttl: const Duration(minutes: 5),
      );

  /// Top repos by star count for [username] via GraphQL.
  Future<ApiResponse<List<PinnedRepository>>> getUserTopRepos(
    String username, {
    int count = 6,
  }) async {
    const query = r'''
query($login: String!, $count: Int!) {
  user(login: $login) {
    repositories(
      first: $count
      ownerAffiliations: [OWNER]
      orderBy: { field: STARGAZERS, direction: DESC }
    ) {
      nodes {
        name
        nameWithOwner
        description
        stargazerCount
        forkCount
        primaryLanguage { name color }
      }
    }
  }
}''';
    final result =
        await graphql(query, variables: {'login': username, 'count': count});
    if (!result.isSuccess || result.data == null) return ApiResponse.ok([]);
    try {
      final user = result.data!['user'] as Map<String, dynamic>?;
      if (user == null) return ApiResponse.ok([]);
      final nodes = ((user['repositories'] as Map)['nodes'] as List<dynamic>);
      final repos = nodes.whereType<Map<String, dynamic>>().map((n) {
        final lang = n['primaryLanguage'] as Map<String, dynamic>?;
        return PinnedRepository(
          name: n['name'] as String? ?? '',
          fullName: n['nameWithOwner'] as String? ?? '',
          description: n['description'] as String? ?? '',
          stargazerCount: n['stargazerCount'] as int? ?? 0,
          forkCount: n['forkCount'] as int? ?? 0,
          languageName: lang?['name'] as String? ?? '',
          languageColor: lang?['color'] as String? ?? '',
        );
      }).toList();
      return ApiResponse.ok(repos);
    } catch (_) {
      return ApiResponse.ok([]);
    }
  }

  Future<ApiResponse<List<PinnedRepository>>> getUserPinnedRepos(
      String username) async {
    const query = r'''
query($login: String!) {
  user(login: $login) {
    pinnedItems(first: 6, types: [REPOSITORY]) {
      nodes {
        ... on Repository {
          name
          nameWithOwner
          description
          stargazerCount
          forkCount
          primaryLanguage { name color }
        }
      }
    }
  }
}''';
    final result = await graphql(query, variables: {'login': username});
    if (!result.isSuccess || result.data == null) {
      return ApiResponse.ok([]);
    }
    try {
      final user = result.data!['user'] as Map<String, dynamic>?;
      if (user == null) return ApiResponse.ok([]);
      final nodes = ((user['pinnedItems'] as Map)['nodes'] as List<dynamic>);
      final repos = nodes.whereType<Map<String, dynamic>>().map((n) {
        final lang = n['primaryLanguage'] as Map<String, dynamic>?;
        return PinnedRepository(
          name: n['name'] as String? ?? '',
          fullName: n['nameWithOwner'] as String? ?? '',
          description: n['description'] as String? ?? '',
          stargazerCount: n['stargazerCount'] as int? ?? 0,
          forkCount: n['forkCount'] as int? ?? 0,
          languageName: lang?['name'] as String? ?? '',
          languageColor: lang?['color'] as String? ?? '',
        );
      }).toList();
      return ApiResponse.ok(repos);
    } catch (_) {
      return ApiResponse.ok([]);
    }
  }

  // ── Repository APIs ────────────────────────────────────────────────────────────

  Future<ApiResponse<List<Repository>>> getUserRepositories({
    String visibility = 'all',
    String sort = 'updated',
    String direction = 'desc',
    int page = 1,
    int perPage = 30,
  }) =>
      _get<List<Repository>>(
        '/user/repos',
        params: {
          'visibility': visibility,
          'sort': sort,
          'direction': direction,
          'page': page,
          'per_page': perPage,
        },
        parser: (d) => (d as List<dynamic>)
            .map((e) => Repository.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<ApiResponse<List<Repository>>> getUserPublicRepositories(
    String username, {
    String sort = 'updated',
    String direction = 'desc',
    int page = 1,
    int perPage = 30,
  }) =>
      _get<List<Repository>>(
        '/users/$username/repos',
        params: {
          'sort': sort,
          'direction': direction,
          'page': page,
          'per_page': perPage,
        },
        parser: (d) => (d as List<dynamic>)
            .map((e) => Repository.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<ApiResponse<Repository>> getRepository(
    String owner,
    String repo, {
    bool forceRefresh = false,
  }) =>
      _get<Repository>(
        '/repos/$owner/$repo',
        parser: (d) => Repository.fromJson(d as Map<String, dynamic>),
        ttl: const Duration(minutes: 1),
        forceRefresh: forceRefresh,
      );

  Future<ApiResponse<Repository>> createRepository(
          Map<String, dynamic> repoData) =>
      _post<Repository>(
        '/user/repos',
        data: repoData,
        parser: (d) => Repository.fromJson(d as Map<String, dynamic>),
      );

  Future<ApiResponse<Repository>> forkRepository(
    String owner,
    String repo, {
    bool defaultBranchOnly = false,
  }) =>
      _post<Repository>(
        '/repos/$owner/$repo/forks',
        data: {'default_branch_only': defaultBranchOnly},
        parser: (d) => Repository.fromJson(d as Map<String, dynamic>),
      );

  // ── Stars ──────────────────────────────────────────────────────────────────────

  Future<ApiResponse<List<Repository>>> getUserStarredRepositories({
    String? username,
    String sort = 'created',
    String direction = 'desc',
    int page = 1,
    int perPage = 30,
  }) {
    final endpoint =
        username != null ? '/users/$username/starred' : '/user/starred';
    return _get<List<Repository>>(
      endpoint,
      params: {
        'sort': sort,
        'direction': direction,
        'page': page,
        'per_page': perPage,
      },
      parser: (d) => (d as List<dynamic>)
          .map((e) => Repository.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<ApiResponse<bool>> checkRepositoryStarred(
    String owner,
    String repo, {
    bool forceRefresh = false,
  }) =>
      _checkExistence('/user/starred/$owner/$repo', forceRefresh: forceRefresh);

  Future<ApiResponse<void>> starRepository(String owner, String repo) async {
    try {
      await _dio.put<dynamic>('/user/starred/$owner/$repo', data: {});
      _boolCache['/user/starred/$owner/$repo'] =
          _BoolCacheEntry(true, DateTime.now());
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  Future<ApiResponse<void>> unstarRepository(String owner, String repo) async {
    try {
      await _dio.delete<dynamic>('/user/starred/$owner/$repo');
      _boolCache['/user/starred/$owner/$repo'] =
          _BoolCacheEntry(false, DateTime.now());
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ── Commits ─────────────────────────────────────────────────────────────────────

  Future<ApiResponse<List<Map<String, dynamic>>>> getRepositoryCommits(
    String owner,
    String repo, {
    String? sha,
    String? path,
    String? author,
    String? since,
    String? until,
    int page = 1,
    int perPage = 30,
  }) {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (sha != null) params['sha'] = sha;
    if (path != null) params['path'] = path;
    if (author != null) params['author'] = author;
    if (since != null) params['since'] = since;
    if (until != null) params['until'] = until;

    return _get<List<Map<String, dynamic>>>(
      '/repos/$owner/$repo/commits',
      params: params,
      parser: (d) =>
          (d as List<dynamic>).map((e) => e as Map<String, dynamic>).toList(),
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> getCommit(
          String owner, String repo, String ref) =>
      _get<Map<String, dynamic>>(
        '/repos/$owner/$repo/commits/$ref',
        parser: (d) => d as Map<String, dynamic>,
      );

  // ── Issues ───────────────────────────────────────────────────────────────────────

  Future<ApiResponse<List<Map<String, dynamic>>>> getRepositoryIssues(
    String owner,
    String repo, {
    String state = 'open',
    String? labels,
    String sort = 'created',
    String direction = 'desc',
    int page = 1,
    int perPage = 30,
    // Pass 'issue' to exclude pull requests from the result.
    String? type,
  }) {
    final params = <String, dynamic>{
      'state': state,
      'sort': sort,
      'direction': direction,
      'page': page,
      'per_page': perPage,
    };
    if (labels != null) params['labels'] = labels;
    if (type != null) params['type'] = type;

    return _get<List<Map<String, dynamic>>>(
      '/repos/$owner/$repo/issues',
      params: params,
      parser: (d) =>
          (d as List<dynamic>).map((e) => e as Map<String, dynamic>).toList(),
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> getIssue(
          String owner, String repo, int issueNumber) =>
      _get<Map<String, dynamic>>(
        '/repos/$owner/$repo/issues/$issueNumber',
        parser: (d) => d as Map<String, dynamic>,
      );

  // ── Pull Requests ─────────────────────────────────────────────────────────────────

  Future<ApiResponse<List<Map<String, dynamic>>>> getRepositoryPullRequests(
    String owner,
    String repo, {
    String state = 'open',
    String sort = 'created',
    String direction = 'desc',
    int page = 1,
    int perPage = 30,
  }) =>
      _get<List<Map<String, dynamic>>>(
        '/repos/$owner/$repo/pulls',
        params: {
          'state': state,
          'sort': sort,
          'direction': direction,
          'page': page,
          'per_page': perPage,
        },
        parser: (d) =>
            (d as List<dynamic>).map((e) => e as Map<String, dynamic>).toList(),
      );

  Future<ApiResponse<Map<String, dynamic>>> getPullRequest(
          String owner, String repo, int pullNumber) =>
      _get<Map<String, dynamic>>(
        '/repos/$owner/$repo/pulls/$pullNumber',
        parser: (d) => d as Map<String, dynamic>,
      );

  Future<ApiResponse<List<Map<String, dynamic>>>> getPullRequestReviews(
    String owner,
    String repo,
    int pullNumber,
  ) =>
      _get<List<Map<String, dynamic>>>(
        '/repos/$owner/$repo/pulls/$pullNumber/reviews',
        parser: (d) =>
            (d as List<dynamic>).map((e) => e as Map<String, dynamic>).toList(),
      );

  Future<ApiResponse<List<Map<String, dynamic>>>> getPullRequestFiles(
    String owner,
    String repo,
    int pullNumber, {
    int page = 1,
    int perPage = 30,
  }) =>
      _get<List<Map<String, dynamic>>>(
        '/repos/$owner/$repo/pulls/$pullNumber/files',
        params: {'page': page, 'per_page': perPage},
        parser: (d) =>
            (d as List<dynamic>).map((e) => e as Map<String, dynamic>).toList(),
      );

  Future<ApiResponse<List<Map<String, dynamic>>>> getPullRequestComments(
    String owner,
    String repo,
    int pullNumber, {
    int page = 1,
    int perPage = 30,
  }) =>
      _get<List<Map<String, dynamic>>>(
        '/repos/$owner/$repo/issues/$pullNumber/comments',
        params: {
          'page': page,
          'per_page': perPage,
          'sort': 'created',
          'direction': 'asc',
        },
        parser: (d) =>
            (d as List<dynamic>).map((e) => e as Map<String, dynamic>).toList(),
      );

  Future<ApiResponse<Map<String, dynamic>>> mergePullRequest(
    String owner,
    String repo,
    int pullNumber, {
    String mergeMethod = 'merge',
    String? commitTitle,
    String? commitMessage,
  }) async {
    final data = <String, dynamic>{'merge_method': mergeMethod};
    if (commitTitle != null) data['commit_title'] = commitTitle;
    if (commitMessage != null) data['commit_message'] = commitMessage;
    try {
      final response = await _dio.put<dynamic>(
        '/repos/$owner/$repo/pulls/$pullNumber/merge',
        data: data,
      );
      return ApiResponse.ok(response.data as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updatePullRequestState(
    String owner,
    String repo,
    int pullNumber, {
    required String state, // 'open' | 'closed'
  }) async {
    try {
      final response = await _dio.patch<dynamic>(
        '/repos/$owner/$repo/pulls/$pullNumber',
        data: {'state': state},
      );
      return ApiResponse.ok(response.data as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getIssueComments(
    String owner,
    String repo,
    int issueNumber, {
    int page = 1,
    int perPage = 30,
  }) =>
      _get<List<Map<String, dynamic>>>(
        '/repos/$owner/$repo/issues/$issueNumber/comments',
        params: {
          'page': page,
          'per_page': perPage,
          'sort': 'created',
          'direction': 'asc',
        },
        parser: (d) =>
            (d as List<dynamic>).map((e) => e as Map<String, dynamic>).toList(),
      );

  // ── Releases ─────────────────────────────────────────────────────────────────────

  Future<ApiResponse<List<Map<String, dynamic>>>> getRepositoryReleases(
    String owner,
    String repo, {
    int page = 1,
    int perPage = 20,
  }) =>
      _get<List<Map<String, dynamic>>>(
        '/repos/$owner/$repo/releases',
        params: {'page': page, 'per_page': perPage},
        parser: (d) =>
            (d as List<dynamic>).map((e) => e as Map<String, dynamic>).toList(),
      );

  // ── Branches & Tags ───────────────────────────────────────────────────────────────

  Future<ApiResponse<void>> createBranch({
    required String owner,
    required String repo,
    required String newBranchName,
    required String baseSha,
  }) async {
    return _post(
      '/repos/$owner/$repo/git/refs',
      data: {
        'ref': 'refs/heads/$newBranchName',
        'sha': baseSha,
      },
    );
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getRepositoryBranches(
    String owner,
    String repo, {
    int page = 1,
    int perPage = 30,
    bool forceRefresh = false,
  }) =>
      _get<List<Map<String, dynamic>>>(
        '/repos/$owner/$repo/branches',
        params: {'page': page, 'per_page': perPage},
        parser: (d) =>
            (d as List<dynamic>).map((e) => e as Map<String, dynamic>).toList(),
        ttl: const Duration(minutes: 5),
        forceRefresh: forceRefresh,
      );

  Future<ApiResponse<List<Map<String, dynamic>>>> getRepositoryTags(
    String owner,
    String repo, {
    int page = 1,
    int perPage = 30,
  }) =>
      _get<List<Map<String, dynamic>>>(
        '/repos/$owner/$repo/tags',
        params: {'page': page, 'per_page': perPage},
        parser: (d) =>
            (d as List<dynamic>).map((e) => e as Map<String, dynamic>).toList(),
        ttl: const Duration(minutes: 5),
      );

  // ── File contents ────────────────────────────────────────────────────────────────

  Future<ApiResponse<dynamic>> getFileContents(
    String owner,
    String repo,
    String path, {
    String? ref,
    bool forceRefresh = false,
  }) {
    final params = <String, dynamic>{};
    if (ref != null) params['ref'] = ref;
    return _get<dynamic>(
      '/repos/$owner/$repo/contents/$path',
      params: params,
      parser: (d) => d,
      ttl: const Duration(minutes: 1),
      forceRefresh: forceRefresh,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> getRepositoryReadme(
    String owner,
    String repo, {
    String? ref,
    bool forceRefresh = false,
  }) {
    final params = <String, dynamic>{};
    if (ref != null) params['ref'] = ref;
    return _get<Map<String, dynamic>>(
      '/repos/$owner/$repo/readme',
      params: params,
      parser: (d) => d as Map<String, dynamic>,
      ttl: const Duration(minutes: 30),
      forceRefresh: forceRefresh,
    );
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getRepositoryTree(
    String owner,
    String repo,
    String treeSha, {
    bool recursive = false,
  }) =>
      _get<List<Map<String, dynamic>>>(
        '/repos/$owner/$repo/git/trees/$treeSha',
        params: {'recursive': recursive ? '1' : '0'},
        parser: (d) {
          final data = d as Map<String, dynamic>;
          return (data['tree'] as List<dynamic>)
              .map((e) => e as Map<String, dynamic>)
              .toList();
        },
      );

  // ── Markdown rendering ────────────────────────────────────────────────────────────

  Future<ApiResponse<String>> renderMarkdown(
    String text, {
    String mode = 'markdown',
    String? context,
  }) async {
    try {
      final body = <String, dynamic>{
        'text': text,
        'mode': mode,
      };
      if (context != null) body['context'] = context;

      final response = await _dio.post<dynamic>('/markdown', data: body);
      return ApiResponse.ok(response.data as String);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ── Notifications ─────────────────────────────────────────────────────────────────

  Future<ApiResponse<List<Map<String, dynamic>>>> getNotifications({
    bool all = false,
    bool participating = false,
    int page = 1,
    int perPage = 50,
  }) =>
      _get<List<Map<String, dynamic>>>(
        '/notifications',
        params: {
          'all': all,
          'participating': participating,
          'page': page,
          'per_page': perPage,
        },
        parser: (d) =>
            (d as List<dynamic>).map((e) => e as Map<String, dynamic>).toList(),
      );

  Future<ApiResponse<void>> markAllNotificationsRead() async {
    try {
      await _dio.put<dynamic>('/notifications', data: {});
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  Future<ApiResponse<void>> markThreadRead(String threadId) async {
    try {
      await _dio.patch<dynamic>('/notifications/threads/$threadId', data: {});
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ── Search ─────────────────────────────────────────────────────────────────────────

  Future<ApiResponse<Map<String, dynamic>>> searchRepositories(
    String query, {
    String sort = 'stars',
    String order = 'desc',
    int page = 1,
    int perPage = 30,
  }) =>
      _get<Map<String, dynamic>>(
        '/search/repositories',
        params: {
          'q': query,
          'sort': sort,
          'order': order,
          'page': page,
          'per_page': perPage,
        },
        parser: (d) => d as Map<String, dynamic>,
      );

  Future<ApiResponse<Map<String, dynamic>>> searchUsers(
    String query, {
    String sort = 'followers',
    String order = 'desc',
    int page = 1,
    int perPage = 30,
  }) =>
      _get<Map<String, dynamic>>(
        '/search/users',
        params: {
          'q': query,
          'sort': sort,
          'order': order,
          'page': page,
          'per_page': perPage,
        },
        parser: (d) => d as Map<String, dynamic>,
      );

  // ── GraphQL ────────────────────────────────────────────────────────────────────────

  Future<ApiResponse<Map<String, dynamic>>> graphql(
    String query, {
    Map<String, dynamic>? variables,
  }) async {
    try {
      final body = <String, dynamic>{'query': query};
      if (variables != null) body['variables'] = variables;

      final response = await Dio(BaseOptions(
        baseUrl: 'https://api.github.com',
        connectTimeout: Constants.connectTimeout,
        receiveTimeout: Constants.receiveTimeout,
        headers: {
          'Accept': 'application/vnd.github+json',
          'Authorization': 'Bearer $_accessToken',
          'User-Agent': Constants.userAgent,
        },
      )).post<dynamic>('/graphql', data: body);

      final data = response.data as Map<String, dynamic>;
      if (data.containsKey('errors')) {
        final errors = data['errors'] as List<dynamic>;
        final errMsg = errors.map((e) => (e as Map)['message']).join(', ');
        return ApiResponse.fail('GraphQL error: $errMsg');
      }
      return ApiResponse.ok(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ── Contribution (heatmap) ───────────────────────────────────────────────────

  /// Fetch contribution data for [username] in [year].
  /// Tries GitHub GraphQL first; falls back to search/commits REST API.
  Future<ApiResponse<ContributionStatsData>> getUserContributionStats(
    String username,
    int year,
  ) async {
    final stats = await _getContributionViaGraphQL(username, year) ??
        await _getContributionViaREST(username, year);
    if (stats == null) {
      return ApiResponse.fail('获取贡献数据失败');
    }
    return ApiResponse.ok(stats);
  }

  /// Fetch contribution data for [username] within an arbitrary date range.
  /// Only uses GraphQL; returns failure if GraphQL is unavailable.
  Future<ApiResponse<ContributionStatsData>> getUserContributionStatsByRange(
    String username,
    DateTime from,
    DateTime to,
  ) async {
    final stats = await _getContributionViaGraphQLRange(username, from, to);
    if (stats == null) {
      return ApiResponse.fail('获取贡献数据失败');
    }
    return ApiResponse.ok(stats);
  }

  Future<ContributionStatsData?> _getContributionViaGraphQLRange(
      String username, DateTime from, DateTime to) async {
    const query = r'''
query($login: String!, $from: DateTime!, $to: DateTime!) {
  user(login: $login) {
    contributionsCollection(from: $from, to: $to) {
      contributionCalendar {
        totalContributions
        weeks {
          contributionDays {
            contributionCount
            date
          }
        }
      }
    }
  }
}''';
    try {
      final response = await _dio.post<dynamic>(
        'https://api.github.com/graphql',
        data: {
          'query': query,
          'variables': {
            'login': username,
            'from': from.toUtc().toIso8601String(),
            'to': to.toUtc().toIso8601String(),
          },
        },
        options: Options(headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        }),
      );
      final data = response.data;
      if (data is! Map || data['data'] == null) return null;
      final userData = (data['data'] as Map)['user'] as Map?;
      if (userData == null) return null;
      final calendar = ((userData['contributionsCollection']
          as Map)['contributionCalendar'] as Map);
      final weeks = (calendar['weeks'] as List).map((w) => w as Map).toList();

      final Map<String, int> byDate = {};
      int total = 0;
      int max = 0;
      for (final week in weeks) {
        for (final day in (week['contributionDays'] as List)) {
          final d = day as Map;
          final count = (d['contributionCount'] as int?) ?? 0;
          final date = d['date'] as String? ?? '';
          if (date.isNotEmpty && count > 0) {
            byDate[date] = count;
            total += count;
            if (count > max) max = count;
          }
        }
      }
      return ContributionStatsData(
        year: from.year,
        contributionsByDate: byDate,
        totalContributions: total,
        maxContributions: max,
      );
    } catch (_) {
      return null;
    }
  }

  Future<ContributionStatsData?> _getContributionViaGraphQL(
      String username, int year) async {
    const query = r'''
query($login: String!, $from: DateTime!, $to: DateTime!) {
  user(login: $login) {
    contributionsCollection(from: $from, to: $to) {
      contributionCalendar {
        totalContributions
        weeks {
          contributionDays {
            contributionCount
            date
          }
        }
      }
    }
  }
}''';
    try {
      final response = await _dio.post<dynamic>(
        'https://api.github.com/graphql',
        data: {
          'query': query,
          'variables': {
            'login': username,
            'from': '$year-01-01T00:00:00Z',
            'to': '$year-12-31T23:59:59Z',
          },
        },
        options: Options(headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        }),
      );
      final data = response.data;
      if (data is! Map || data['data'] == null) return null;
      final userData = (data['data'] as Map)['user'] as Map?;
      if (userData == null) return null;
      final calendar = ((userData['contributionsCollection']
          as Map)['contributionCalendar'] as Map);
      final weeks = (calendar['weeks'] as List).map((w) => w as Map).toList();

      final Map<String, int> byDate = {};
      int total = 0;
      int max = 0;
      for (final week in weeks) {
        for (final day in (week['contributionDays'] as List)) {
          final d = day as Map;
          final count = (d['contributionCount'] as int?) ?? 0;
          final date = d['date'] as String? ?? '';
          if (date.isNotEmpty && count > 0) {
            byDate[date] = count;
            total += count;
            if (count > max) max = count;
          }
        }
      }
      return ContributionStatsData(
        year: year,
        contributionsByDate: byDate,
        totalContributions: total,
        maxContributions: max,
      );
    } catch (_) {
      return null;
    }
  }

  Future<ContributionStatsData?> _getContributionViaREST(
      String username, int year) async {
    final start = '$year-01-01';
    final end = '$year-12-31';
    final q = 'author:$username committer-date:$start..$end';
    final Map<String, int> byDate = {};
    int total = 0;

    // /search/commits is rate-limited at 30 req/min — cap pagination to 3
    // pages and bail on the first failure to avoid burning the budget.
    try {
      for (int page = 1; page <= 3; page++) {
        final resp = await _dio.get<dynamic>(
          '/search/commits',
          queryParameters: {
            'q': q,
            'sort': 'committer-date',
            'order': 'desc',
            'page': page,
            'per_page': 100,
          },
          options: Options(headers: {
            'Accept': 'application/vnd.github.cloak-preview+json',
          }),
        );
        final items = (resp.data['items'] as List?) ?? [];
        if (items.isEmpty) break;
        for (final item in items) {
          final date =
              ((item['commit'] as Map)['committer'] as Map)['date'] as String?;
          if (date != null) {
            final key = date.substring(0, 10);
            byDate[key] = (byDate[key] ?? 0) + 1;
            total++;
          }
        }
        if (items.length < 100) break;
      }
    } catch (_) {
      // best-effort
    }

    final max = byDate.values.isEmpty
        ? 0
        : byDate.values.reduce((a, b) => a > b ? a : b);
    return ContributionStatsData(
      year: year,
      contributionsByDate: byDate,
      totalContributions: total,
      maxContributions: max,
    );
  }

  // ── Token exchange (used only by AuthService) ──────────────────────────────────

  /// Exchange an OAuth authorization code for an access token.
  /// Uses a plain [Dio] instance (no base URL, no auth header).
  Future<ApiResponse<String>> exchangeCodeForToken(String code) async {
    final tempDio = Dio();
    try {
      final response = await tempDio.post<dynamic>(
        Constants.githubTokenUrl,
        data: {
          'client_id': Constants.githubClientId,
          'client_secret': Constants.githubClientSecret,
          'code': code,
          'redirect_uri': Constants.githubRedirectUri,
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'User-Agent': Constants.userAgent,
          },
        ),
      );

      final body = response.data;
      Map<String, dynamic> tokenData;
      if (body is String) {
        // Some servers return form-encoded strings
        final pairs = body.split('&');
        tokenData = {
          for (final p in pairs)
            p.split('=')[0]: Uri.decodeComponent(p.split('=')[1])
        };
      } else {
        tokenData = body as Map<String, dynamic>;
      }

      final token = tokenData['access_token'] as String?;
      if (token != null && token.isNotEmpty) {
        return ApiResponse.ok(token);
      }
      final errorDesc = tokenData['error_description'] as String? ?? '令牌交换失败';
      return ApiResponse.fail(errorDesc);
    } on DioException catch (e) {
      return ApiResponse.fail(e.message ?? '令牌交换网络错误');
    } finally {
      tempDio.close();
    }
  }
}

class _BoolCacheEntry {
  _BoolCacheEntry(this.value, this.fetchedAt);
  final bool value;
  final DateTime fetchedAt;
}
