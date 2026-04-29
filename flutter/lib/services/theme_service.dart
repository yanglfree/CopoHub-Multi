import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

enum ThemeMode2 {
  auto,   // follow system
  light,
  dark,
}

/// Flutter equivalent of the HarmonyOS ThemeService.
///
/// Uses [ChangeNotifier] so Riverpod can watch it.
class ThemeService extends ChangeNotifier {
  static ThemeService? _instance;
  static ThemeService get instance => _instance ??= ThemeService._();

  ThemeService._() {
    _loadTheme();
  }

  ThemeMode2 _themeMode = ThemeMode2.auto;
  String _contributionTheme = 'Purple';

  ThemeMode2 get themeMode => _themeMode;
  String get contributionTheme => _contributionTheme;

  /// Converts our enum to Flutter's [ThemeMode] for MaterialApp.
  ThemeMode get flutterThemeMode => switch (_themeMode) {
        ThemeMode2.auto => ThemeMode.system,
        ThemeMode2.light => ThemeMode.light,
        ThemeMode2.dark => ThemeMode.dark,
      };

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(Constants.storageThemeMode);
      if (saved != null) {
        _themeMode = ThemeMode2.values.firstWhere(
          (e) => e.name == saved,
          orElse: () => ThemeMode2.auto,
        );
      }
      _contributionTheme = prefs.getString(Constants.storageContributionTheme) ??
          Constants.contributionThemes.first.name;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode2 mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Constants.storageThemeMode, mode.name);
  }

  Future<void> setContributionTheme(String themeName) async {
    _contributionTheme = themeName;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Constants.storageContributionTheme, themeName);
  }

  List<String> getContributionThemeColors() =>
      Constants.getContributionThemeColors(_contributionTheme);
}
