import '../utils/api_error_message.dart';

/// Generic response wrapper mirroring the harmony APIResponse\<T\>
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final String? message;

  const ApiResponse({
    required this.success,
    this.data,
    this.error,
    this.message,
  });

  factory ApiResponse.ok(T data) => ApiResponse(success: true, data: data);

  factory ApiResponse.fail(String error, {String? message}) {
    final friendlyMessage = friendlyApiErrorMessage(
      message ?? error,
      fallback: '请求失败，请稍后重试',
    );
    return ApiResponse(
      success: false,
      error: error,
      message: friendlyMessage,
    );
  }

  bool get isSuccess => success && data != null;
}

/// Pagination metadata for list responses
class PaginationInfo {
  final int page;
  final int perPage;
  final int? totalCount;
  final bool hasNext;
  final bool hasPrev;

  const PaginationInfo({
    required this.page,
    required this.perPage,
    this.totalCount,
    this.hasNext = false,
    this.hasPrev = false,
  });
}
