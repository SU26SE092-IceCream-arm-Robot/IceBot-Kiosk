import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderRecoveryRecord {
  const OrderRecoveryRecord({
    required this.orderId,
    required this.kioskId,
    required this.orderStatus,
    required this.paymentStatus,
    required this.savedAt,
    required this.recoveryExpiresAt,
    this.paymentExpiresAt,
    this.orderAccessToken,
  });

  final String orderId;
  final String kioskId;
  final OrderStatus orderStatus;
  final PaymentStatus paymentStatus;
  final DateTime savedAt;
  final DateTime recoveryExpiresAt;
  final DateTime? paymentExpiresAt;
  final String? orderAccessToken;

  bool isExpiredAt(DateTime now) => !now.isBefore(recoveryExpiresAt);

  bool get isTerminal => _isTerminalStatus(orderStatus);

  OrderRecoveryRecord copyWith({String? orderAccessToken}) {
    return OrderRecoveryRecord(
      orderId: orderId,
      kioskId: kioskId,
      orderStatus: orderStatus,
      paymentStatus: paymentStatus,
      savedAt: savedAt,
      recoveryExpiresAt: recoveryExpiresAt,
      paymentExpiresAt: paymentExpiresAt,
      orderAccessToken: orderAccessToken ?? this.orderAccessToken,
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'orderId': orderId,
    'kioskId': kioskId,
    'orderStatus': orderStatus.name,
    'paymentStatus': paymentStatus.name,
    'savedAt': savedAt.toUtc().toIso8601String(),
    'recoveryExpiresAt': recoveryExpiresAt.toUtc().toIso8601String(),
    if (paymentExpiresAt != null)
      'paymentExpiresAt': paymentExpiresAt!.toUtc().toIso8601String(),
  };

  static OrderRecoveryRecord? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }

    final map = Map<String, dynamic>.from(value);
    if (map['schemaVersion'] != 1) {
      return null;
    }

    final orderId = map['orderId'] as String?;
    final kioskId = map['kioskId'] as String?;
    final savedAt = DateTime.tryParse(map['savedAt'] as String? ?? '');
    final recoveryExpiresAt = DateTime.tryParse(
      map['recoveryExpiresAt'] as String? ?? '',
    );
    final orderStatus = _readOrderStatus(map['orderStatus']);
    final paymentStatus = _readPaymentStatus(map['paymentStatus']);
    if (orderId == null ||
        orderId.trim().isEmpty ||
        kioskId == null ||
        kioskId.trim().isEmpty ||
        savedAt == null ||
        recoveryExpiresAt == null ||
        orderStatus == null ||
        paymentStatus == null) {
      return null;
    }

    return OrderRecoveryRecord(
      orderId: orderId,
      kioskId: kioskId,
      orderStatus: orderStatus,
      paymentStatus: paymentStatus,
      savedAt: savedAt,
      recoveryExpiresAt: recoveryExpiresAt,
      paymentExpiresAt: DateTime.tryParse(
        map['paymentExpiresAt'] as String? ?? '',
      ),
    );
  }
}

abstract class OrderRecoveryStore {
  Future<void> save(
    OrderResult order, {
    String? orderAccessToken,
    DateTime? paymentExpiresAt,
  });

  Future<OrderRecoveryRecord?> read(String kioskId);

  Future<void> clear();
}

abstract class OrderAccessTokenStore {
  Future<void> write(String token);

  Future<String?> read();

  Future<void> clear();
}

class SecureOrderAccessTokenStore implements OrderAccessTokenStore {
  SecureOrderAccessTokenStore(this._storage);

  static const String storageKey = 'icebot.kiosk.orderAccessToken.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String token) =>
      _storage.write(key: storageKey, value: token);

  @override
  Future<String?> read() => _storage.read(key: storageKey);

  @override
  Future<void> clear() => _storage.delete(key: storageKey);
}

class SharedPreferencesOrderRecoveryStore implements OrderRecoveryStore {
  SharedPreferencesOrderRecoveryStore(
    this._preferences, {
    required OrderAccessTokenStore tokenStore,
    DateTime Function()? clock,
    this.retention = const Duration(hours: 24),
  }) : _tokenStore = tokenStore,
       _clock = clock ?? DateTime.now;

  static const String storageKey = 'icebot.kiosk.activeOrder.v1';

  final SharedPreferences _preferences;
  final OrderAccessTokenStore _tokenStore;
  final DateTime Function() _clock;
  final Duration retention;

  @override
  Future<void> save(
    OrderResult order, {
    String? orderAccessToken,
    DateTime? paymentExpiresAt,
  }) async {
    if (_isTerminalStatus(order.status)) {
      await clear();
      return;
    }

    final now = _clock().toUtc();
    final record = OrderRecoveryRecord(
      orderId: order.id,
      kioskId: order.kioskId,
      orderStatus: order.status,
      paymentStatus: order.paymentStatus,
      savedAt: now,
      recoveryExpiresAt: now.add(retention),
      paymentExpiresAt: paymentExpiresAt,
    );
    await _preferences.setString(storageKey, jsonEncode(record.toJson()));
    final token = orderAccessToken?.trim();
    if (token != null && token.isNotEmpty) {
      await _tokenStore.write(token);
    }
  }

  @override
  Future<OrderRecoveryRecord?> read(String kioskId) async {
    final raw = _preferences.getString(storageKey);
    if (raw == null) {
      return null;
    }

    try {
      final record = OrderRecoveryRecord.fromJson(jsonDecode(raw));
      final invalid =
          record == null ||
          record.kioskId != kioskId ||
          record.isTerminal ||
          record.isExpiredAt(_clock());
      if (invalid) {
        await clear();
        return null;
      }
      final token = await _tokenStore.read();
      if (token == null || token.trim().isEmpty) {
        await clear();
        return null;
      }
      return record.copyWith(orderAccessToken: token.trim());
    } on Object {
      await clear();
      return null;
    }
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(storageKey);
    await _tokenStore.clear();
  }
}

class NoopOrderRecoveryStore implements OrderRecoveryStore {
  const NoopOrderRecoveryStore();

  @override
  Future<void> save(
    OrderResult order, {
    String? orderAccessToken,
    DateTime? paymentExpiresAt,
  }) async {}

  @override
  Future<OrderRecoveryRecord?> read(String kioskId) async => null;

  @override
  Future<void> clear() async {}
}

bool _isTerminalStatus(OrderStatus status) {
  return switch (status) {
    OrderStatus.completed ||
    OrderStatus.cancelled ||
    OrderStatus.failed ||
    OrderStatus.executionRejected ||
    OrderStatus.refundRequired ||
    OrderStatus.refunded ||
    OrderStatus.compensated => true,
    _ => false,
  };
}

OrderStatus? _readOrderStatus(Object? value) {
  return OrderStatus.values.cast<OrderStatus?>().firstWhere(
    (status) => status?.name == value,
    orElse: () => null,
  );
}

PaymentStatus? _readPaymentStatus(Object? value) {
  return PaymentStatus.values.cast<PaymentStatus?>().firstWhere(
    (status) => status?.name == value,
    orElse: () => null,
  );
}
