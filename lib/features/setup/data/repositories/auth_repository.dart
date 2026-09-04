import 'package:dio/dio.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
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
}
