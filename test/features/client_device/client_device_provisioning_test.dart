import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/client_device/data/client_device_registration_store.dart';
import 'package:icebot_kiosk/features/client_device/data/client_device_session_manager.dart';
import 'package:icebot_kiosk/features/setup/data/models/auth_models.dart';
import 'package:icebot_kiosk/features/setup/data/repositories/auth_repository.dart';

void main() {
  test('pending provision remains stable until device registration', () async {
    final storage = _MemorySecureStorage();
    final registrations = ClientDeviceRegistrationStore(storage);

    final first = await registrations.readOrCreatePendingProvision();
    final second = await registrations.readOrCreatePendingProvision();

    expect(second.installationId, first.installationId);
    expect(second.credential, first.credential);
    expect(second.idempotencyKey, first.idempotencyKey);
    expect(base64.decode(first.credential), hasLength(32));
    expect(first.credential, isNot(matches(RegExp(r'[-_]'))));

    await registrations.completeProvision(_deviceId, first);
    expect((await registrations.readRegistration())?.clientDeviceId, _deviceId);
  });

  test('replaces a pending Base64URL credential rejected by backend', () async {
    final storage = _MemorySecureStorage();
    final urlSafeCredential = base64UrlEncode(List<int>.filled(32, 0xff));
    expect(urlSafeCredential, contains('_'));
    storage.values[ClientDeviceRegistrationStore.pendingProvisionKey] =
        jsonEncode({
          'installationId': _kioskId,
          'credential': urlSafeCredential,
          'idempotencyKey': _storeId,
        });
    final registrations = ClientDeviceRegistrationStore(storage);

    final pending = await registrations.readOrCreatePendingProvision();

    expect(pending.credential, isNot(urlSafeCredential));
    expect(base64.decode(pending.credential), hasLength(32));
    expect(pending.credential, matches(RegExp(r'^[A-Za-z0-9+/]{43}=$')));
  });

  test('runtime session token stays in memory and refreshes', () async {
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
      adapter.sessionHeaders,
      everyElement(containsPair('X-Client-Device-Id', _deviceId)),
    );
    expect(
      storage.values.values.join(),
      isNot(contains('client-device-token')),
    );
  });

  test('runtime interceptor attaches device JWT and retries one 401', () async {
    final adapter = _ClientDeviceAdapter();
    final registrations = ClientDeviceRegistrationStore(_MemorySecureStorage());
    final pending = await registrations.readOrCreatePendingProvision();
    await registrations.completeProvision(_deviceId, pending);
    final sessions = ClientDeviceSessionManager(
      Dio()..httpClientAdapter = adapter,
      registrations,
    );
    final runtimeDio = Dio()..httpClientAdapter = adapter;
    runtimeDio.interceptors.add(
      ClientDeviceAuthInterceptor(runtimeDio, sessions),
    );

    final response = await runtimeDio.get<dynamic>('/api/v1/runtime/menu');

    expect(response.statusCode, 200);
    expect(adapter.runtimeRequests, 2);
    expect(adapter.sessionRequests, 2);
    expect(adapter.runtimeAuthorization, [
      'Bearer client-device-token-1',
      'Bearer client-device-token-2',
    ]);
  });

  test('Manager provisioning creates a new ClientDevice binding', () async {
    final adapter = _ClientDeviceAdapter();
    final repository = AuthRepository(
      DioClient(
        baseUrl: 'https://api.test',
        dio: Dio()..httpClientAdapter = adapter,
      ),
    );
    final registrations = ClientDeviceRegistrationStore(_MemorySecureStorage());
    final pending = await registrations.readOrCreatePendingProvision();

    final device = await repository.configureClientDevice(
      accessToken: 'manager-token',
      kiosk: const ManagedKiosk(id: _kioskId, storeId: _storeId),
      pending: pending,
    );

    expect(device.id, _deviceId);
    expect(adapter.paths, [
      '/api/v1/management/kiosks/$_kioskId/client-devices',
      '/api/v1/management/kiosks/$_kioskId/client-devices',
    ]);
    expect(adapter.mutation?.headers['Authorization'], 'Bearer manager-token');
    expect(adapter.mutation?.headers['Idempotency-Key'], isNotEmpty);
    expect(adapter.mutation?.data['installationId'], pending.installationId);
    expect(adapter.mutation?.data, isNot(contains('kioskId')));
  });

  test('Manager provisioning replaces an existing active tablet', () async {
    final adapter = _ClientDeviceAdapter()..hasActiveTablet = true;
    final repository = AuthRepository(
      DioClient(
        baseUrl: 'https://api.test',
        dio: Dio()..httpClientAdapter = adapter,
      ),
    );
    final registrations = ClientDeviceRegistrationStore(_MemorySecureStorage());
    final pending = await registrations.readOrCreatePendingProvision();

    final device = await repository.configureClientDevice(
      accessToken: 'manager-token',
      kiosk: const ManagedKiosk(id: _kioskId, storeId: _storeId),
      pending: pending,
    );

    expect(device.id, _replacementDeviceId);
    expect(adapter.paths.last, endsWith('/client-devices/replace'));
    expect(adapter.mutation?.data['expectedCurrentClientDeviceId'], _deviceId);
    expect(adapter.mutation?.data['expectedCurrentRevision'], 7);
    expect(
      adapter.mutation?.data['replacementInstallationId'],
      pending.installationId,
    );
  });
}

