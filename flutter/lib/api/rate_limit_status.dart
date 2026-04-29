import 'package:flutter/foundation.dart';

/// Snapshot of GitHub's `X-RateLimit-*` headers from the most recent response.
class RateLimitInfo {
  const RateLimitInfo({
    required this.limit,
    required this.remaining,
    required this.resetAt,
  });

  final int limit;
  final int remaining;
  final DateTime resetAt;

  bool get isNearLimit => limit > 0 && remaining < (limit * 0.1);
  Duration get untilReset => resetAt.difference(DateTime.now());
}

/// Globally observable rate-limit state. UI may listen and warn the user
/// when [RateLimitInfo.isNearLimit] becomes true.
class RateLimitStatus {
  RateLimitStatus._();
  static final RateLimitStatus instance = RateLimitStatus._();

  final ValueNotifier<RateLimitInfo?> notifier = ValueNotifier(null);

  void update(Map<String, dynamic> headers) {
    final limit = _intHeader(headers, 'x-ratelimit-limit');
    final remaining = _intHeader(headers, 'x-ratelimit-remaining');
    final reset = _intHeader(headers, 'x-ratelimit-reset');
    if (limit == null || remaining == null || reset == null) return;
    notifier.value = RateLimitInfo(
      limit: limit,
      remaining: remaining,
      resetAt: DateTime.fromMillisecondsSinceEpoch(reset * 1000),
    );
  }

  static int? _intHeader(Map<String, dynamic> headers, String key) {
    final raw = headers[key];
    if (raw == null) return null;
    final str = raw is List ? (raw.isEmpty ? null : raw.first.toString()) : raw.toString();
    if (str == null) return null;
    return int.tryParse(str);
  }
}
