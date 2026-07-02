/// Spacing, radius, elevation, and kiosk touch-target tokens for IceBot Kiosk.
///
/// These are static constants intentionally kept as plain [double] values so
/// they can be used in both layout code and [BoxDecoration] without importing
/// Flutter's full widget library here.
class IceBotSpacing {
  IceBotSpacing._();

  // ── Base spacing scale ────────────────────────────────────────────────────
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;

  // ── Section / screen padding ──────────────────────────────────────────────
  /// Horizontal + vertical padding applied to each screen body.
  static const double screenPaddingCompact = 18.0;
  static const double screenPaddingNormal = 28.0;
  static const double screenPaddingWide = 36.0;

  /// Vertical gap between major content sections (e.g. card → card).
  static const double sectionGapCompact = 16.0;
  static const double sectionGapNormal = 24.0;

  // ── Border radii ──────────────────────────────────────────────────────────
  /// Cards and panels.
  static const double cardRadius = 20.0;

  /// Pill / chip elements (info labels, badges).
  static const double pillRadius = 999.0;

  /// Buttons (primary and secondary).
  static const double buttonRadius = 14.0;

  /// Small UI elements (e.g. inner icon containers).
  static const double innerRadius = 12.0;

  // ── Touch targets (kiosk mandate) ─────────────────────────────────────────
  /// Absolute minimum for any interactive target on a touch kiosk.
  static const double minTouchTarget = 64.0;

  /// Primary CTA (FilledButton / IcePrimaryButton) height.
  static const double primaryCTAHeight = 72.0;

  /// Secondary CTA (OutlinedButton / IceSecondaryButton) height.
  static const double secondaryCTAHeight = 64.0;

  /// Quantity stepper +/- button size (square).
  static const double stepperButtonSize = 64.0;

  /// Quantity display area width in the stepper.
  static const double stepperCountWidth = 96.0;

  // ── Bottom bar ────────────────────────────────────────────────────────────
  /// Extra padding at the bottom of scrollable content so content isn't hidden
  /// behind the floating bottom action bar.
  static const double bottomOverlayPaddingCompact = 120.0;
  static const double bottomOverlayPaddingNormal = 108.0;

  // ── Card shadow parameters (use with BoxShadow) ───────────────────────────
  /// Light elevation shadow blur radius.
  static const double shadowBlur = 32.0;

  /// Light elevation shadow spread radius.
  static const double shadowSpread = 0.0;

  // ── Step rail ─────────────────────────────────────────────────────────────
  /// Total height of the BotStepRail widget.
  static const double stepRailHeight = 56.0;

  /// Diameter of each step node circle.
  static const double stepNodeSize = 28.0;

  /// Diameter of the "active" bot-eye dot inside the node.
  static const double stepEyeSize = 10.0;
}
