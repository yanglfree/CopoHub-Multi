import 'package:flutter/services.dart';

import '../utils/constants.dart';

class AppInfo {
  const AppInfo({
    required this.name,
    required this.version,
    required this.buildNumber,
  });

  final String name;
  final String version;
  final String buildNumber;

  String get fullVersion =>
      buildNumber.isEmpty ? version : '$version+$buildNumber';
}

class AppInfoService {
  AppInfoService._();

  static final instance = AppInfoService._();

  Future<AppInfo>? _cached;

  Future<AppInfo> get info => _cached ??= _load();

  Future<String> get version async => (await info).version;

  Future<String> get fullVersion async => (await info).fullVersion;

  Future<String> get userAgent async {
    final current = await info;
    return Constants.buildUserAgent(current.version);
  }

  Future<AppInfo> _load() async {
    try {
      final content = await rootBundle.loadString('pubspec.yaml');
      final (version, buildNumber) = _readVersion(content);
      return AppInfo(
        name: _readScalar(content, 'name') ?? Constants.appName,
        version: version,
        buildNumber: buildNumber,
      );
    } catch (_) {
      return const AppInfo(
        name: Constants.appName,
        version: Constants.fallbackAppVersion,
        buildNumber: '',
      );
    }
  }

  (String, String) _readVersion(String content) {
    final raw = _readScalar(content, 'version');
    if (raw == null || raw.isEmpty) {
      return (Constants.fallbackAppVersion, '');
    }
    final parts = raw.split('+');
    return (parts.first, parts.length > 1 ? parts.sublist(1).join('+') : '');
  }

  String? _readScalar(String content, String key) {
    final match =
        RegExp('^$key:\\s*([^#\\n]+)', multiLine: true).firstMatch(content);
    return match?.group(1)?.trim().replaceAll(RegExp(r'''^['"]|['"]$'''), '');
  }
}
