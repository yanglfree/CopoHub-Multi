import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/theme_service.dart';

// ── ThemeService provider ─────────────────────────────────────────────────────

final themeServiceProvider = ChangeNotifierProvider<ThemeService>((ref) {
  return ThemeService.instance;
});

// ── Derived state providers ───────────────────────────────────────────────────

/// Flutter [ThemeMode] used by [MaterialApp].
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(themeServiceProvider).flutterThemeMode;
});

/// User-facing theme mode enum (auto / light / dark).
final themeMode2Provider = Provider<ThemeMode2>((ref) {
  return ref.watch(themeServiceProvider).themeMode;
});

/// Selected contribution chart color theme name.
final contributionThemeProvider = Provider<String>((ref) {
  return ref.watch(themeServiceProvider).contributionTheme;
});

/// Resolved contribution chart color list.
final contributionColorsProvider = Provider<List<String>>((ref) {
  return ref.watch(themeServiceProvider).getContributionThemeColors();
});
