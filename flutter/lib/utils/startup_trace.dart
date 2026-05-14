import 'package:flutter/widgets.dart';

class StartupTrace {
  static final Stopwatch _stopwatch = Stopwatch()..start();
  static final Set<String> _seenKeys = <String>{};
  static final List<String> _history = <String>[];
  static const int _maxHistoryCount = 120;

  static void log(String event, [Object? details]) {
    final suffix = details == null ? '' : ' $details';
    final line =
        '[CopoHubStartup][+${_stopwatch.elapsedMilliseconds}ms] $event$suffix';
    _appendHistory(line);
    debugPrint(line);
  }

  static void logError(String event, Object error, [StackTrace? stackTrace]) {
    log(event, 'error=$error');
    if (stackTrace != null) {
      debugPrint('[CopoHubStartup] $stackTrace');
    }
  }

  static void logOnce(String key, String event, [Object? details]) {
    if (!_seenKeys.add(key)) {
      return;
    }
    log(event, details);
  }

  static void dumpHistory(String reason) {
    debugPrint(
        '[CopoHubStartup][dump][$reason] begin count=${_history.length}');
    for (final line in _history) {
      debugPrint('[CopoHubStartup][dump][$reason] $line');
    }
    debugPrint('[CopoHubStartup][dump][$reason] end');
  }

  static String windowSummary() {
    // Flutter-OH in this project tracks an older Flutter API surface, so keep
    // the legacy window accessor instead of newer FlutterView APIs.
    // ignore: deprecated_member_use
    final w = WidgetsBinding.instance.window;
    final p = w.padding;
    final v = w.viewInsets;
    return 'physicalSize=${w.physicalSize.width.toStringAsFixed(0)}x${w.physicalSize.height.toStringAsFixed(0)} '
        'dpr=${w.devicePixelRatio.toStringAsFixed(2)} '
        'padding=T${p.top.toStringAsFixed(0)},B${p.bottom.toStringAsFixed(0)},L${p.left.toStringAsFixed(0)},R${p.right.toStringAsFixed(0)} '
        'viewInsets=T${v.top.toStringAsFixed(0)},B${v.bottom.toStringAsFixed(0)}';
  }

  static void _appendHistory(String line) {
    _history.add(line);
    if (_history.length > _maxHistoryCount) {
      _history.removeAt(0);
    }
  }
}
