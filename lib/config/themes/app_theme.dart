import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App-wide theme configuration (colors, fonts, styles) for Kiosk.
class AppTheme {
  AppTheme._();

  // Primary palette
  static const Color primaryColor = Color(0xFF007AFF);
  static const Color primaryVariantColor = Color(0xFF0056B3);
  static const Color secondaryColor = Color(0xFF34C759);
  
  // Light Theme background/surface
  static const Color backgroundColor = Color(0xFFF2F2F7);
  static const Color surfaceColor = Colors.white;
  static const Color errorColor = Color(0xFFFF3B30);

  // Text colors
  static const Color textPrimaryColor = Color(0xFF1C1C1E);
  static const Color textSecondaryColor = Color(0xFF8E8E93);

  /// Light theme definition
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: errorColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      textTheme: GoogleFonts.outfitTextTheme(
        const TextTheme(
          displayLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: textPrimaryColor),
          headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: textPrimaryColor),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: textPrimaryColor),
          bodyLarge: TextStyle(fontSize: 18, color: textPrimaryColor),
          bodyMedium: TextStyle(fontSize: 16, color: textSecondaryColor),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
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
        surface: Color(0xFF1C1C1E),
        error: errorColor,
      ),
      scaffoldBackgroundColor: const Color(0xFF000000),
      textTheme: GoogleFonts.outfitTextTheme(
        const TextTheme(
          displayLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
          headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Colors.white),
          bodyLarge: TextStyle(fontSize: 18, color: Colors.white70),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.white54),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1C1C1E),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
