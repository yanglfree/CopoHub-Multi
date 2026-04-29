/// Dart port of HarmonyOS SensitiveContentFilter.ets
///
/// Pure-logic sensitive-word checker for search queries and repository
/// metadata. Words are hardcoded (no file system dependency on Flutter).
class SensitiveContentFilter {
  SensitiveContentFilter._();

  static final SensitiveContentFilter instance =
      SensitiveContentFilter._();

  // Lightweight built-in list.  Extend as needed.
  static const List<String> _words = [];

  final List<String> _asciiWords = [];
  final List<String> _nonAsciiWords = [];

  bool _loaded = false;

  void _ensureLoaded() {
    if (_loaded) return;
    for (final w in _words) {
      if (_isAscii(w)) {
        _asciiWords.add(w.toLowerCase());
      } else {
        _nonAsciiWords.add(w.toLowerCase());
      }
    }
    _loaded = true;
  }

  static bool _isAscii(String s) =>
      s.codeUnits.every((c) => c < 128);

  /// Returns `true` when [text] contains a sensitive word.
  bool hasSensitiveContent(String? text) =>
      findSensitiveWord(text).isNotEmpty;

  /// Returns the first matched sensitive word, or empty string if none.
  String findSensitiveWord(String? text) {
    if (text == null || text.trim().isEmpty) return '';
    _ensureLoaded();
    if (_asciiWords.isEmpty && _nonAsciiWords.isEmpty) return '';

    final lower = text.toLowerCase();
    final compact = lower.replaceAll(RegExp(r'\s+'), '');

    for (final w in _nonAsciiWords) {
      if (compact.contains(w)) return w;
    }
    for (final w in _asciiWords) {
      if (lower.contains(w) || compact.contains(w)) return w;
    }
    return '';
  }

  /// Sanitises [query] by removing leading/trailing spaces and checking for
  /// sensitive content.  Returns `null` when the query should be blocked.
  String? sanitiseQuery(String? query) {
    if (query == null || query.trim().isEmpty) return null;
    final trimmed = query.trim();
    if (hasSensitiveContent(trimmed)) return null;
    return trimmed;
  }
}
