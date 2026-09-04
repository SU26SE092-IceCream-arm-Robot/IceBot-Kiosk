import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:icebot_kiosk/features/setup/data/models/auth_models.dart';

abstract class AuthSessionStore {
  Future<KioskAuthSession?> read();

  Future<void> write(KioskAuthSession session);

  Future<void> clear();
}

class SecureAuthSessionStore implements AuthSessionStore {
  SecureAuthSessionStore(this._storage);

  static const String storageKey = 'icebot.kiosk.managerSession.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<KioskAuthSession?> read() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['schemaVersion'] != 1) {
        await clear();
        return null;
      }
      final session = KioskAuthSession.fromJson(decoded);
      if (!session.isValid) {
        await clear();
        return null;
      }
      return session;
    } on Object {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(KioskAuthSession session) {
    return _storage.write(key: storageKey, value: jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() => _storage.delete(key: storageKey);
}

class MemoryAuthSessionStore implements AuthSessionStore {
  KioskAuthSession? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<KioskAuthSession?> read() async => value;

  @override
  Future<void> write(KioskAuthSession session) async => value = session;
}
