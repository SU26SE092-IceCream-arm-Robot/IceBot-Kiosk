import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/features/setup/data/local/auth_session_store.dart';
import 'package:icebot_kiosk/features/setup/data/models/auth_models.dart';
import 'package:icebot_kiosk/features/setup/data/repositories/auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository repository,
    required AuthSessionStore sessionStore,
  }) : _repository = repository,
       _sessionStore = sessionStore;

  final AuthRepository _repository;
  final AuthSessionStore _sessionStore;

  KioskAuthSession? _session;
  AuthenticatedAccountResult? _pendingAccount;
  AccountRoleScope? _pendingManagerRole;
  List<ManagedKiosk> _availableKiosks = const [];
  ApiException? _error;
  bool _isRestoring = true;
  bool _isSubmitting = false;
  Future<String?>? _refreshInFlight;

  KioskAuthSession? get session => _session;
  ApiException? get error => _error;
  bool get isRestoring => _isRestoring;
  bool get isSubmitting => _isSubmitting;
  bool get isAuthenticated => _session?.isValid == true;
  String? get accessToken => _session?.accessToken;
  bool get requiresKioskSelection =>
      _pendingAccount != null && _pendingManagerRole != null;
  List<ManagedKiosk> get availableKiosks => _availableKiosks;

  Future<void> restore() async {
    _isRestoring = true;
    _error = null;
    notifyListeners();

    try {
      final stored = await _sessionStore.read();
      if (stored == null) {
        _session = null;
        return;
      }

      _session = stored;
      try {
        final refreshed = await _repository.refresh(stored.refreshToken);
        final next = await _createSession(refreshed, previous: stored);
        if (next == null) {
          await _clearLocalSession();
          _error = const ApiException(
            type: ApiErrorType.validation,
            message: 'Vui lòng đăng nhập lại để chọn kiosk cho máy này.',
          );
        } else {
          _session = next;
          await _sessionStore.write(next);
        }
      } on ApiException catch (error) {
        if (error.type == ApiErrorType.unauthorized) {
          await _clearLocalSession();
        } else {
          // Keep the last valid binding when the backend is temporarily offline.
          _error = error;
        }
      }
    } on Object {
      await _clearLocalSession();
      _error = const ApiException(
        type: ApiErrorType.unknown,
        message: 'Không thể khôi phục cấu hình kiosk đã lưu.',
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
    if (_isSubmitting) {
      return false;
    }
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

    try {
      final account = await _repository.login(
        emailOrUsername: emailOrUsername,
        password: password,
      );
      final next = await _createSession(account);
      if (next != null) {
        await _sessionStore.write(next);
        _session = next;
      }
      return true;
    } on ApiException catch (error) {
      _error = _presentLoginError(error);
      return false;
    } on Object {
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

  Future<String?> refreshAccessToken() {
    return _refreshInFlight ??= _refreshAccessToken().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<String?> _refreshAccessToken() async {
    final current = _session;
    if (current == null) {
      return null;
    }

    try {
      final account = await _repository.refresh(current.refreshToken);
      final next = await _createSession(account, previous: current);
      if (next == null) {
        return null;
      }
      _session = next;
      await _sessionStore.write(next);
      notifyListeners();
      return next.accessToken;
    } on ApiException catch (error) {
      if (error.type == ApiErrorType.unauthorized) {
        await _clearLocalSession();
        notifyListeners();
      }
      return null;
    }
  }

  Future<void> logout() async {
    if (_isSubmitting) {
      return;
    }
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    final refreshToken = _session?.refreshToken;
    await _clearLocalSession();
    notifyListeners();
    try {
      if (refreshToken != null && refreshToken.trim().isNotEmpty) {
        await _repository.revoke(refreshToken);
      }
    } on Object {
      // Local reset must still succeed if the revoke call cannot reach backend.
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> selectKiosk(String kioskId) async {
    if (_isSubmitting) {
      return false;
    }
    final account = _pendingAccount;
    final role = _pendingManagerRole;
    ManagedKiosk? kiosk;
    for (final candidate in _availableKiosks) {
      if (candidate.id == kioskId) {
        kiosk = candidate;
        break;
      }
    }
    if (account == null || role == null || kiosk == null) {
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
      final next = _sessionFor(account, role, kiosk);
      await _sessionStore.write(next);
      _session = next;
      _clearPendingKioskSelection();
      return true;
    } on Object {
      _error = const ApiException(
        type: ApiErrorType.unknown,
        message: 'Không thể lưu lựa chọn kiosk. Vui lòng thử lại.',
      );
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void cancelKioskSelection() {
    _clearPendingKioskSelection();
    _error = null;
    notifyListeners();
  }

  Future<KioskAuthSession?> _createSession(
    AuthenticatedAccountResult account, {
    KioskAuthSession? previous,
  }) async {
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
    ManagedKiosk? kiosk;

    if (roleKioskId != null && roleKioskId.isNotEmpty) {
      kiosk = ManagedKiosk(id: roleKioskId, storeId: storeId ?? '');
    } else if (previous != null &&
        previous.storeId == storeId &&
        previous.kioskId.trim().isNotEmpty) {
      kiosk = ManagedKiosk(
        id: previous.kioskId,
        storeId: previous.storeId ?? '',
        code: previous.kioskCode,
        name: previous.kioskName,
      );
    } else {
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
      kiosk = matching.single;
    }

    return _sessionFor(account, role, kiosk);
  }

  KioskAuthSession _sessionFor(
    AuthenticatedAccountResult account,
    AccountRoleScope role,
    ManagedKiosk kiosk,
  ) {
    return KioskAuthSession(
      accessToken: account.accessToken.trim(),
      refreshToken: account.refreshToken.trim(),
      accountId: account.id.trim(),
      userName: account.userName.trim(),
      managerName: account.fullName.trim().isNotEmpty
          ? account.fullName.trim()
          : account.userName.trim(),
      organizationId: role.organizationId,
      storeId: role.storeId?.trim(),
      kioskId: kiosk.id.trim(),
      kioskCode: kiosk.code,
      kioskName: kiosk.name,
    );
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

  Future<void> _clearLocalSession() async {
    _session = null;
    _clearPendingKioskSelection();
    await _sessionStore.clear();
  }

  void _clearPendingKioskSelection() {
    _pendingAccount = null;
    _pendingManagerRole = null;
    _availableKiosks = const [];
  }
}
