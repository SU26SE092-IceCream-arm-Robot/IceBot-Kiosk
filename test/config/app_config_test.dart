import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/config/app_config.dart';

void main() {
  const kioskId = 'aec68c48-207d-433d-b2fd-e7ddf7d5346a';

  test('allows an explicit local backend for a non-release build', () {
    final error = AppConfig.validateRuntimeConfiguration(
      rawApiUrl: 'http://127.0.0.1:5000',
      kioskIdentity: kioskId,
      paymentCode: 'payos',
      isDemoMode: false,
      isReleaseBuild: false,
    );

    expect(error, isNull);
  });

  test('rejects HTTP and loopback origins for a release build', () {
    final httpError = AppConfig.validateRuntimeConfiguration(
      rawApiUrl: 'http://icebot.io.vn',
      kioskIdentity: kioskId,
      paymentCode: 'payos',
      isDemoMode: false,
      isReleaseBuild: true,
    );
    final loopbackError = AppConfig.validateRuntimeConfiguration(
      rawApiUrl: 'https://localhost:5000',
      kioskIdentity: kioskId,
      paymentCode: 'payos',
      isDemoMode: false,
      isReleaseBuild: true,
    );

    expect(httpError, contains('HTTPS'));
    expect(loopbackError, contains('localhost'));
  });

  test('accepts a production HTTPS origin and valid kiosk identity', () {
    final error = AppConfig.validateRuntimeConfiguration(
      rawApiUrl: 'https://icebot.io.vn',
      kioskIdentity: kioskId,
      paymentCode: 'payos',
      isDemoMode: false,
      isReleaseBuild: true,
    );

    expect(error, isNull);
  });

  test('rejects missing or malformed runtime values outside demo mode', () {
    final missingKioskError = AppConfig.validateRuntimeConfiguration(
      rawApiUrl: 'https://icebot.io.vn',
      kioskIdentity: '',
      paymentCode: 'payos',
      isDemoMode: false,
      isReleaseBuild: true,
    );
    final malformedKioskError = AppConfig.validateRuntimeConfiguration(
      rawApiUrl: 'https://icebot.io.vn/api/v1',
      kioskIdentity: 'not-a-kiosk-id',
      paymentCode: '',
      isDemoMode: false,
      isReleaseBuild: true,
    );

    expect(missingKioskError, contains('ICEBOT_KIOSK_ID'));
    expect(malformedKioskError, contains('UUID'));
  });

  test('does not block demo mode configuration', () {
    final error = AppConfig.validateRuntimeConfiguration(
      rawApiUrl: '',
      kioskIdentity: '',
      paymentCode: '',
      isDemoMode: true,
      isReleaseBuild: true,
    );

    expect(error, isNull);
  });
}
