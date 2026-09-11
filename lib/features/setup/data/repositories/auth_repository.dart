import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/core/network/api_result.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/client_device/data/client_device_registration_store.dart';
import 'package:icebot_kiosk/features/setup/data/models/auth_models.dart';

class AuthRepository {
  AuthRepository(this._client);

  final DioClient _client;

  Future<AuthenticatedAccountResult> login({
    required String emailOrUsername,
    required String password,
  }) async {
    final result = await _client.postResult<AuthenticatedAccountResult>(
      '/api/v1/authentication/login',
      data: {'emailOrUsername': emailOrUsername.trim(), 'password': password},
      fromJson: AuthenticatedAccountResult.fromJson,
    );
    return _requireAccount(result.data);
  }

  Future<AuthenticatedAccountResult> refresh(String refreshToken) async {
    final result = await _client.postResult<AuthenticatedAccountResult>(
      '/api/v1/authentication/refresh',
      data: {'refreshToken': refreshToken.trim()},
      fromJson: AuthenticatedAccountResult.fromJson,
    );
    return _requireAccount(result.data);
  }

  Future<void> revoke(String refreshToken) async {
    await _client.postResult<Object?>(
      '/api/v1/authentication/revoke',
      data: {
        'refreshToken': refreshToken.trim(),
        'reason': 'Kiosk manager logged out.',
      },
      fromJson: (json) => json,
    );
  }

  Future<List<ManagedKiosk>> listKiosksForStore({
    required String accessToken,
    required String storeId,
  }) async {
    final result = await _client.getResult<List<ManagedKiosk>>(
      '/api/v1/management/kiosks',
      queryParameters: {'storeId': storeId.trim()},
      options: Options(
        headers: {'Authorization': 'Bearer ${accessToken.trim()}'},
      ),
      fromJson: _readKioskList,
    );
    return result.data ?? const [];
  }

  Future<List<ManagedClientDevice>> listClientDevicesForKiosk({
    required String accessToken,
    required String kioskId,
  }) async {
    final result = await _client.getResult<List<ManagedClientDevice>>(
      '/api/v1/management/kiosks/${kioskId.trim()}/client-devices',
      options: _managerOptions(accessToken),
      fromJson: _readClientDeviceList,
    );
    return result.data ?? const [];
  }

  Future<ManagedClientDevice> configureClientDevice({
    required String accessToken,
    required ManagedKiosk kiosk,
    required PendingClientDeviceProvision pending,
  }) async {
    final devices = await listClientDevicesForKiosk(
      accessToken: accessToken,
      kioskId: kiosk.id,
    );
    final activeTablets = devices
        .where((device) => device.isActiveSelfOrderTablet)
        .toList(growable: false);
    if (activeTablets.length > 1) {
      throw const ApiException(
        type: ApiErrorType.conflict,
        statusCode: 409,
        message:
            'Kiosk đang có nhiều liên kết tablet còn hiệu lực. Vui lòng xử lý trên trang quản trị.',
      );
    }

    final headers = {
      'Authorization': 'Bearer ${accessToken.trim()}',
      'Idempotency-Key': pending.idempotencyKey,
    };
    final displayName = _deviceDisplayName(kiosk);
    final commonPayload = <String, Object?>{
      'credential': pending.credential,
      'displayName': displayName,
      'appVersion': AppConfig.appVersion,
      'platform': defaultTargetPlatform.name,
      'reason': 'IceBot Kiosk customer runtime setup',
    };

    final ApiResult<ManagedClientDevice> result;
    if (activeTablets.isEmpty) {
      result = await _client.postResult<ManagedClientDevice>(
        '/api/v1/management/kiosks/${kiosk.id}/client-devices',
        data: {'installationId': pending.installationId, ...commonPayload},
        options: Options(headers: headers),
        fromJson: ManagedClientDevice.fromJson,
      );
    } else {
      final current = activeTablets.single;
      result = await _client.postResult<ManagedClientDevice>(
        '/api/v1/management/kiosks/${kiosk.id}/client-devices/replace',
        data: {
          'expectedCurrentClientDeviceId': current.id,
          'expectedCurrentRevision': current.revision,
          'replacementInstallationId': pending.installationId,
          ...commonPayload,
        },
        options: Options(headers: headers),
        fromJson: ManagedClientDevice.fromJson,
      );
    }

    final device = result.data;
    if (device == null || device.id.trim().isEmpty) {
      throw const ApiException(
        type: ApiErrorType.unknown,
        message: 'Máy chủ không trả về định danh tablet.',
      );
    }
    return device;
  }

  AuthenticatedAccountResult _requireAccount(
    AuthenticatedAccountResult? account,
  ) {
    if (account == null ||
        account.accessToken.trim().isEmpty ||
        account.refreshToken.trim().isEmpty ||
        account.id.trim().isEmpty) {
      throw const ApiException(
        type: ApiErrorType.unknown,
        message: 'Máy chủ không trả về phiên đăng nhập hợp lệ.',
      );
    }
    return account;
  }

  static List<ManagedKiosk> _readKioskList(Object? json) {
    final rawItems = switch (json) {
      Iterable value => value,
      Map value when value['items'] is Iterable => value['items'] as Iterable,
      _ => const <Object?>[],
    };
    return rawItems
        .map(ManagedKiosk.fromJson)
        .where((kiosk) => kiosk.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  static List<ManagedClientDevice> _readClientDeviceList(Object? json) {
    final rawItems = switch (json) {
      Iterable value => value,
      Map value when value['items'] is Iterable => value['items'] as Iterable,
      _ => const <Object?>[],
    };
    return rawItems
        .map(ManagedClientDevice.fromJson)
        .where((device) => device.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  Options _managerOptions(String accessToken) =>
      Options(headers: {'Authorization': 'Bearer ${accessToken.trim()}'});

  String _deviceDisplayName(ManagedKiosk kiosk) {
    final suffix = kiosk.code?.trim().isNotEmpty == true
        ? kiosk.code!.trim()
        : kiosk.name?.trim() ?? '';
    return suffix.isEmpty ? 'IceBot Kiosk Tablet' : 'IceBot Kiosk $suffix';
  }
}
