import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/dialogs/app_dialog.dart';
import 'app_info_service.dart';
import '../utils/constants.dart';

/// App update metadata returned by the update check.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.releaseNotes,
    required this.downloadUrl,
  });
  final String latestVersion;
  final String currentVersion;
  final String releaseNotes;
  final String downloadUrl;

  bool get hasUpdate => latestVersion != currentVersion;
}

/// Checks for available app updates and shows a dialog when one is found.
///
/// Calls `${copoHubBaseUrl}/api/v1/app/latest-version` — expected shape:
/// ```json
/// {
///   "version": "1.1.0",
///   "releaseNotes": "Bug fixes and improvements",
///   "downloadUrl": "https://example.com/download"
/// }
/// ```
/// Mirrors the update-check flow in HarmonyOS `check_app_update` module.
class AppUpdateService {
  AppUpdateService._()
      : _dio = Dio(BaseOptions(
          baseUrl: Constants.copoHubBaseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {'Accept': 'application/json'},
        ));

  static final instance = AppUpdateService._();
  final Dio _dio;

  /// Fetches latest version from the server.
  /// Returns update info when a newer version is available, otherwise null.
  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final currentVersion = await AppInfoService.instance.version;
      final response = await _dio.get<dynamic>('/api/v1/app/latest-version');
      final body = response.data as Map<String, dynamic>?;
      if (body == null) return null;

      final latest = body['version'] as String? ?? '';
      if (latest.isEmpty || latest == currentVersion) return null;

      return AppUpdateInfo(
        latestVersion: latest,
        currentVersion: currentVersion,
        releaseNotes: body['releaseNotes'] as String? ?? '',
        downloadUrl: body['downloadUrl'] as String? ?? '',
      );
    } catch (_) {
      // Network errors are silently ignored — update checks are best-effort.
      return null;
    }
  }

  /// Calls [checkForUpdate] and shows a dialog if an update is available.
  Future<void> checkAndShowDialogIfNeeded(BuildContext context) async {
    final info = await checkForUpdate();
    if (info == null || !info.hasUpdate) return;
    if (!context.mounted) return;
    _showUpdateDialog(context, info);
  }

  void _showUpdateDialog(BuildContext context, AppUpdateInfo info) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AppDialog(
        title: '发现新版本',
        icon: Icons.system_update_alt_outlined,
        actions: [
          AppDialogAction(
            label: '稍后',
            onPressed: () => Navigator.pop(dialogContext),
          ),
          AppDialogAction(
            label: '立即更新',
            isPrimary: true,
            onPressed: () async {
              Navigator.pop(dialogContext);
              final uri = Uri.tryParse(info.downloadUrl);
              if (uri != null) await launchUrl(uri);
            },
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前版本：${info.currentVersion}'),
            Text('最新版本：${info.latestVersion}'),
            if (info.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(info.releaseNotes, style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}