const _deviceId = '019f1b51-3a55-7a48-9b3f-1b9a5d2c1001';
const _kioskId = '019f1b51-3a55-7a48-9b3f-1b9a5d2c1002';
const _replacementDeviceId = '019f1b51-3a55-7a48-9b3f-1b9a5d2c1003';
const _storeId = '019f1b51-3a55-7a48-9b3f-1b9a5d2c1004';

class _ClientDeviceAdapter implements HttpClientAdapter {
  final paths = <String>[];
  final sessionHeaders = <Map<String, dynamic>>[];
  RequestOptions? mutation;
  var sessionRequests = 0;
  var runtimeRequests = 0;
  var hasActiveTablet = false;
  final runtimeAuthorization = <String?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    if (options.path == '/api/v1/runtime/menu') {
      runtimeRequests++;
      runtimeAuthorization.add(options.headers['Authorization'] as String?);
      return ResponseBody.fromString(
        jsonEncode(
          runtimeRequests == 1
              ? {
                  'succeeded': false,
                  'statusCode': 401,
                  'message': 'Expired device token.',
                }
              : _success({'items': <Object?>[]}),
        ),
        runtimeRequests == 1 ? 401 : 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    final Object body;
    if (options.path == '/api/v1/client-device-sessions') {
      sessionRequests++;
      sessionHeaders.add(Map<String, dynamic>.from(options.headers));
      body = _success({
        'accessToken': 'client-device-token-$sessionRequests',
        'expiresAt': '2030-01-01T00:00:00Z',
        'device': {'kioskId': _kioskId},
      });
    } else if (options.path ==
            '/api/v1/management/kiosks/$_kioskId/client-devices' &&
        options.method == 'GET') {
      body = _success(
        hasActiveTablet
            ? [
                {
                  'id': _deviceId,
                  'kioskId': _kioskId,
                  'type': 'SelfOrderTablet',
                  'status': 'Active',
                  'revision': 7,
                },
              ]
            : <Object?>[],
      );
    } else if (options.path ==
            '/api/v1/management/kiosks/$_kioskId/client-devices' &&
        options.method == 'POST') {
      mutation = options;
      body = _success({
        'id': _deviceId,
        'kioskId': _kioskId,
        'type': 'SelfOrderTablet',
        'status': 'Active',
        'revision': 1,
      });
    } else if (options.path ==
        '/api/v1/management/kiosks/$_kioskId/client-devices/replace') {
      mutation = options;
      body = _success({
        'id': _replacementDeviceId,
        'kioskId': _kioskId,
        'type': 'SelfOrderTablet',
        'status': 'Active',
        'revision': 1,
      });
    } else {
      throw StateError('Unexpected route: ${options.method} ${options.path}');
    }

    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

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

Map<String, Object?> _success(Object data) => {
  'succeeded': true,
  'statusCode': 200,
  'data': data,
};
