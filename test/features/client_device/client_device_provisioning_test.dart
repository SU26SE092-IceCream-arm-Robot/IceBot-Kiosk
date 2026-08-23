import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/features/client_device/data/client_device_registration_store.dart';
import 'package:icebot_kiosk/features/client_device/data/client_device_session_manager.dart';
import 'package:icebot_kiosk/features/client_device/data/client_device_setup_service.dart';

void main() {
  test(
    'pending provision is stable until a server device identity is stored',
    () async {
      final storage = _MemorySecureStorage();
      final registrations = ClientDeviceRegistrationStore(storage);

      final first = await registrations.readOrCreatePendingProvision();
      final second = await registrations.readOrCreatePendingProvision();

      expect(second.installationId, first.installationId);
      expect(second.credential, first.credential);
      expect(second.idempotencyKey, first.idempotencyKey);
      expect(base64Url.decode(first.credential), hasLength(32));

      await registrations.completeProvision(_deviceId, first);

      final registration = await registrations.readRegistration();
      expect(registration?.clientDeviceId, _deviceId);
      expect(registration?.installationId, first.installationId);
      expect(registration?.credential, first.credential);
      expect(
        await registrations.readOrCreatePendingProvision(),
        isNot(same(first)),
      );
    },
  );

  test(
    'setup provisions a client device without persisting the manager session',
    () async {
      final adapter = _ClientDeviceAdapter();
      final registrations = ClientDeviceRegistrationStore(
        _MemorySecureStorage(),
      );
      final service = ClientDeviceSetupService(
        Dio()..httpClientAdapter = adapter,
        registrations,
      );

      final session = await service.signIn('manager@icebot.test', 'password');
      final revoked = await service.provision(
        session,
        session.kiosks.single,
        displayName: 'Front tablet',
      );

      expect(revoked, isTrue);
      expect(adapter.paths, [
        '/api/v1/authentication/login',
        '/api/v1/management/kiosks',
        '/api/v1/management/kiosks/$_kioskId/client-devices',
        '/api/v1/authentication/revoke',
      ]);
      expect(
        adapter.provisionRequest?.headers['Authorization'],
        'Bearer manager-access-token',
      );
      expect(adapter.provisionRequest?.headers['Idempotency-Key'], isNotEmpty);
      expect(
        adapter.revokeRequest?.data['refreshToken'],
        'manager-refresh-token',
      );

      final registration = await registrations.readRegistration();
      expect(registration?.clientDeviceId, _deviceId);
      expect(registration?.credential, isNot('manager-access-token'));
    },
  );

  test(
    'runtime session token is memory-only and refreshes after an unauthorized response',
    () async {
      final adapter = _ClientDeviceAdapter();
      final storage = _MemorySecureStorage();
      final registrations = ClientDeviceRegistrationStore(storage);
      final pending = await registrations.readOrCreatePendingProvision();
      await registrations.completeProvision(_deviceId, pending);
      final sessions = ClientDeviceSessionManager(
        Dio()..httpClientAdapter = adapter,
        registrations,
      );

      final first = await sessions.ensureSession();
      final cached = await sessions.ensureSession();
      final refreshed = await sessions.refreshAfterUnauthorized();

      expect(first?.accessToken, 'client-device-token-1');
      expect(cached?.accessToken, 'client-device-token-1');
      expect(refreshed?.accessToken, 'client-device-token-2');
      expect(adapter.sessionRequests, 2);
      expect(
        adapter.sessionRequestHeaders,
        everyElement(containsPair('X-Client-Device-Id', _deviceId)),
      );
      expect(
        storage.values.values.join(),
        isNot(contains('client-device-token')),
      );
    },
  );

  test(
    'setup replaces a registered tablet when its credential is no longer usable',
    () async {
      final adapter = _ClientDeviceAdapter()..existingDeviceAvailable = true;
      final registrations = ClientDeviceRegistrationStore(
        _MemorySecureStorage(),
      );
      final prior = await registrations.readOrCreatePendingProvision();
      await registrations.completeProvision(_deviceId, prior);
      final service = ClientDeviceSetupService(
        Dio()..httpClientAdapter = adapter,
        registrations,
      );

      final session = await service.signIn('manager@icebot.test', 'password');
      final revoked = await service.provision(
        session,
        session.kiosks.single,
        displayName: 'Replacement tablet',
      );

      expect(revoked, isTrue);
      expect(adapter.paths, [
        '/api/v1/authentication/login',
        '/api/v1/management/kiosks',
        '/api/v1/management/client-devices/$_deviceId',
        '/api/v1/management/kiosks/$_kioskId/client-devices/replace',
        '/api/v1/authentication/revoke',
      ]);
      expect(
        adapter.provisionRequest?.data['expectedCurrentClientDeviceId'],
        _deviceId,
      );
      expect(adapter.provisionRequest?.data['expectedCurrentRevision'], 7);
      expect(
        (await registrations.readRegistration())?.clientDeviceId,
        _replacementDeviceId,
      );
    },
  );

  test(
    'a rejected client-device credential clears the runtime identity',
    () async {
      final adapter = _ClientDeviceAdapter()..rejectSessionExchange = true;
      final registrations = ClientDeviceRegistrationStore(
        _MemorySecureStorage(),
      );
      final pending = await registrations.readOrCreatePendingProvision();
      await registrations.completeProvision(_deviceId, pending);
      final sessions = ClientDeviceSessionManager(
        Dio()..httpClientAdapter = adapter,
        registrations,
      );

      await expectLater(sessions.ensureSession(), throwsA(isA<Exception>()));

      expect(sessions.identity, isNull);
      expect(adapter.sessionRequests, 1);
    },
  );
}

