import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/config/app_config.dart';

void main() {
  test('allows an explicit local backend for a non-release build', () {
    final error = AppConfig.validateRuntimeConfiguration(
      rawApiUrl: 'http://127.0.0.1:5000',
      paymentCode: 'payos',
      isDemoMode: false,
      isReleaseBuild: false,
    );

    expect(error, isNull);
  });

  test('rejects HTTP and loopback origins for a release build', () {
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

  test('accepts a production HTTPS origin', () {
    final error = AppConfig.validateRuntimeConfiguration(
      rawApiUrl: 'https://icebot.io.vn',
      paymentCode: 'payos',
      isDemoMode: false,
      isReleaseBuild: true,
    );

    expect(error, isNull);
  });

  test('rejects missing payment code or malformed backend origin', () {
    final missingPaymentError = AppConfig.validateRuntimeConfiguration(
      rawApiUrl: 'https://icebot.io.vn',
      paymentCode: '',
      isDemoMode: false,
      isReleaseBuild: true,
    );
    final malformedUrlError = AppConfig.validateRuntimeConfiguration(
      rawApiUrl: 'https://icebot.io.vn/api/v1',
      paymentCode: 'payos',
      isDemoMode: false,
      isReleaseBuild: true,
    );

    expect(missingPaymentError, contains('ICEBOT_PAYMENT_METHOD_CODE'));
    expect(malformedUrlError, contains('origin'));
  });

  test('does not block demo mode configuration', () {
    final error = AppConfig.validateRuntimeConfiguration(
      rawApiUrl: '',
      paymentCode: '',
      isDemoMode: true,
      isReleaseBuild: true,
    );

    expect(error, isNull);
  });
}
