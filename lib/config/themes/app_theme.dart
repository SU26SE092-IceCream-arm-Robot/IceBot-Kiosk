import 'package:flutter/material.dart';
import 'package:icebot_kiosk/config/themes/icebot_colors.dart';
import 'package:icebot_kiosk/config/themes/icebot_spacing.dart';

/// App-wide theme configuration — Frost-Tech Kiosk direction.
///
/// Typography uses system fonts (no external packages required in this phase).
/// Display headings: bold system sans-serif.
/// Body: standard system sans-serif with adjusted weight and line-height.
///
/// Fonts can be upgraded to Saira Semi Condensed + Be Vietnam Pro in a later
/// phase once bundled as local assets.
class AppTheme {
  AppTheme._();

  // ── Light theme ───────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // ColorScheme ──────────────────────────────────────────────────────────
      colorScheme: const ColorScheme.light(
        primary: IceBotColors.icePrimary,
        onPrimary: Colors.white,
        primaryContainer: IceBotColors.icePrimaryContainer,
        onPrimaryContainer: IceBotColors.onIcePrimaryContainer,
        secondary: IceBotColors.sorbetAccent,
        onSecondary: Colors.white,
        secondaryContainer: IceBotColors.sorbetContainer,
        onSecondaryContainer: Color(0xFF8B2500),
        tertiary: IceBotColors.mintSuccess,
        onTertiary: Colors.white,
        tertiaryContainer: IceBotColors.mintSuccessContainer,
        onTertiaryContainer: Color(0xFF005235),
        error: IceBotColors.dangerRed,
        onError: Colors.white,
        errorContainer: IceBotColors.dangerContainer,
        onErrorContainer: IceBotColors.onDangerContainer,
        surface: IceBotColors.snowCard,
        onSurface: IceBotColors.botNavy,
        surfaceContainerHighest: IceBotColors.frostSurface,
        onSurfaceVariant: IceBotColors.botNavyMuted,
        outline: IceBotColors.frostBorder,
        outlineVariant: Color(0xFFE8F2FB),
        scrim: Color(0xFF102033),
      ),

      // Scaffold ─────────────────────────────────────────────────────────────
      scaffoldBackgroundColor: IceBotColors.frostSurface,

      // Typography ───────────────────────────────────────────────────────────
      // System fonts only in Phase UI-1. Display styles use tighter letter-
      // spacing to approximate the condensed-display feel of Saira.
      textTheme: const TextTheme(
        // Display — large screen titles, splash, attract
        displayLarge: TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w800,
          height: 1.05,
          letterSpacing: -0.5,
          color: IceBotColors.botNavy,
        ),
        // Display — section headers, payment amount
        displayMedium: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          height: 1.10,
          letterSpacing: -0.3,
          color: IceBotColors.botNavy,
        ),
        // Headline — card titles, product names
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          height: 1.20,
          letterSpacing: -0.2,
          color: IceBotColors.botNavy,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.25,
          color: IceBotColors.botNavy,
        ),
        // Title — subtitles, button labels, secondary headings
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.30,
          color: IceBotColors.botNavyMuted,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.35,
          color: IceBotColors.botNavy,
        ),
        // Body
        bodyLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          height: 1.45,
          color: IceBotColors.botNavy,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.40,
          color: IceBotColors.botNavyMuted,
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.40,
          color: IceBotColors.botNavyMuted,
        ),
        // Label — info pills, badges, step rail labels
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.25,
          letterSpacing: 0.1,
          color: IceBotColors.botNavy,
        ),
        labelMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.25,
          color: IceBotColors.botNavyMuted,
        ),
        labelSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.25,
          letterSpacing: 0.4,
          color: IceBotColors.botNavyMuted,
        ),
      ),

      // AppBar ───────────────────────────────────────────────────────────────
      // The custom IceBotScaffold (Phase UI-2+) will replace AppBar.
      // These settings keep the existing screens looking reasonable until then.
      appBarTheme: const AppBarTheme(
        backgroundColor: IceBotColors.frostSurface,
        foregroundColor: IceBotColors.botNavy,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        toolbarHeight: 68,
        titleSpacing: 20,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: IceBotColors.botNavy,
        ),
        iconTheme: IconThemeData(color: IceBotColors.botNavy, size: 28),
      ),

      // FilledButton — IcePrimaryButton style applied globally ────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: IceBotColors.icePrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Color(0xFFB0D4F1),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size(180, IceBotSpacing.primaryCTAHeight),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(IceBotSpacing.buttonRadius),
            ),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        ),
      ),

      // OutlinedButton — IceSecondaryButton style ────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: IceBotColors.icePrimary,
          side: const BorderSide(color: IceBotColors.icePrimary, width: 1.8),
          minimumSize: const Size(180, IceBotSpacing.secondaryCTAHeight),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(IceBotSpacing.buttonRadius),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        ),
      ),

      // TextButton ───────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: IceBotColors.icePrimary,
          minimumSize: const Size(64, IceBotSpacing.minTouchTarget),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),

      // IconButton ───────────────────────────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            IceBotSpacing.minTouchTarget,
            IceBotSpacing.minTouchTarget,
          ),
          iconSize: 28,
          foregroundColor: IceBotColors.botNavy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(IceBotSpacing.innerRadius),
            ),
          ),
        ),
      ),

      // Card ─────────────────────────────────────────────────────────────────
      cardTheme: const CardThemeData(
        color: IceBotColors.snowCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(IceBotSpacing.cardRadius),
          ),
          side: BorderSide(color: IceBotColors.frostBorder),
        ),
      ),

      // Divider ──────────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: IceBotColors.frostBorder,
        thickness: 1,
        space: 28,
      ),

      // ProgressIndicator ────────────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: IceBotColors.icePrimary,
        linearTrackColor: IceBotColors.icePrimaryContainer,
        circularTrackColor: IceBotColors.icePrimaryContainer,
      ),

      // SnackBar ─────────────────────────────────────────────────────────────
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: IceBotColors.botNavy,
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),

      // Badge ────────────────────────────────────────────────────────────────
      badgeTheme: const BadgeThemeData(
        backgroundColor: IceBotColors.sorbetAccent,
        textColor: Colors.white,
        textStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ── Dark theme (minimal — kiosk runs light only) ───────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: IceBotColors.icePrimary,
        onPrimary: Colors.white,
        secondary: IceBotColors.sorbetAccent,
        onSecondary: Colors.white,
        tertiary: IceBotColors.mintSuccess,
        error: IceBotColors.dangerRed,
        surface: Color(0xFF1A2535),
        onSurface: Colors.white,
        outline: Color(0xFF2E4057),
      ),
      scaffoldBackgroundColor: const Color(0xFF0D1B2A),
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
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        titleLarge: TextStyle(fontSize: 20, color: Colors.white70),
        bodyLarge: TextStyle(fontSize: 18, color: Colors.white70),
        bodyMedium: TextStyle(fontSize: 16, color: Colors.white54),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A2535),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
