import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/client_device/data/client_device_registration_store.dart';
import 'package:icebot_kiosk/features/client_device/data/client_device_session_manager.dart';
import 'package:icebot_kiosk/features/setup/data/local/auth_session_store.dart';
import 'package:icebot_kiosk/features/setup/data/models/auth_models.dart';
import 'package:icebot_kiosk/features/setup/data/repositories/auth_repository.dart';
import 'package:icebot_kiosk/features/setup/presentation/state/auth_controller.dart';

void main() {
  late _FakeAuthRepository repository;
  late MemoryAuthSessionStore legacyStore;
  late _MemorySecureStorage secureStorage;
  late ClientDeviceRegistrationStore registrations;
  late _SessionAdapter sessionAdapter;
  late ClientDeviceSessionManager sessions;
  late AuthController controller;

  setUp(() {
    repository = _FakeAuthRepository();
    legacyStore = MemoryAuthSessionStore();
    secureStorage = _MemorySecureStorage();
    registrations = ClientDeviceRegistrationStore(secureStorage);
    sessionAdapter = _SessionAdapter();
    sessions = ClientDeviceSessionManager(
      Dio()..httpClientAdapter = sessionAdapter,
      registrations,
    );
    controller = AuthController(
      repository: repository,
      legacySessionStore: legacyStore,
      registrationStore: registrations,
      sessionManager: sessions,
    );
  });

  tearDown(() => controller.dispose());

  test('uses Manager only to provision a directly assigned kiosk', () async {
    repository.account = _account(
      const AccountRoleScope(
        roleCode: 'Manager',
        organizationId: 'org-1',
        storeId: 'store-1',
        kioskId: _kiosk1,
      ),
    );

    expect(
      await controller.login(emailOrUsername: 'manager', password: 'secret'),
      isTrue,
    );
    expect(controller.session?.kioskId, _kiosk1);
    expect(repository.configuredKiosk?.id, _kiosk1);
    expect(repository.revokedTokens, ['refresh-token']);
    expect(legacyStore.value, isNull);
    expect((await registrations.readRegistration())?.clientDeviceId, _deviceId);
    expect(secureStorage.values.values.join(), isNot(contains('access-token')));
  });

  test('resolves one kiosk from the Manager store scope', () async {
    repository.account = _account(
      const AccountRoleScope(roleCode: 'Manager', storeId: 'store-1'),
    );
    repository.kiosks = const [
      ManagedKiosk(id: _kiosk1, storeId: 'store-1', code: 'KIOSK-01'),
    ];

    expect(
      await controller.login(emailOrUsername: 'manager', password: 'secret'),
      isTrue,
    );
    expect(controller.session?.kioskId, _kiosk1);
    expect(repository.lastStoreId, 'store-1');
  });

  test('rejects an account without Manager role and revokes it', () async {
    repository.account = _account(
      const AccountRoleScope(roleCode: 'SystemAdmin'),
    );

    expect(
      await controller.login(emailOrUsername: 'admin', password: 'secret'),
      isFalse,
    );
    expect(controller.error?.message, contains('Manager'));
    expect(repository.revokedTokens, ['refresh-token']);
    expect(await registrations.readRegistration(), isNull);
  });

  test('requires Manager selection when a store has multiple kiosks', () async {
    repository.account = _account(
      const AccountRoleScope(roleCode: 'Manager', storeId: 'store-1'),
    );
    repository.kiosks = const [
      ManagedKiosk(id: _kiosk1, storeId: 'store-1'),
      ManagedKiosk(id: _kiosk2, storeId: 'store-1'),
    ];

    expect(
      await controller.login(emailOrUsername: 'manager', password: 'secret'),
      isTrue,
    );
    expect(controller.isAuthenticated, isFalse);
    expect(controller.requiresKioskSelection, isTrue);
    sessionAdapter.kioskId = _kiosk2;

    expect(await controller.selectKiosk(_kiosk2), isTrue);
    expect(controller.session?.kioskId, _kiosk2);
    expect(repository.configuredKiosk?.id, _kiosk2);
  });

  test('restore migrates away from a persisted Manager session', () async {
    legacyStore.value = const KioskAuthSession(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
      accountId: 'account-1',
      userName: 'manager',
      managerName: 'Manager',
      organizationId: 'org-1',
      storeId: 'store-1',
      kioskId: _kiosk1,
    );
    final pending = await registrations.readOrCreatePendingProvision();
    await registrations.completeProvision(_deviceId, pending);

    await controller.restore();

    expect(controller.isAuthenticated, isTrue);
    expect(controller.session?.kioskId, _kiosk1);
    expect(legacyStore.value, isNull);
  });

  test('failed kiosk selection discards the revoked Manager session', () async {
    repository.account = _account(
      const AccountRoleScope(roleCode: 'Manager', storeId: 'store-1'),
    );
    repository.kiosks = const [
      ManagedKiosk(id: _kiosk1, storeId: 'store-1'),
      ManagedKiosk(id: _kiosk2, storeId: 'store-1'),
    ];
    await controller.login(emailOrUsername: 'manager', password: 'secret');
    repository.configureError = const ApiException(
      type: ApiErrorType.conflict,
      statusCode: 409,
      message: 'Active customer session.',
    );

    expect(await controller.selectKiosk(_kiosk1), isFalse);
    expect(controller.requiresKioskSelection, isFalse);
    expect(repository.revokedTokens, ['refresh-token']);
  });

  test('logout clears the ClientDevice registration locally', () async {
    final pending = await registrations.readOrCreatePendingProvision();
    await registrations.completeProvision(_deviceId, pending);
    await controller.restore();

    await controller.logout();

    expect(controller.isAuthenticated, isFalse);
    expect(await registrations.readRegistration(), isNull);
  });
}

