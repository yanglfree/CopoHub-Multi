import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF0969DA);
  static const Color primaryDark = Color(0xFF1F6FEB);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        // ── Primary (GitHub blue) ───────────────────────────────────────────
        primary: Color(0xFF0969DA),
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFDDEEFF),
        onPrimaryContainer: Color(0xFF0550AE),
        // ── Secondary (muted text) ──────────────────────────────────────────
        secondary: Color(0xFF57606A),
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFEAEEF2),
        onSecondaryContainer: Color(0xFF24292F),
        // ── Tertiary (success green) ────────────────────────────────────────
        tertiary: Color(0xFF1A7F37),
        onTertiary: Colors.white,
        tertiaryContainer: Color(0xFFDCFCE7),
        onTertiaryContainer: Color(0xFF1A7F37),
        // ── Error (red) ─────────────────────────────────────────────────────
        error: Color(0xFFCF222E),
        onError: Colors.white,
        errorContainer: Color(0xFFFFEBE9),
        onErrorContainer: Color(0xFF82071E),
        // ── Surfaces ────────────────────────────────────────────────────────
        surface: Color(0xFFF6F8FA),
        onSurface: Color(0xFF24292F),
        onSurfaceVariant: Color(0xFF57606A),
        // Surface container hierarchy (light → dark)
        surfaceContainerLowest: Color(0xFFFFFFFF),
        surfaceContainerLow: Color(0xFFF6F8FA),
        surfaceContainer: Color(0xFFEAEEF2),
        surfaceContainerHigh: Color(0xFFDDE1E6),
        surfaceContainerHighest: Color(0xFFD0D7DE),
        // ── Outline / border ────────────────────────────────────────────────
        outline: Color(0xFFD0D7DE),
        outlineVariant: Color(0xFFEAEEF2),
        // ── Inverse ─────────────────────────────────────────────────────────
        inverseSurface: Color(0xFF24292F),
        onInverseSurface: Color(0xFFF6F8FA),
        inversePrimary: Color(0xFF1F6FEB),
        // ── Misc ────────────────────────────────────────────────────────────
        shadow: Color(0xFF1F2328),
        scrim: Color(0xFF1F2328),
        surfaceTint: Color(0xFF0969DA),
      ),
      scaffoldBackgroundColor: const Color(0xFFF6F8FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF24292F),
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: _cardTheme(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFD0D7DE), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFD0D7DE),
        thickness: 1,
        space: 0,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      textTheme: _textTheme(Brightness.light),
      fontFamily: 'SF Pro Text',
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      // Use an explicit color scheme instead of fromSeed so every surface
      // container variant is a known GitHub-dark color, not an algorithm guess.
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        // ── Primary (GitHub blue) ───────────────────────────────────────────
        primary: Color(0xFF1F6FEB),
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF0C2556),
        onPrimaryContainer: Color(0xFF79AAFF),
        // ── Secondary (muted text) ──────────────────────────────────────────
        secondary: Color(0xFF7D8590),
        onSecondary: Color(0xFFE6EDF3),
        secondaryContainer: Color(0xFF21262D),
        onSecondaryContainer: Color(0xFFE6EDF3),
        // ── Tertiary (success green) ────────────────────────────────────────
        tertiary: Color(0xFF3FB950),
        onTertiary: Colors.black,
        tertiaryContainer: Color(0xFF1A3D22),
        onTertiaryContainer: Color(0xFF3FB950),
        // ── Error (red) ─────────────────────────────────────────────────────
        error: Color(0xFFF85149),
        onError: Colors.black,
        errorContainer: Color(0xFF3D0C0B),
        onErrorContainer: Color(0xFFF85149),
        // ── Surfaces ────────────────────────────────────────────────────────
        surface: Color(0xFF161B22),
        onSurface: Color(0xFFE6EDF3),
        onSurfaceVariant: Color(0xFF7D8590),
        // Surface container hierarchy (dark → light)
        surfaceContainerLowest: Color(0xFF0D1117),
        surfaceContainerLow: Color(0xFF13181E),
        surfaceContainer: Color(0xFF161B22),
        surfaceContainerHigh: Color(0xFF1C2128),
        surfaceContainerHighest: Color(0xFF21262D),
        // ── Outline / border ────────────────────────────────────────────────
        outline: Color(0xFF30363D),
        outlineVariant: Color(0xFF21262D),
        // ── Inverse ─────────────────────────────────────────────────────────
        inverseSurface: Color(0xFFE6EDF3),
        onInverseSurface: Color(0xFF0D1117),
        inversePrimary: Color(0xFF0969DA),
        // ── Misc ────────────────────────────────────────────────────────────
        shadow: Colors.black,
        scrim: Colors.black,
        surfaceTint: Color(0xFF1F6FEB),
      ),
      scaffoldBackgroundColor: const Color(0xFF0D1117),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF161B22),
        foregroundColor: Color(0xFFE6EDF3),
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: _cardTheme(
        color: const Color(0xFF161B22),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF30363D), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF30363D),
        thickness: 1,
        space: 0,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      textTheme: _textTheme(Brightness.dark),
      fontFamily: 'SF Pro Text',
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final Color primary = brightness == Brightness.light
        ? const Color(0xFF24292F)
        : const Color(0xFFE6EDF3);
    final Color secondary = brightness == Brightness.light
        ? const Color(0xFF57606A)
        : const Color(0xFF7D8590);

    return TextTheme(
      titleLarge:
          TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: primary),
      titleMedium:
          TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
      titleSmall:
          TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      bodyLarge:
          TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: primary),
      bodyMedium:
          TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: primary),
      bodySmall: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w400, color: secondary),
      labelSmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w500, color: secondary),
    );
  }

  static dynamic _cardTheme({
    required Color color,
    required double elevation,
    required ShapeBorder shape,
    required EdgeInsetsGeometry margin,
  }) {
    final dynamic theme = CardTheme(
      color: color,
      elevation: elevation,
      shape: shape,
      margin: margin,
    );

    // Flutter 3.32 changed ThemeData.cardTheme from CardTheme to CardThemeData.
    return theme is InheritedWidget ? (theme as dynamic).data : theme;
  }
}
