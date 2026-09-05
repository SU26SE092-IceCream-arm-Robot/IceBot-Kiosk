import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/payment_models.dart';
import 'package:icebot_kiosk/features/speech/application/kiosk_speech_service.dart';
import 'package:icebot_kiosk/features/speech/application/order_announcement_coordinator.dart';

void main() {
  test(
    'unpaid to paid announces exactly once across repeated polling',
    () async {
      final speech = _FakeSpeechService();
      final coordinator = OrderAnnouncementCoordinator(speech);
      final order = _order(status: OrderStatus.pendingPayment);

      coordinator.observePayment(
        order,
        _payment(PaymentTransactionStatus.pending),
      );
      coordinator.observePayment(
        order,
        _payment(PaymentTransactionStatus.paid),
      );
      coordinator.observePayment(
        order,
        _payment(PaymentTransactionStatus.paid),
      );
      await _flushAsyncWork();

      expect(speech.played, [OrderAnnouncementType.paymentSuccess]);
    },
  );

  test(
    'preparing to ready stays silent and completed announces once',
    () async {
      final speech = _FakeSpeechService();
      final coordinator = OrderAnnouncementCoordinator(speech);

      coordinator.observeOrder(_order(status: OrderStatus.preparing));
      coordinator.observeOrder(_order(status: OrderStatus.ready));
      coordinator.observeOrder(_order(status: OrderStatus.completed));
      coordinator.observeOrder(_order(status: OrderStatus.completed));
      await _flushAsyncWork();

      expect(speech.played, [OrderAnnouncementType.completed]);
    },
  );

  test(
    'restored paid and completed order does not replay old announcements',
    () async {
      final speech = _FakeSpeechService();
      final coordinator = OrderAnnouncementCoordinator(speech);
      final order = _order(
        status: OrderStatus.completed,
        paymentStatus: PaymentStatus.paid,
      );

      coordinator.registerRestoredOrder(order);
      coordinator.observePayment(
        order,
        _payment(PaymentTransactionStatus.paid),
      );
      coordinator.observeOrder(order);
      await _flushAsyncWork();

      expect(speech.preparedOrderIds, ['order-1']);
      expect(speech.played, isEmpty);
    },
  );

  test(
    'a speech failure is contained and is not enqueued repeatedly',
    () async {
      final speech = _FakeSpeechService(failPlayback: true);
      final coordinator = OrderAnnouncementCoordinator(speech);
      final completed = _order(status: OrderStatus.completed);

      coordinator.observeOrder(completed);
      coordinator.observeOrder(completed);
      await _flushAsyncWork();

      expect(speech.played, [OrderAnnouncementType.completed]);
    },
  );
}

Future<void> _flushAsyncWork() => Future<void>.delayed(Duration.zero);

OrderResult _order({
  required OrderStatus status,
  PaymentStatus paymentStatus = PaymentStatus.unpaid,
}) {
  return OrderResult(
    id: 'order-1',
    kioskId: 'kiosk-1',
    orderNumber: 'ORD-001',
    channel: 'Tablet',
    status: status,
    paymentStatus: paymentStatus,
    currency: 'VND',
    subtotalAmount: 10000,
    discountAmount: 0,
    taxAmount: 0,
    totalAmount: 10000,
    paidAmount: paymentStatus == PaymentStatus.paid ? 10000 : 0,
    placedAt: DateTime.utc(2026),
    customerStatus: '',
    customerStatusMessage: '',
    canRetryPayment: false,
    requiresStaffSupport: false,
    items: const [],
  );
}

PaymentStatusResult _payment(PaymentTransactionStatus status) {
  return PaymentStatusResult(
    paymentTransactionId: 'payment-1',
    orderId: 'order-1',
    provider: 'payos',
    paymentTransactionStatus: status,
    orderPaymentStatus: status == PaymentTransactionStatus.paid
        ? PaymentStatus.paid
        : PaymentStatus.unpaid,
    orderStatus: status == PaymentTransactionStatus.paid
        ? OrderStatus.paid
        : OrderStatus.pendingPayment,
    amount: 10000,
    currency: 'VND',
    customerStatus: '',
    customerStatusMessage: '',
    canRetryPayment: false,
    requiresStaffSupport: false,
  );
}

class _FakeSpeechService implements KioskSpeechService {
  _FakeSpeechService({this.failPlayback = false});

  final bool failPlayback;
  final List<String> preparedOrderIds = [];
  final List<OrderAnnouncementType> played = [];

  @override
  SpeechDiagnostics get diagnostics =>
      const SpeechDiagnostics(status: SpeechEngineStatus.ready);

  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> prepareOrder({
    required String orderId,
    required String orderNumber,
  }) async {
    preparedOrderIds.add(orderId);
  }

  @override
  Future<SpeechPlaybackResult> playOrderAnnouncement({
    required String orderId,
    required String orderNumber,
    required OrderAnnouncementType type,
    bool forceRegenerate = false,
  }) async {
    played.add(type);
    if (failPlayback) {
      throw StateError('speaker unavailable');
    }
    return const SpeechPlaybackResult(success: true);
  }
}