const _deviceId = '019f1b51-3a55-7a48-9b3f-1b9a5d2c1001';
const _replacementDeviceId = '019f1b51-3a55-7a48-9b3f-1b9a5d2c1003';
const _kioskId = '019f1b51-3a55-7a48-9b3f-1b9a5d2c1002';

class _MemorySecureStorage extends FlutterSecureStorage {
  final values = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

class _ClientDeviceAdapter implements HttpClientAdapter {
  final paths = <String>[];
  RequestOptions? provisionRequest;
  RequestOptions? revokeRequest;
  final sessionRequestHeaders = <Map<String, dynamic>>[];
  var sessionRequests = 0;
  var rejectSessionExchange = false;
  var existingDeviceAvailable = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    final body = switch (options.path) {
      '/api/v1/authentication/login' => _success({
        'accessToken': 'manager-access-token',
        'refreshToken': 'manager-refresh-token',
      }),
      '/api/v1/management/kiosks' => _success([
        {'id': _kioskId, 'name': 'Demo kiosk', 'code': 'DEMO-KIOSK'},
      ]),
      '/api/v1/management/kiosks/$_kioskId/client-devices' => () {
        provisionRequest = options;
        return _success({'id': _deviceId});
      }(),
      '/api/v1/management/client-devices/$_deviceId'
          when existingDeviceAvailable =>
        _success({
          'id': _deviceId,
          'kioskId': _kioskId,
          'status': 'Active',
          'revision': 7,
        }),
      '/api/v1/management/kiosks/$_kioskId/client-devices/replace' => () {
        provisionRequest = options;
        return _success({'id': _replacementDeviceId});
      }(),
      '/api/v1/authentication/revoke' => () {
        revokeRequest = options;
        return _success({});
      }(),
      '/api/v1/client-device-sessions' => _sessionResponse(options),
      _ => throw StateError('Unexpected route: ${options.path}'),
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      rejectSessionExchange && options.path == '/api/v1/client-device-sessions'
          ? 401
          : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Map<String, Object?> _sessionResponse(RequestOptions options) {
    sessionRequests++;
    sessionRequestHeaders.add(Map<String, dynamic>.from(options.headers));
    if (rejectSessionExchange) {
      return {
        'succeeded': false,
        'statusCode': 401,
        'message': 'Client device credential is invalid.',
      };
    }
    return _success({
      'accessToken': 'client-device-token-$sessionRequests',
      'expiresAt': '2030-01-01T00:00:00Z',
      'device': {'kioskId': _kioskId},
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _success(Object data) => {
  'succeeded': true,
  'statusCode': 200,
  'data': data,
};
