import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/features/client_device/data/client_device_registration_store.dart';
import 'package:icebot_kiosk/features/client_device/data/client_device_session_manager.dart';
import 'package:icebot_kiosk/features/setup/data/local/auth_session_store.dart';
import 'package:icebot_kiosk/features/setup/data/models/auth_models.dart';
import 'package:icebot_kiosk/features/setup/data/repositories/auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository repository,
    required AuthSessionStore legacySessionStore,
    required ClientDeviceRegistrationStore registrationStore,
    required ClientDeviceSessionManager sessionManager,
  }) : _repository = repository,
       _legacySessionStore = legacySessionStore,
       _registrationStore = registrationStore,
       _sessionManager = sessionManager {
    _sessionManager.addListener(_handleRuntimeSessionChanged);
  }

  final AuthRepository _repository;
  final AuthSessionStore _legacySessionStore;
  final ClientDeviceRegistrationStore _registrationStore;
  final ClientDeviceSessionManager _sessionManager;

  AuthenticatedAccountResult? _pendingAccount;
  AccountRoleScope? _pendingManagerRole;
  List<ManagedKiosk> _availableKiosks = const [];
  ApiException? _error;
  bool _isRestoring = true;
  bool _isSubmitting = false;

  ClientDeviceRuntimeIdentity? get session => _sessionManager.identity;
  ApiException? get error => _error;
  bool get isRestoring => _isRestoring;
  bool get isSubmitting => _isSubmitting;
  bool get isAuthenticated => session != null;
  bool get requiresKioskSelection =>
      _pendingAccount != null && _pendingManagerRole != null;
  List<ManagedKiosk> get availableKiosks => _availableKiosks;

  Future<void> restore() async {
    _isRestoring = true;
    _error = null;
    notifyListeners();

    try {
      // v1.1 and earlier persisted a Manager session. It must never be reused
      // as runtime authority after the ClientDevice migration.
      await _legacySessionStore.clear();
      await _sessionManager.ensureSession();
    } on ApiException catch (error) {
      _error = error;
    } on Object {
      _sessionManager.clearIdentity();
      _error = const ApiException(
        type: ApiErrorType.unknown,
        message: 'Không thể khôi phục cấu hình thiết bị kiosk đã lưu.',
      );
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String emailOrUsername,
    required String password,
  }) async {
    if (_isSubmitting) return false;
    if (emailOrUsername.trim().isEmpty || password.isEmpty) {
      _error = const ApiException(
        type: ApiErrorType.validation,
        message: 'Vui lòng nhập tài khoản và mật khẩu Manager.',
      );
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _error = null;
    notifyListeners();

    AuthenticatedAccountResult? account;
    var provisioningStarted = false;
    try {
      account = await _repository.login(
        emailOrUsername: emailOrUsername,
        password: password,
      );
      final kiosk = await _resolveKiosk(account);
      if (kiosk != null) {
        provisioningStarted = true;
        await _provisionAndActivate(account, kiosk);
      }
      return true;
    } on ApiException catch (error) {
      if (account != null && _pendingAccount == null && !provisioningStarted) {
        await _revokeManagerSession(account.refreshToken);
      }
      _error = _presentLoginError(error);
      return false;
    } on Object {
      if (account != null && _pendingAccount == null && !provisioningStarted) {
        await _revokeManagerSession(account.refreshToken);
      }
      _error = const ApiException(
        type: ApiErrorType.unknown,
        message: 'Không thể hoàn tất thiết lập kiosk.',
      );
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> selectKiosk(String kioskId) async {
    if (_isSubmitting) return false;
    final account = _pendingAccount;
    ManagedKiosk? kiosk;
    for (final candidate in _availableKiosks) {
      if (candidate.id == kioskId) {
        kiosk = candidate;
        break;
      }
    }
    if (account == null || _pendingManagerRole == null || kiosk == null) {
      _error = const ApiException(
        type: ApiErrorType.validation,
        message: 'Lựa chọn kiosk không còn hợp lệ. Vui lòng đăng nhập lại.',
      );
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _error = null;
    notifyListeners();
    try {
      await _provisionAndActivate(account, kiosk);
      return true;
    } on ApiException catch (error) {
      _clearPendingKioskSelection();
      _error = error;
      return false;
    } on Object {
      _clearPendingKioskSelection();
      _error = const ApiException(
        type: ApiErrorType.unknown,
        message: 'Không thể liên kết tablet với kiosk. Vui lòng thử lại.',
      );
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void cancelKioskSelection() {
    final refreshToken = _pendingAccount?.refreshToken;
    _clearPendingKioskSelection();
    _error = null;
    notifyListeners();
    if (refreshToken != null) {
      unawaited(_revokeManagerSession(refreshToken));
    }
  }

  Future<void> logout() async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    _error = null;
    notifyListeners();
    try {
      await _registrationStore.clearRegistration();
      await _legacySessionStore.clear();
      _sessionManager.clearIdentity();
      _clearPendingKioskSelection();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<ManagedKiosk?> _resolveKiosk(
    AuthenticatedAccountResult account,
  ) async {
    final managerRoles = account.roles
        .where((role) => role.roleCode.toLowerCase() == 'manager')
        .toList(growable: false);
    if (managerRoles.isEmpty) {
      throw const ApiException(
        type: ApiErrorType.unauthorized,
        statusCode: 403,
        message: 'Tài khoản này không có quyền Manager để thiết lập kiosk.',
      );
    }
    if (managerRoles.length > 1) {
      throw const ApiException(
        type: ApiErrorType.validation,
        message:
            'Tài khoản Manager đang được gán nhiều điểm bán. Vui lòng liên hệ quản trị viên.',
      );
    }

    final role = managerRoles.single;
    final roleKioskId = role.kioskId?.trim();
    final storeId = role.storeId?.trim();
    if (roleKioskId != null && roleKioskId.isNotEmpty) {
      return ManagedKiosk(id: roleKioskId, storeId: storeId ?? '');
    }
    if (storeId == null || storeId.isEmpty) {
      throw const ApiException(
        type: ApiErrorType.validation,
        message:
            'Tài khoản Manager chưa được gán điểm bán hoặc kiosk. Vui lòng kiểm tra cấu hình tài khoản.',
      );
    }

    final kiosks = await _repository.listKiosksForStore(
      accessToken: account.accessToken,
      storeId: storeId,
    );
    final matching = kiosks
        .where(
          (candidate) =>
              candidate.storeId.isEmpty || candidate.storeId == storeId,
        )
        .toList(growable: false);
    if (matching.isEmpty) {
      throw const ApiException(
        type: ApiErrorType.notFound,
        statusCode: 404,
        message: 'Điểm bán của Manager chưa có kiosk được cấu hình.',
      );
    }
    if (matching.length > 1) {
      _pendingAccount = account;
      _pendingManagerRole = role;
      _availableKiosks = matching;
      return null;
    }
    return matching.single;
  }

  Future<void> _provisionAndActivate(
    AuthenticatedAccountResult account,
    ManagedKiosk kiosk,
  ) async {
    try {
      final pending = await _registrationStore.readOrCreatePendingProvision();
      final device = await _repository.configureClientDevice(
        accessToken: account.accessToken,
        kiosk: kiosk,
        pending: pending,
      );
      await _registrationStore.completeProvision(device.id, pending);
      final identity = await _sessionManager.ensureSession(force: true);
      if (identity == null || identity.kioskId != kiosk.id) {
        await _registrationStore.clearRegistration();
        _sessionManager.clearIdentity();
        throw const ApiException(
          type: ApiErrorType.conflict,
          statusCode: 409,
          message: 'Định danh tablet không khớp với kiosk đã chọn.',
        );
      }
      _clearPendingKioskSelection();
    } finally {
      await _revokeManagerSession(account.refreshToken);
    }
  }

  Future<void> _revokeManagerSession(String refreshToken) async {
    if (refreshToken.trim().isEmpty) return;
    try {
      await _repository.revoke(refreshToken);
    } on Object {
      // Manager credentials are never persisted; a transient revoke failure
      // must not undo a successfully provisioned device.
    }
  }

  ApiException _presentLoginError(ApiException error) {
    if (error.statusCode == 401) {
      return const ApiException(
        type: ApiErrorType.unauthorized,
        statusCode: 401,
        message: 'Tài khoản hoặc mật khẩu không chính xác.',
      );
    }
    return error;
  }

  void _clearPendingKioskSelection() {
    _pendingAccount = null;
    _pendingManagerRole = null;
    _availableKiosks = const [];
  }

  void _handleRuntimeSessionChanged() => notifyListeners();

  @override
  void dispose() {
    _sessionManager.removeListener(_handleRuntimeSessionChanged);
    super.dispose();
  }
}
