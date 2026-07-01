import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/features/kiosk/data/local/order_recovery_store.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores and restores only safe active-order recovery fields', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesOrderRecoveryStore(
      preferences,
      clock: () => DateTime.utc(2026, 7, 1, 10),
    );

    await store.save(
      _order(OrderStatus.preparing),
      paymentExpiresAt: DateTime.utc(2026, 7, 1, 10, 15),
    );

    final raw = preferences.getString(
      SharedPreferencesOrderRecoveryStore.storageKey,
    );
    expect(raw, contains('order-id'));
    expect(raw, contains('preparing'));
    expect(raw, isNot(contains('qrCodePayload')));
    expect(raw, isNot(contains('checkoutUrl')));
    expect(raw, isNot(contains('provider')));

    final restored = await store.read('kiosk-id');
    expect(restored?.orderId, 'order-id');
    expect(restored?.orderStatus, OrderStatus.preparing);
    expect(restored?.paymentStatus, PaymentStatus.paid);
  });

  test('expired recovery is cleared', () async {
    var now = DateTime.utc(2026, 7, 1, 10);
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesOrderRecoveryStore(
      preferences,
      clock: () => now,
      retention: const Duration(minutes: 30),
    );
    await store.save(_order(OrderStatus.accepted));

    now = now.add(const Duration(minutes: 31));
    expect(await store.read('kiosk-id'), isNull);
    expect(
      preferences.getString(SharedPreferencesOrderRecoveryStore.storageKey),
      isNull,
    );
  });

  test('terminal order clears recovery', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesOrderRecoveryStore(preferences);
    await store.save(_order(OrderStatus.preparing));

    await store.save(_order(OrderStatus.completed));

    expect(await store.read('kiosk-id'), isNull);
    expect(
      preferences.getString(SharedPreferencesOrderRecoveryStore.storageKey),
      isNull,
    );
  });

  test('demo no-op store never persists recovery', () async {
    const store = NoopOrderRecoveryStore();

    await store.save(_order(OrderStatus.preparing));

    expect(await store.read('kiosk-id'), isNull);
  });
}

OrderResult _order(OrderStatus status) {
  final paid = status != OrderStatus.pendingPayment;
  return OrderResult(
    id: 'order-id',
    kioskId: 'kiosk-id',
    orderNumber: 'ORD-001',
    channel: 'Tablet',
    status: status,
    paymentStatus: paid ? PaymentStatus.paid : PaymentStatus.unpaid,
    currency: 'VND',
    subtotalAmount: 35000,
    discountAmount: 0,
    taxAmount: 0,
    totalAmount: 35000,
    paidAmount: paid ? 35000 : 0,
    placedAt: DateTime.utc(2026, 7, 1, 9, 55),
    customerStatus: status.name,
    customerStatusMessage: '',
    canRetryPayment: status == OrderStatus.pendingPayment,
    requiresStaffSupport: false,
    items: const [],
  );
}
