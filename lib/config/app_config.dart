import 'package:flutter/foundation.dart';

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

  static const String paymentMethodCode = String.fromEnvironment(
    'ICEBOT_PAYMENT_METHOD_CODE',
    defaultValue: 'payos',
  );

  static const String demoKioskId = '00000000-0000-7000-8000-000000000001';

  static const String appChannel = 'Tablet';

  static String get apiBaseUrl => normalizeBaseUrl(rawApiBaseUrl);

  static String get effectiveKioskId =>
      kioskId.trim().isNotEmpty ? kioskId.trim() : demoKioskId;

  static bool get hasKioskId => demoMode || kioskId.trim().isNotEmpty;

  static bool get isProductionBuild => kReleaseMode && !demoMode;

  /// Null when the current compile-time configuration is safe to start.
  ///
  /// Development builds may use an explicit local HTTP backend. Release builds
  /// require a direct HTTPS origin and a real kiosk identity.
  static String? get runtimeConfigurationError => validateRuntimeConfiguration(
    rawApiUrl: rawApiBaseUrl,
    kioskIdentity: kioskId,
    paymentCode: paymentMethodCode,
    isDemoMode: demoMode,
    isReleaseBuild: kReleaseMode,
  );

  static String? validateRuntimeConfiguration({
    required String rawApiUrl,
    required String kioskIdentity,
    required String paymentCode,
    required bool isDemoMode,
    required bool isReleaseBuild,
  }) {
    if (isDemoMode) {
      return null;
    }

    if (kioskIdentity.trim().isEmpty) {
      return 'Thiếu ICEBOT_KIOSK_ID. Vui lòng cấu hình mã kiosk trước khi chạy.';
    }

    if (!_isGuid(kioskIdentity.trim())) {
      return 'ICEBOT_KIOSK_ID phải là mã UUID hợp lệ của kiosk.';
    }

    if (paymentCode.trim().isEmpty) {
      return 'Thiếu ICEBOT_PAYMENT_METHOD_CODE.';
    }

    final uri = Uri.tryParse(rawApiUrl.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'ICEBOT_API_BASE_URL phải là địa chỉ backend hợp lệ.';
    }

    if (uri.path.isNotEmpty && uri.path != '/' ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      return 'ICEBOT_API_BASE_URL chỉ nhận backend origin, không kèm đường dẫn hoặc thông tin xác thực.';
    }

    if (isReleaseBuild) {
      if (uri.scheme != 'https') {
        return 'Bản phát hành chỉ được kết nối backend HTTPS.';
      }
      if (_isLoopbackHost(uri.host)) {
        return 'Bản phát hành không được dùng localhost làm backend.';
      }
    }

    return null;
  }

  static String normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'http://10.0.2.2:5000';
    }

    return trimmed.replaceFirst(RegExp(r'/+$'), '');
  }

  static bool _isGuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  static bool _isLoopbackHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '::1' ||
        normalized.startsWith('127.');
  }
}
