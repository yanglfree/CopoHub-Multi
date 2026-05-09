import 'package:flutter/services.dart';

/// Result of a clipboard detection attempt.
class ClipboardDetectionResult {
  const ClipboardDetectionResult({required this.owner, required this.repo});
  final String owner;
  final String repo;

  String get fullName => '$owner/$repo';
}

/// Parses GitHub repository URLs from arbitrary text and de-duplicates results.
///
/// Supported formats:
///   https://github.com/owner/repo
///   https://github.com/owner/repo.git
///   https://github.com/owner/repo/
///   git@github.com:owner/repo.git
///
/// Mirrors HarmonyOS `ClipboardDetector.ts`.
class ClipboardDetectorService {
  ClipboardDetectorService._();
  static final instance = ClipboardDetectorService._();

  String _lastDetectedUrl = '';

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Reads clipboard, parses a GitHub repo URL, de-duplicates.
  /// Returns `null` when clipboard is empty, non-GitHub, duplicate, or invalid.
  Future<ClipboardDetectionResult?> detect() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) return null;

      // De-duplicate: same URL won't trigger twice in a row
      if (text == _lastDetectedUrl) return null;

      final result = _parseGithubUrl(text);
      if (result == null) return null;

      _lastDetectedUrl = text;
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Clears the de-duplication state so the next `detect()` re-triggers.
  void resetDuplicateCheck() => _lastDetectedUrl = '';

  /// Clears the clipboard contents.
  Future<void> clearClipboard() async {
    try {
      await Clipboard.setData(const ClipboardData(text: ''));
    } catch (_) {}
  }

  // ── URL parsing ────────────────────────────────────────────────────────────

  static ClipboardDetectionResult? _parseGithubUrl(String text) {
    // HTTPS: https://github.com/owner/repo[.git][/path][?query][#fragment]
    // Supports www.github.com and matches anywhere in the string.
    final httpsRe = RegExp(
        r'https?://(?:www\.)?github\.com/([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+?)(?:\.git)?(?:[/?#].*)?(?:\s|$)');
    final httpsMatch = httpsRe.firstMatch(text);
    if (httpsMatch != null) {
      return _validated(httpsMatch.group(1)!, httpsMatch.group(2)!);
    }

    // SSH: git@github.com:owner/repo[.git]
    final sshRe = RegExp(
        r'git@github\.com:([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+?)(?:\.git)?(?:\s|$)');
    final sshMatch = sshRe.firstMatch(text);
    if (sshMatch != null) {
      return _validated(sshMatch.group(1)!, sshMatch.group(2)!);
    }

    return null;
  }

  static ClipboardDetectionResult? _validated(String owner, String repo) {
    // Basic sanity: no empty, no dots-only names
    if (owner.isEmpty || repo.isEmpty) return null;
    if (owner == '.' || owner == '..') return null;
    if (repo == '.' || repo == '..') return null;
    return ClipboardDetectionResult(owner: owner, repo: repo);
  }
}
