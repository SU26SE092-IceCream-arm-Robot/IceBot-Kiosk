import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ClientDeviceRegistration {
  const ClientDeviceRegistration({
    required this.clientDeviceId,
    required this.installationId,
    required this.credential,
  });

  final String clientDeviceId;
  final String installationId;
  final String credential;

  Map<String, String> toJson() => {
    'clientDeviceId': clientDeviceId,
    'installationId': installationId,
    'credential': credential,
  };

  static ClientDeviceRegistration? fromJson(Object? value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final deviceId = map['clientDeviceId'] as String?;
    final installationId = map['installationId'] as String?;
    final credential = map['credential'] as String?;
    if (!_isGuid(deviceId) ||
        !_isGuid(installationId) ||
        credential == null ||
        credential.isEmpty) {
      return null;
    }
    return ClientDeviceRegistration(
      clientDeviceId: deviceId!,
      installationId: installationId!,
      credential: credential,
    );
  }
}

class PendingClientDeviceProvision {
  const PendingClientDeviceProvision({
    required this.installationId,
    required this.credential,
    required this.idempotencyKey,
  });

  final String installationId;
  final String credential;
  final String idempotencyKey;

  Map<String, String> toJson() => {
    'installationId': installationId,
    'credential': credential,
    'idempotencyKey': idempotencyKey,
  };

  static PendingClientDeviceProvision? fromJson(Object? value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final installationId = map['installationId'] as String?;
    final credential = map['credential'] as String?;
    final idempotencyKey = map['idempotencyKey'] as String?;
    if (!_isGuid(installationId) ||
        credential == null ||
        credential.isEmpty ||
        idempotencyKey == null ||
        idempotencyKey.isEmpty) {
      return null;
    }
    return PendingClientDeviceProvision(
      installationId: installationId!,
      credential: credential,
      idempotencyKey: idempotencyKey,
    );
  }
}

class ClientDeviceRegistrationStore {
  ClientDeviceRegistrationStore(this._storage);

  static const _registrationKey = 'icebot.client-device.registration.v1';
  static const _pendingProvisionKey =
      'icebot.client-device.pending-provision.v1';

  final FlutterSecureStorage _storage;

  Future<ClientDeviceRegistration?> readRegistration() async =>
      ClientDeviceRegistration.fromJson(await _readJson(_registrationKey));

  Future<PendingClientDeviceProvision> readOrCreatePendingProvision() async {
    final existing = PendingClientDeviceProvision.fromJson(
      await _readJson(_pendingProvisionKey),
    );
    if (existing != null) return existing;

    final pending = PendingClientDeviceProvision(
      installationId: _newGuid(),
      credential: base64UrlEncode(_randomBytes(32)),
      idempotencyKey: _newGuid(),
    );
    await _writeJson(_pendingProvisionKey, pending.toJson());
    return pending;
  }

  Future<void> completeProvision(
    String clientDeviceId,
    PendingClientDeviceProvision pending,
  ) async {
    if (!_isGuid(clientDeviceId)) {
      throw ArgumentError.value(
        clientDeviceId,
        'clientDeviceId',
        'Must be a UUID.',
      );
    }
    await _writeJson(
      _registrationKey,
      ClientDeviceRegistration(
        clientDeviceId: clientDeviceId,
        installationId: pending.installationId,
        credential: pending.credential,
      ).toJson(),
    );
    await _storage.delete(key: _pendingProvisionKey);
  }

  Future<void> clearRegistration() async {
    await _storage.delete(key: _registrationKey);
    await _storage.delete(key: _pendingProvisionKey);
  }

  Future<Object?> _readJson(String key) async {
    final raw = await _storage.read(key: key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      await _storage.delete(key: key);
      return null;
    }
  }

  Future<void> _writeJson(String key, Map<String, String> value) =>
      _storage.write(key: key, value: jsonEncode(value));
}

List<int> _randomBytes(int length) =>
    List<int>.generate(length, (_) => Random.secure().nextInt(256));

String _newGuid() {
  final bytes = _randomBytes(16);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

bool _isGuid(String? value) =>
    value != null &&
    RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
