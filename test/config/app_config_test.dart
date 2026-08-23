import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/config/app_config.dart';

void main() {
  test('allows an explicit local backend for a non-release build', () {
    expect(
      AppConfig.validateRuntimeConfiguration(
        rawApiUrl: 'http://127.0.0.1:5000',
        paymentCode: 'payos',
        isDemoMode: false,
        isReleaseBuild: false,
      ),
      isNull,
    );
  });

  test('release requires an HTTPS non-loopback origin', () {
    final httpError = AppConfig.validateRuntimeConfiguration(
      rawApiUrl: 'http://icebot.io.vn',
      paymentCode: 'payos',
      isDemoMode: false,
      isReleaseBuild: true,
    );
    final loopbackError = AppConfig.validateRuntimeConfiguration(
      rawApiUrl: 'https://localhost:5000',
      paymentCode: 'payos',
      isDemoMode: false,
      isReleaseBuild: true,
    );
    expect(httpError, contains('HTTPS'));
    expect(loopbackError, contains('localhost'));
  });

  test('does not require a compile-time kiosk identity', () {
    expect(
      AppConfig.validateRuntimeConfiguration(
        rawApiUrl: 'https://icebot.io.vn',
        paymentCode: 'payos',
        isDemoMode: false,
        isReleaseBuild: true,
      ),
      isNull,
    );
  });

  test('demo mode permits local configuration', () {
    expect(
      AppConfig.validateRuntimeConfiguration(
        rawApiUrl: '',
        paymentCode: '',
        isDemoMode: true,
        isReleaseBuild: true,
      ),
      isNull,
    );
  });
}
