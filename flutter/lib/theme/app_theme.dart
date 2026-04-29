import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF0969DA);
  static const Color primaryDark = Color(0xFF1F6FEB);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        surface: const Color(0xFFF6F8FA),
        onSurface: const Color(0xFF24292F),
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
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryDark,
        brightness: Brightness.dark,
        primary: primaryDark,
        surface: const Color(0xFF161B22),
        onSurface: const Color(0xFFE6EDF3),
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
