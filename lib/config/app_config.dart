import 'package:flutter/foundation.dart';

/// Non-secret build configuration. Kiosk scope comes only from ClientDevice.
class AppConfig {
  AppConfig._();

  static const String rawApiBaseUrl = String.fromEnvironment(
    'ICEBOT_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );
  static const bool demoMode = bool.fromEnvironment(
    'ICEBOT_DEMO_MODE',
    defaultValue: false,
  );
  static const String paymentMethodCode = String.fromEnvironment(
    'ICEBOT_PAYMENT_METHOD_CODE',
    defaultValue: 'payos',
  );
  static const String appVersion = String.fromEnvironment(
    'ICEBOT_APP_VERSION',
    defaultValue: '1.0.0',
  );
  static const String appChannel = 'Tablet';
  static const String demoKioskId = '00000000-0000-7000-8000-000000000001';

  static String get apiBaseUrl => normalizeBaseUrl(rawApiBaseUrl);
  static bool get isProductionBuild => kReleaseMode && !demoMode;

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
    if (isDemoMode) return null;
    if (paymentCode.trim().isEmpty) return 'Thiếu ICEBOT_PAYMENT_METHOD_CODE.';

    final uri = Uri.tryParse(rawApiUrl.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'ICEBOT_API_BASE_URL phải là địa chỉ backend hợp lệ.';
    }
    if ((uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      return 'ICEBOT_API_BASE_URL chỉ nhận backend origin, không kèm đường dẫn hoặc thông tin xác thực.';
    }
    if (isReleaseBuild &&
        (uri.scheme != 'https' || _isLoopbackHost(uri.host))) {
      return uri.scheme != 'https'
          ? 'Bản phát hành chỉ được kết nối backend HTTPS.'
          : 'Bản phát hành không được dùng localhost làm backend.';
    }
    return null;
  }

  static String normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty
        ? 'http://10.0.2.2:5000'
        : trimmed.replaceFirst(RegExp(r'/+$'), '');
  }

  static bool _isLoopbackHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '::1' ||
        normalized.startsWith('127.');
  }
}