const _deviceId = '019f1b51-3a55-7a48-9b3f-1b9a5d2c1001';
const _kiosk1 = '019f1b51-3a55-7a48-9b3f-1b9a5d2c1002';
const _kiosk2 = '019f1b51-3a55-7a48-9b3f-1b9a5d2c1003';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(DioClient(baseUrl: 'https://api.test'));

  late AuthenticatedAccountResult account;
  List<ManagedKiosk> kiosks = const [];
  String? lastStoreId;
  ManagedKiosk? configuredKiosk;
  ApiException? configureError;
  final revokedTokens = <String>[];

  @override
  Future<AuthenticatedAccountResult> login({
    required String emailOrUsername,
    required String password,
  }) async => account;

  @override
  Future<List<ManagedKiosk>> listKiosksForStore({
    required String accessToken,
    required String storeId,
  }) async {
    lastStoreId = storeId;
    return kiosks;
  }

  @override
  Future<ManagedClientDevice> configureClientDevice({
    required String accessToken,
    required ManagedKiosk kiosk,
    required PendingClientDeviceProvision pending,
  }) async {
    final error = configureError;
    if (error != null) throw error;
    configuredKiosk = kiosk;
    return ManagedClientDevice(
      id: _deviceId,
      kioskId: kiosk.id,
      type: 'SelfOrderTablet',
      status: 'Active',
      revision: 1,
    );
  }

  @override
  Future<void> revoke(String refreshToken) async {
    revokedTokens.add(refreshToken);
  }
}

class _SessionAdapter implements HttpClientAdapter {
  String kioskId = _kiosk1;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path != '/api/v1/client-device-sessions') {
      throw StateError('Unexpected route: ${options.path}');
    }
    return ResponseBody.fromString(
      jsonEncode({
        'succeeded': true,
        'statusCode': 200,
        'data': {
          'accessToken': 'client-device-token',
          'expiresAt': '2030-01-01T00:00:00Z',
          'device': {'kioskId': kioskId},
        },
      }),
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

AuthenticatedAccountResult _account(AccountRoleScope role) {
  return AuthenticatedAccountResult(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    id: 'account-1',
    userName: 'manager',
    fullName: 'Store Manager',
    email: 'manager@example.test',
    roles: [role],
  );
}
