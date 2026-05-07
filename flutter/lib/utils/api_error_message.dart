import 'package:dio/dio.dart';

String friendlyApiErrorMessage(
  String? message, {
  String fallback = '加载失败，请稍后重试',
}) {
  final raw = (message ?? '').trim();
  if (raw.isEmpty) return fallback;
  final lower = raw.toLowerCase();

  if (_containsAny(lower, [
    'connection took longer',
    'connecttimeout',
    'receivetimeout',
    'sendtimeout',
    'timeout',
    'timed out',
  ])) {
    return '网络连接超时，请检查网络后重试';
  }

  if (_containsAny(lower, [
    'socketexception',
    'connection refused',
    'network is unreachable',
    'failed host lookup',
    'connection reset',
    'network error',
  ])) {
    return '网络连接异常，请检查网络后重试';
  }

  if (_containsAny(lower, ['requestoptions', 'dioexception', 'exception:'])) {
    return fallback;
  }
  if (lower.startsWith('graphql error')) {
    return fallback;
  }

  if (lower.contains('bad credentials') || lower.contains('401')) {
    return '登录状态已失效，请重新登录';
  }
  if (lower.contains('rate limit') || lower.contains('403')) {
    return '请求过于频繁，请稍后再试';
  }
  if (lower.contains('not found') || lower.contains('404')) {
    return '内容不存在或已被删除';
  }
  if (lower.contains('500') || lower.contains('502') || lower.contains('503')) {
    return '服务暂时不可用，请稍后重试';
  }

  return raw.length > 80 ? fallback : raw;
}

String friendlyDioErrorMessage(
  DioException error, {
  String fallback = '网络请求失败，请稍后重试',
}) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return '网络连接超时，请检查网络后重试';
    case DioExceptionType.badCertificate:
    case DioExceptionType.connectionError:
      return '网络连接异常，请检查网络后重试';
    case DioExceptionType.cancel:
      return '请求已取消';
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      return friendlyApiErrorMessage(
        _responseErrorMessage(error) ?? error.message,
        fallback: fallback,
      );
  }
}

String? _responseErrorMessage(DioException error) {
  final data = error.response?.data;
  if (data is Map<String, dynamic>) {
    final msg = data['message'] as String? ?? data['error'] as String?;
    // GitHub 422 errors carry detail in the `errors` array
    final errors = data['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      final detail = first is Map
          ? (first['message'] as String? ?? first['field'] as String?)
          : null;
      if (detail != null && detail.isNotEmpty) {
        return detail;
      }
    }
    return msg;
  }
  return null;
}

bool _containsAny(String value, List<String> patterns) {
  for (final pattern in patterns) {
    if (value.contains(pattern)) return true;
  }
  return false;
}
