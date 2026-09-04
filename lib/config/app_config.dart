import 'package:flutter/foundation.dart';

/// Compile-time application configuration for the kiosk tablet app.
class AppConfig {
  AppConfig._();

  static const String rawApiBaseUrl = String.fromEnvironment(
    'ICEBOT_API_BASE_URL',
    defaultValue: 'https://api.icebot.io.vn',
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

  static bool get isProductionBuild => kReleaseMode && !demoMode;

  /// Null when the current compile-time configuration is safe to start.
  ///
  /// Development builds may use an explicit local HTTP backend. Release builds
  /// require a direct HTTPS origin; kiosk identity is resolved after login.
  static String? get runtimeConfigurationError => validateRuntimeConfiguration(
    rawApiUrl: rawApiBaseUrl,
    paymentCode: paymentMethodCode,
    isDemoMode: demoMode,
    isReleaseBuild: kReleaseMode,
  );

  static String? validateRuntimeConfiguration({
    required String rawApiUrl,
    required String paymentCode,
    required bool isDemoMode,
    required bool isReleaseBuild,
  }) {
    if (isDemoMode) {
      return null;
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

  static bool _isLoopbackHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '::1' ||
        normalized.startsWith('127.');
  }
}
