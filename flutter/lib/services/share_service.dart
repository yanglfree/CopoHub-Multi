import 'dart:ui';
import 'package:share_plus/share_plus.dart';

/// Cross-platform share integration using share_plus.
///
/// Mirrors HarmonyOS `ShareService.ets`.
class ShareService {
  const ShareService._();

  // ── Repository ─────────────────────────────────────────────────────────────

  /// Shares a GitHub repository — shows the native OS share sheet.
  static Future<void> shareRepository({
    required String owner,
    required String repo,
    String? description,
    int stars = 0,
    String? language,
    Rect? sharePositionOrigin,
  }) async {
    final url = 'https://github.com/$owner/$repo';
    final sb = StringBuffer();
    sb.write('$owner/$repo');
    if (description != null && description.isNotEmpty) {
      sb.write('\n$description');
    }
    if (language != null && language.isNotEmpty) {
      sb.write(' · $language');
    }
    if (stars > 0) sb.write(' · ⭐ $stars');
    sb.write('\n$url');
    await Share.share(
      sb.toString(),
      subject: '$owner/$repo on GitHub',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  // ── User profile ────────────────────────────────────────────────────────────

  /// Shares a GitHub user profile.
  static Future<void> shareProfile({
    required String username,
    String? bio,
    Rect? sharePositionOrigin,
  }) async {
    final url = 'https://github.com/$username';
    final sb = StringBuffer();
    sb.write('@$username');
    if (bio != null && bio.isNotEmpty) sb.write(' — $bio');
    sb.write('\n$url');
    await Share.share(
      sb.toString(),
      subject: '@$username on GitHub',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  // ── Generic ─────────────────────────────────────────────────────────────────

  /// Shares arbitrary text.
  static Future<void> shareText(
    String text, {
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    await Share.share(
      text,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}
