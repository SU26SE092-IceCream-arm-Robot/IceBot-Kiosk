import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/payment_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/demo_kiosk_repositories.dart';

void main() {
  test(
    'demo repositories provide menu, order, payment, and tracking flow',
    () async {
      var now = DateTime.utc(2026, 6, 18, 10);
      final store = DemoKioskStore(clock: () => now);
      final menuRepository = DemoMenuRepository(store);
      final orderRepository = DemoOrderRepository(store);
      final paymentRepository = DemoPaymentRepository(store);

      final menu = await menuRepository.getRuntimeMenu(AppConfig.demoKioskId);
      expect(menu.items, hasLength(4));
      expect(menu.containsMachineRuntimeState, isFalse);
      expect(menu.availabilitySource, 'DemoLocalData');
      expect(menu.kioskId, AppConfig.demoKioskId);

      final item = menu.items.first;
      final order = await orderRepository.createOrder(
        CreateOrderRequest(
          kioskId: AppConfig.demoKioskId,
          runtimeSnapshotId: menu.snapshotId,
          runtimeSnapshotGeneratedAt: menu.generatedAt,
          clientTotalAmount: item.finalPrice,
          items: [
            CreateOrderItemRequest(menuItemId: item.menuItemId, quantity: 1),
          ],
        ),
      );
      expect(order.status, OrderStatus.pendingPayment);
      expect(order.totalAmount, item.finalPrice);
      expect(order.orderAccessToken, isNotEmpty);

      final session = await paymentRepository.createPaymentSession(
        order.id,
        orderAccessToken: order.orderAccessToken!,
        idempotencyKey: 'demo-payment-001',
        paymentMethodCode: 'payos',
        expectedAmount: order.totalAmount,
        expectedCurrency: order.currency,
      );
      expect(session.qrCodePayload, contains('DEMO-QR'));
      expect(session.checkoutUrl, isNull);

      var paymentStatus = await orderRepository.getPaymentStatus(
        order.id,
        orderAccessToken: order.orderAccessToken!,
      );
      expect(
        paymentStatus.paymentTransactionStatus,
        PaymentTransactionStatus.pending,
      );

      now = now.add(const Duration(seconds: 4));
      paymentStatus = await orderRepository.getPaymentStatus(
        order.id,
        orderAccessToken: order.orderAccessToken!,
      );
      expect(
        paymentStatus.paymentTransactionStatus,
        PaymentTransactionStatus.paid,
      );
      expect(paymentStatus.orderPaymentStatus, PaymentStatus.paid);

      now = now.add(const Duration(seconds: 10));
      final completedOrder = await orderRepository.getOrder(
        order.id,
        orderAccessToken: order.orderAccessToken!,
      );
      expect(completedOrder.status, OrderStatus.completed);
      expect(completedOrder.paymentStatus, PaymentStatus.paid);
    },
  );
}
