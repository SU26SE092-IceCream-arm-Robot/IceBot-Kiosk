import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/setup/data/local/auth_session_store.dart';
import 'package:icebot_kiosk/features/setup/data/models/auth_models.dart';
import 'package:icebot_kiosk/features/setup/data/repositories/auth_repository.dart';
import 'package:icebot_kiosk/features/setup/presentation/state/auth_controller.dart';

void main() {
  late _FakeAuthRepository repository;
  late MemoryAuthSessionStore store;
  late AuthController controller;

  setUp(() {
    repository = _FakeAuthRepository();
    store = MemoryAuthSessionStore();
    controller = AuthController(repository: repository, sessionStore: store);
  });

  test('accepts one Manager role with a kiosk assigned directly', () async {
    repository.account = _account(
      const AccountRoleScope(
        roleCode: 'Manager',
        organizationId: 'org-1',
        storeId: 'store-1',
        kioskId: 'kiosk-1',
      ),
    );

    expect(
      await controller.login(emailOrUsername: 'manager', password: 'secret'),
      isTrue,
    );
    expect(controller.session?.kioskId, 'kiosk-1');
    expect(controller.session?.storeId, 'store-1');
    expect(store.value?.accessToken, 'access-token');
  });

  test('resolves exactly one kiosk from Manager store scope', () async {
    repository.account = _account(
      const AccountRoleScope(roleCode: 'Manager', storeId: 'store-1'),
    );
    repository.kiosks = const [
      ManagedKiosk(id: 'kiosk-1', storeId: 'store-1', code: 'KIOSK-01'),
    ];

    expect(
      await controller.login(emailOrUsername: 'manager', password: 'secret'),
      isTrue,
    );
    expect(controller.session?.kioskId, 'kiosk-1');
    expect(controller.session?.kioskCode, 'KIOSK-01');
    expect(repository.lastStoreId, 'store-1');
  });

  test('rejects an account without Manager role', () async {
    repository.account = _account(
      const AccountRoleScope(roleCode: 'SystemAdmin'),
    );

    expect(
      await controller.login(emailOrUsername: 'admin', password: 'secret'),
      isFalse,
    );
    expect(controller.error?.message, contains('Manager'));
    expect(store.value, isNull);
  });

  test('shows a clear error when Manager store has no kiosk', () async {
    repository.account = _account(
      const AccountRoleScope(roleCode: 'Manager', storeId: 'store-1'),
    );

    expect(
      await controller.login(emailOrUsername: 'manager', password: 'secret'),
      isFalse,
    );
    expect(controller.error?.message, contains('chưa có kiosk'));
  });

  test(
    'requires Manager to choose when the store has multiple kiosks',
    () async {
      repository.account = _account(
        const AccountRoleScope(roleCode: 'Manager', storeId: 'store-1'),
      );
      repository.kiosks = const [
        ManagedKiosk(id: 'kiosk-1', storeId: 'store-1'),
        ManagedKiosk(id: 'kiosk-2', storeId: 'store-1'),
      ];

      expect(
        await controller.login(emailOrUsername: 'manager', password: 'secret'),
        isTrue,
      );
      expect(controller.isAuthenticated, isFalse);
      expect(controller.requiresKioskSelection, isTrue);
      expect(controller.availableKiosks.map((kiosk) => kiosk.id), [
        'kiosk-1',
        'kiosk-2',
      ]);

      expect(await controller.selectKiosk('kiosk-2'), isTrue);
      expect(controller.session?.kioskId, 'kiosk-2');
      expect(controller.session?.storeId, 'store-1');
      expect(store.value?.kioskId, 'kiosk-2');
    },
  );

  test('restores, refreshes, and revokes the persisted session', () async {
    store.value = const KioskAuthSession(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
      accountId: 'account-1',
      userName: 'manager',
      managerName: 'Manager',
      organizationId: 'org-1',
      storeId: 'store-1',
      kioskId: 'kiosk-1',
    );
    repository.account = _account(
      const AccountRoleScope(
        roleCode: 'Manager',
        organizationId: 'org-1',
        storeId: 'store-1',
      ),
    );

    await controller.restore();
    expect(controller.isAuthenticated, isTrue);
    expect(controller.session?.accessToken, 'access-token');
    expect(controller.session?.kioskId, 'kiosk-1');

    await controller.logout();
    expect(controller.isAuthenticated, isFalse);
    expect(store.value, isNull);
    expect(repository.revokedToken, 'refresh-token');
  });
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(DioClient(baseUrl: 'https://api.test'));

  late AuthenticatedAccountResult account;
  List<ManagedKiosk> kiosks = const [];
  String? lastStoreId;
  String? revokedToken;

  @override
  Future<AuthenticatedAccountResult> login({
    required String emailOrUsername,
    required String password,
  }) async => account;

  @override
  Future<AuthenticatedAccountResult> refresh(String refreshToken) async =>
      account;

  @override
  Future<List<ManagedKiosk>> listKiosksForStore({
    required String accessToken,
    required String storeId,
  }) async {
    lastStoreId = storeId;
    return kiosks;
  }

  @override
  Future<void> revoke(String refreshToken) async {
    revokedToken = refreshToken;
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
