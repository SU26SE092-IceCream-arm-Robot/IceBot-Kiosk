import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/features/client_device/data/client_device_registration_store.dart';

class SetupKiosk {
  const SetupKiosk({required this.id, required this.name, required this.code});

  final String id;
  final String name;
  final String code;
}

class ManagerSetupSession {
  const ManagerSetupSession({
    required this.accessToken,
    required this.refreshToken,
    required this.kiosks,
  });

  final String accessToken;
  final String refreshToken;
  final List<SetupKiosk> kiosks;
}

class ClientDeviceSetupService {
  ClientDeviceSetupService(this._api, this._registrations);

  final Dio _api;
  final ClientDeviceRegistrationStore _registrations;

  Future<ManagerSetupSession> signIn(
    String emailOrUsername,
    String password,
  ) async {
    String? issuedRefreshToken;
    try {
      final login = await _api.post<dynamic>(
        '/api/v1/authentication/login',
        data: {'emailOrUsername': emailOrUsername.trim(), 'password': password},
      );
      final loginData = _data(login.data);
      final accessToken = loginData['accessToken'] as String? ?? '';
      final refreshToken = loginData['refreshToken'] as String? ?? '';
      if (accessToken.isEmpty || refreshToken.isEmpty) {
        throw const ApiException(
          type: ApiErrorType.unauthorized,
          statusCode: 401,
          message: 'Tai khoan khong the thiet lap tablet.',
        );
      }
      issuedRefreshToken = refreshToken;
      final kiosksResponse = await _api.get<dynamic>(
        '/api/v1/management/kiosks',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final kiosks = (_data(kiosksResponse.data) as List)
          .whereType<Map>()
          .map((value) {
            final map = Map<String, dynamic>.from(value);
            return SetupKiosk(
              id: map['id'] as String? ?? '',
              name: map['name'] as String? ?? '',
              code: map['code'] as String? ?? '',
            );
          })
          .where((kiosk) => kiosk.id.isNotEmpty)
          .toList(growable: false);
      return ManagerSetupSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        kiosks: kiosks,
      );
    } on DioException catch (error) {
      if (issuedRefreshToken != null) {
        await _revokeRefreshToken(issuedRefreshToken);
      }
      throw ApiException.fromDio(error);
    } on Object {
      if (issuedRefreshToken != null) {
        await _revokeRefreshToken(issuedRefreshToken);
      }
      rethrow;
    }
  }

  Future<bool> provision(
    ManagerSetupSession session,
    SetupKiosk kiosk, {
    required String displayName,
  }) async {
    var revokeSucceeded = false;
    try {
      final pending = await _registrations.readOrCreatePendingProvision();
      final response = await _provisionOrReplace(
        session,
        kiosk,
        pending,
        displayName: displayName,
      );
      final data = _data(response.data);
      final clientDeviceId = data['id'] as String? ?? '';
      if (clientDeviceId.isEmpty) {
        throw const ApiException(
          type: ApiErrorType.unknown,
          message: 'May chu khong tra ve dinh danh tablet.',
        );
      }
      await _registrations.completeProvision(clientDeviceId, pending);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } finally {
      // The setup account is never persisted. A failed revoke is surfaced to
      // the operator but does not undo a completed device provisioning.
      revokeSucceeded = await revoke(session);
    }
    return revokeSucceeded;
  }

  Future<Response<dynamic>> _provisionOrReplace(
    ManagerSetupSession session,
    SetupKiosk kiosk,
    PendingClientDeviceProvision pending, {
    required String displayName,
  }) async {
    final headers = {
      'Authorization': 'Bearer ${session.accessToken}',
      'Idempotency-Key': pending.idempotencyKey,
    };
    final registration = await _registrations.readRegistration();
    final payload = {
      'credential': pending.credential,
      'displayName': displayName.trim(),
      'appVersion': AppConfig.appVersion,
      'platform': defaultTargetPlatform.name,
      'reason': 'Tablet customer runtime setup',
    };

    if (registration == null) {
      return _api.post<dynamic>(
        '/api/v1/management/kiosks/${kiosk.id}/client-devices',
        data: {'installationId': pending.installationId, ...payload},
        options: Options(headers: headers),
      );
    }

    final existingResponse = await _api.get<dynamic>(
      '/api/v1/management/client-devices/${registration.clientDeviceId}',
      options: Options(headers: headers),
    );
    final existing = _data(existingResponse.data);
    if (existing['kioskId'] != kiosk.id) {
      throw const ApiException(
        type: ApiErrorType.conflict,
        statusCode: 409,
        message:
            'Tablet nay dang duoc gan voi kiosk khac. Hay rebind tu he thong quan tri truoc.',
      );
    }

    if (existing['status'] == 'Retired') {
      return _api.post<dynamic>(
        '/api/v1/management/kiosks/${kiosk.id}/client-devices',
        data: {'installationId': pending.installationId, ...payload},
        options: Options(headers: headers),
      );
    }

    return _api.post<dynamic>(
      '/api/v1/management/kiosks/${kiosk.id}/client-devices/replace',
      data: {
        'expectedCurrentClientDeviceId': registration.clientDeviceId,
        'expectedCurrentRevision': existing['revision'],
        'replacementInstallationId': pending.installationId,
        ...payload,
      },
      options: Options(headers: headers),
    );
  }

  Future<bool> revoke(ManagerSetupSession session) =>
      _revokeRefreshToken(session.refreshToken);

  Future<bool> _revokeRefreshToken(String refreshToken) async {
    if (refreshToken.isEmpty) return true;
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        await _api.post<dynamic>(
          '/api/v1/authentication/revoke',
          data: {
            'refreshToken': refreshToken,
            'reason': 'Tablet setup session completed',
          },
        );
        return true;
      } on DioException {
        if (attempt == 2) return false;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    return false;
  }
}

dynamic _data(Object? response) {
  if (response is! Map) {
    throw const ApiException(
      type: ApiErrorType.unknown,
      message: 'Phan hoi may chu khong hop le.',
    );
  }
  final envelope = Map<String, dynamic>.from(response);
  if (envelope['succeeded'] != true) {
    throw const ApiException(
      type: ApiErrorType.unknown,
      message: 'May chu tu choi thao tac thiet lap.',
    );
  }
  return envelope['data'];
}
