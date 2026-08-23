import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/features/client_device/data/client_device_registration_store.dart';

class ClientDeviceRuntimeIdentity {
  const ClientDeviceRuntimeIdentity({
    required this.clientDeviceId,
    required this.kioskId,
    required this.accessToken,
    required this.expiresAt,
  });

  final String clientDeviceId;
  final String kioskId;
  final String accessToken;
  final DateTime expiresAt;

  bool get isUsable => DateTime.now().toUtc().isBefore(
    expiresAt.subtract(const Duration(minutes: 1)),
  );
}

class ClientDeviceSessionManager extends ChangeNotifier {
  ClientDeviceSessionManager(this._api, this._registrations);

  final Dio _api;
  final ClientDeviceRegistrationStore _registrations;
  ClientDeviceRuntimeIdentity? _identity;
  Future<ClientDeviceRuntimeIdentity?>? _pendingExchange;

  ClientDeviceRuntimeIdentity? get identity => _identity;
  String? get kioskId => _identity?.kioskId;
  bool get hasRegistration => _identity != null;

  Future<ClientDeviceRuntimeIdentity?> ensureSession({bool force = false}) {
    final current = _identity;
    if (!force && current != null && current.isUsable) {
      return Future.value(current);
    }
    return _pendingExchange ??= _exchange().whenComplete(
      () => _pendingExchange = null,
    );
  }

  Future<ClientDeviceRuntimeIdentity?> _exchange() async {
    final registration = await _registrations.readRegistration();
    if (registration == null) {
      _setIdentity(null);
      return null;
    }

    try {
      final response = await _api.post<dynamic>(
        '/api/v1/client-device-sessions',
        data: {
          'clientDeviceId': registration.clientDeviceId,
          'installationId': registration.installationId,
          'credential': registration.credential,
          'appVersion': AppConfig.appVersion,
          'platform': defaultTargetPlatform.name,
        },
        options: Options(
          headers: {'X-Client-Device-Id': registration.clientDeviceId},
        ),
      );
      final data = _readData(response.data);
      final device = Map<String, dynamic>.from(data['device'] as Map);
      final identity = ClientDeviceRuntimeIdentity(
        clientDeviceId: registration.clientDeviceId,
        kioskId: device['kioskId'] as String? ?? '',
        accessToken: data['accessToken'] as String? ?? '',
        expiresAt: DateTime.parse(data['expiresAt'] as String).toUtc(),
      );
      if (identity.kioskId.isEmpty || identity.accessToken.isEmpty) {
        throw const ApiException(
          type: ApiErrorType.unknown,
          message: 'Phan hoi xac thuc tablet khong hop le.',
        );
      }
      _setIdentity(identity);
      return identity;
    } on DioException catch (error) {
      _setIdentity(null);
      throw ApiException.fromDio(error);
    }
  }

  Future<ClientDeviceRuntimeIdentity?> refreshAfterUnauthorized() {
    _setIdentity(null);
    return ensureSession(force: true);
  }

  void _setIdentity(ClientDeviceRuntimeIdentity? value) {
    if (identical(_identity, value)) return;
    _identity = value;
    notifyListeners();
  }
}

Map<String, dynamic> _readData(Object? response) {
  if (response is! Map) {
    throw const ApiException(
      type: ApiErrorType.unknown,
      message: 'Phan hoi may chu khong hop le.',
    );
  }
  final envelope = Map<String, dynamic>.from(response);
  final data = envelope['data'];
  if (envelope['succeeded'] != true || data is! Map) {
    throw const ApiException(
      type: ApiErrorType.unauthorized,
      statusCode: 401,
      message: 'Tablet chua duoc cap quyen.',
    );
  }
  return Map<String, dynamic>.from(data);
}

class ClientDeviceAuthInterceptor extends Interceptor {
  ClientDeviceAuthInterceptor(this._runtimeDio, this._sessions);

  final Dio _runtimeDio;
  final ClientDeviceSessionManager _sessions;

  bool _isRuntime(RequestOptions options) =>
      options.path.startsWith('/api/v1/runtime/');

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isRuntime(options)) return handler.next(options);
    try {
      final identity = await _sessions.ensureSession();
      if (identity == null) {
        return handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: options, statusCode: 401),
          ),
        );
      }
      options.headers['Authorization'] = 'Bearer ${identity.accessToken}';
      handler.next(options);
    } on Object catch (error) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (!_isRuntime(options) ||
        err.response?.statusCode != 401 ||
        options.extra['clientDeviceRetry'] == true) {
      return handler.next(err);
    }
    try {
      final identity = await _sessions.refreshAfterUnauthorized();
      if (identity == null) return handler.next(err);
      final retry = options.copyWith(
        headers: {
          ...options.headers,
          'Authorization': 'Bearer ${identity.accessToken}',
        },
        extra: {...options.extra, 'clientDeviceRetry': true},
      );
      handler.resolve(await _runtimeDio.fetch<dynamic>(retry));
    } on Object {
      handler.next(err);
    }
  }
}
