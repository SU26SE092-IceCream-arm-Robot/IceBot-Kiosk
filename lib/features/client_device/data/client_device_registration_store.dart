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
    final clientDeviceId = map['clientDeviceId'] as String?;
    final installationId = map['installationId'] as String?;
    final credential = map['credential'] as String?;
    if (!_isUuid(clientDeviceId) ||
        !_isUuid(installationId) ||
        !_isCredential(credential)) {
      return null;
    }
    return ClientDeviceRegistration(
      clientDeviceId: clientDeviceId!,
      installationId: installationId!,
      credential: credential!,
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
    if (!_isUuid(installationId) ||
        !_isCredential(credential) ||
        !_isUuid(idempotencyKey)) {
      return null;
    }
    return PendingClientDeviceProvision(
      installationId: installationId!,
      credential: credential!,
      idempotencyKey: idempotencyKey!,
    );
  }
}

class ClientDeviceRegistrationStore {
  ClientDeviceRegistrationStore(this._storage);

  static const registrationKey = 'icebot.client-device.registration.v1';
  static const pendingProvisionKey =
      'icebot.client-device.pending-provision.v1';

  final FlutterSecureStorage _storage;

  Future<ClientDeviceRegistration?> readRegistration() async =>
      ClientDeviceRegistration.fromJson(await _readJson(registrationKey));

  Future<PendingClientDeviceProvision> readOrCreatePendingProvision() async {
    final existing = PendingClientDeviceProvision.fromJson(
      await _readJson(pendingProvisionKey),
    );
    if (existing != null) return existing;

    final pending = PendingClientDeviceProvision(
      installationId: _newUuid(),
      credential: base64Encode(_randomBytes(32)),
      idempotencyKey: _newUuid(),
    );
    await _writeJson(pendingProvisionKey, pending.toJson());
    return pending;
  }

  Future<void> completeProvision(
    String clientDeviceId,
    PendingClientDeviceProvision pending,
  ) async {
    if (!_isUuid(clientDeviceId)) {
      throw ArgumentError.value(
        clientDeviceId,
        'clientDeviceId',
        'Must be a UUID.',
      );
    }
    await _writeJson(
      registrationKey,
      ClientDeviceRegistration(
        clientDeviceId: clientDeviceId,
        installationId: pending.installationId,
        credential: pending.credential,
      ).toJson(),
    );
    await _storage.delete(key: pendingProvisionKey);
  }

  Future<void> clearRegistration() async {
    await _storage.delete(key: registrationKey);
    await _storage.delete(key: pendingProvisionKey);
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

String _newUuid() {
  final bytes = _randomBytes(16);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

bool _isUuid(String? value) =>
    value != null &&
    RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);

bool _isCredential(String? value) {
  if (value == null || value.trim().isEmpty) return false;
  final normalized = value.trim();
  if (!RegExp(r'^[A-Za-z0-9+/]{43}=$').hasMatch(normalized)) return false;
  try {
    final bytes = base64Decode(normalized);
    return bytes.length == 32 && base64Encode(bytes) == normalized;
  } on FormatException {
    return false;
  }
}
