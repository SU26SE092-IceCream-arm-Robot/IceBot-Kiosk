import 'package:flutter/material.dart';

/// App-wide theme configuration (colors, fonts, styles).
class AppTheme {
  AppTheme._();

  static const Color primaryColor = Color(0xFF04756F);
  static const Color primaryContainerColor = Color(0xFFD7F7EF);
  static const Color secondaryColor = Color(0xFFE7A23A);
  static const Color backgroundColor = Color(0xFFF6F8F4);
  static const Color surfaceColor = Colors.white;
  static const Color surfaceTintColor = Color(0xFFF0FAF7);
  static const Color errorColor = Color(0xFFB3261E);
  static const Color textPrimaryColor = Color(0xFF17211F);
  static const Color textSecondaryColor = Color(0xFF53615D);
  static const Color outlineColor = Color(0xFFD8E3DF);

  /// Light theme definition
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        onPrimary: Colors.white,
        primaryContainer: primaryContainerColor,
        onPrimaryContainer: Color(0xFF073F3B),
        secondary: secondaryColor,
        onSecondary: textPrimaryColor,
        secondaryContainer: Color(0xFFFFE9BD),
        onSecondaryContainer: Color(0xFF5D3700),
        surface: surfaceColor,
        onSurface: textPrimaryColor,
        error: errorColor,
        errorContainer: Color(0xFFFFE5E1),
        onErrorContainer: Color(0xFF7A1B14),
        outline: outlineColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      dividerTheme: const DividerThemeData(
        color: outlineColor,
        thickness: 1,
        space: 30,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 46,
          fontWeight: FontWeight.w800,
          height: 1.05,
          color: textPrimaryColor,
        ),
        displayMedium: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          height: 1.12,
          color: textPrimaryColor,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          height: 1.16,
          color: textPrimaryColor,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.32,
          color: textSecondaryColor,
        ),
        bodyLarge: TextStyle(
          fontSize: 18,
          height: 1.42,
          color: textPrimaryColor,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          height: 1.38,
          color: textSecondaryColor,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimaryColor,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 78,
        titleSpacing: 24,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: textPrimaryColor,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(204, 68),
          textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: outlineColor, width: 1.4),
          minimumSize: const Size(204, 68),
          textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(56, 56),
          iconSize: 30,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        surfaceTintColor: surfaceTintColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: outlineColor),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: Color(0xFFE0ECE8),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimaryColor,
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Dark theme definition
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: Color(0xFF1E1E1E),
        error: errorColor,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        displayMedium: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        titleLarge: TextStyle(fontSize: 22, color: Colors.white70),
        bodyLarge: TextStyle(fontSize: 18, color: Colors.white70),
        bodyMedium: TextStyle(fontSize: 16, color: Colors.white54),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
