/// Compile-time application configuration for the kiosk tablet app.
class AppConfig {
  AppConfig._();

  static const String rawApiBaseUrl = String.fromEnvironment(
    'ICEBOT_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  static const String kioskId = String.fromEnvironment(
    'ICEBOT_KIOSK_ID',
    defaultValue: '',
  );

  static const bool demoMode = bool.fromEnvironment(
    'ICEBOT_DEMO_MODE',
    defaultValue: false,
  );

  static const String demoKioskId = '00000000-0000-7000-8000-000000000001';

  static const String appChannel = 'Tablet';

  static String get apiBaseUrl => normalizeBaseUrl(rawApiBaseUrl);

  static String get effectiveKioskId =>
      kioskId.trim().isNotEmpty ? kioskId.trim() : demoKioskId;

  static bool get hasKioskId => demoMode || kioskId.trim().isNotEmpty;

  static String normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'http://10.0.2.2:5000';
    }

    return trimmed.replaceFirst(RegExp(r'/+$'), '');
  }
}
