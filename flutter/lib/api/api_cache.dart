import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// One cached API response: ETag + body + timestamp.
class CachedEntry {
  CachedEntry({
    required this.etag,
    required this.body,
    required this.fetchedAt,
  });

  /// ETag from `ETag` response header (may be null when GitHub doesn't send one).
  final String? etag;

  /// Decoded JSON body — `Map`, `List`, `String`, or primitives.
  final dynamic body;

  /// When this entry was last (re)validated.
  final DateTime fetchedAt;

  Map<String, dynamic> toJson() => {
        'etag': etag,
        'body': body,
        'fetchedAt': fetchedAt.millisecondsSinceEpoch,
      };

  static CachedEntry fromJson(Map<String, dynamic> json) => CachedEntry(
        etag: json['etag'] as String?,
        body: json['body'],
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(
            json['fetchedAt'] as int),
      );

  bool isFreshFor(Duration ttl) =>
      DateTime.now().difference(fetchedAt) < ttl;
}

/// Persistent ETag/body cache for GET responses.
///
/// Single Hive box keyed by `method + path + sortedParams` → JSON-encoded
/// [CachedEntry]. The box is also small enough (a few hundred KB at most for
/// typical browsing) that we keep entries indefinitely; eviction happens
/// implicitly when the cache exceeds [_softCap] entries (LRU-ish — oldest
/// fetchedAt wins).
class ApiCache {
  ApiCache._();
  static final ApiCache instance = ApiCache._();

  static const _boxName = 'cache_api_v1';
  static const _softCap = 500;

  Box<String>? _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    instance._box = await Hive.openBox<String>(_boxName);
    await instance._evictIfNeeded();
  }

  /// Build a stable cache key from method + path + sorted query params.
  static String keyFor(String method, String path,
      [Map<String, dynamic>? params]) {
    if (params == null || params.isEmpty) return '$method $path';
    final sorted = params.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final encoded =
        sorted.map((e) => '${e.key}=${e.value}').join('&');
    return '$method $path?$encoded';
  }

  CachedEntry? get(String key) {
    final box = _box;
    if (box == null) return null;
    final raw = box.get(key);
    if (raw == null) return null;
    try {
      return CachedEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      box.delete(key);
      return null;
    }
  }

  Future<void> put(String key, CachedEntry entry) async {
    final box = _box;
    if (box == null) return;
    await box.put(key, jsonEncode(entry.toJson()));
    await _evictIfNeeded();
  }

  /// Update only the timestamp on a 304 hit so the entry counts as fresh.
  Future<void> touch(String key) async {
    final entry = get(key);
    if (entry == null) return;
    await put(
        key,
        CachedEntry(
          etag: entry.etag,
          body: entry.body,
          fetchedAt: DateTime.now(),
        ));
  }

  Future<void> invalidate(String key) async {
    await _box?.delete(key);
  }

  /// Drop every cached entry whose key contains [substring].
  Future<void> invalidateMatching(String substring) async {
    final box = _box;
    if (box == null) return;
    final keys = box.keys
        .whereType<String>()
        .where((k) => k.contains(substring))
        .toList();
    for (final k in keys) {
      await box.delete(k);
    }
  }

  Future<void> clearAll() async {
    await _box?.clear();
  }

  int get entryCount => _box?.length ?? 0;

  String get formattedSize {
    final box = _box;
    if (box == null) return '0 B';
    int bytes = 0;
    for (final v in box.values) {
      bytes += v.length;
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '$bytes B';
  }

  Future<void> _evictIfNeeded() async {
    final box = _box;
    if (box == null) return;
    if (box.length <= _softCap) return;
    // Decode timestamps and drop the oldest 10%.
    final entries = <MapEntry<String, int>>[];
    for (final k in box.keys.whereType<String>()) {
      try {
        final parsed = jsonDecode(box.get(k)!) as Map<String, dynamic>;
        entries.add(MapEntry(k, parsed['fetchedAt'] as int));
      } catch (_) {
        await box.delete(k);
      }
    }
    entries.sort((a, b) => a.value.compareTo(b.value));
    final toDrop = (entries.length * 0.1).ceil().clamp(1, entries.length);
    for (var i = 0; i < toDrop; i++) {
      await box.delete(entries[i].key);
    }
  }
}
