import 'package:flutter/material.dart';

/// Frost-Tech brand colour palette for IceBot Kiosk.
///
/// Do NOT reference these directly inside widgets — use [ColorScheme] from
/// the ambient [Theme] instead. These constants exist solely so [AppTheme]
/// can build the [ColorScheme] and so tests can reference canonical values.
class IceBotColors {
  IceBotColors._();

  // ── Primary ─────────────────────────────────────────────────────────────
  /// Frost blue — primary interactive colour, CTAs, active step indicators.
  static const icePrimary = Color(0xFF1E9BFF);

  /// Slightly darker blue for pressed / hover states on primary.
  static const icePrimaryDark = Color(0xFF0A82E6);

  /// Soft pale-blue container behind primary elements.
  static const icePrimaryContainer = Color(0xFFD6ECFF);

  /// Text / icons drawn on top of [icePrimaryContainer].
  static const onIcePrimaryContainer = Color(0xFF003D6B);

  // ── Dark / Navy ──────────────────────────────────────────────────────────
  /// Bot Navy — used for dark text, headers, scaffold chrome.
  static const botNavy = Color(0xFF102033);

  /// Muted navy for secondary body text.
  static const botNavyMuted = Color(0xFF4A6278);

  // ── Surfaces ─────────────────────────────────────────────────────────────
  /// Frost surface — scaffold / page background.
  static const frostSurface = Color(0xFFF4FAFF);

  /// Snow card — card, panel, and dialog backgrounds.
  static const snowCard = Color(0xFFFFFFFF);

  /// Frost border — subtle dividers and card outlines.
  static const frostBorder = Color(0xFFD0E5F5);

  // ── Accent ────────────────────────────────────────────────────────────────
  /// Sorbet accent — secondary / destructive highlight.
  static const sorbetAccent = Color(0xFFFF7A59);

  /// Container behind sorbet elements.
  static const sorbetContainer = Color(0xFFFFE8E2);

  // ── Success ───────────────────────────────────────────────────────────────
  /// Mint success — confirmations, paid status, completion.
  static const mintSuccess = Color(0xFF2BCB8A);

  /// Container behind success elements.
  static const mintSuccessContainer = Color(0xFFD4F5E9);

  // ── Warning ───────────────────────────────────────────────────────────────
  /// Amber warning — expiry, timeout, staff-support states.
  static const warningAmber = Color(0xFFEFA42A);

  /// Container behind warning elements.
  static const warningContainer = Color(0xFFFFF0D0);

  // ── Error ─────────────────────────────────────────────────────────────────
  /// Danger red — payment failed, execution errors.
  static const dangerRed = Color(0xFFE53E3E);

  /// Container behind error elements.
  static const dangerContainer = Color(0xFFFFE5E5);

  /// Text / icons on top of [dangerContainer].
  static const onDangerContainer = Color(0xFF7A1010);
}
