import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/payment_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/runtime_menu_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/menu_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/order_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/payment_repository.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/screens/payment_screen.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_controller.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';

void main() {
  testWidgets(
    'backend-confirmed payment navigates to tracking, not fake success',
    (tester) async {
      final controller = KioskController(
        menuRepository: _NavigationMenuRepository(),
        orderRepository: _NavigationOrderRepository(),
        paymentRepository: _NavigationPaymentRepository(),
        kioskId: 'kiosk-id',
      );
      await controller.loadMenu();
      controller.addToCart(controller.menuItems.single);
      expect(await controller.checkout(), isNotNull);

      final router = GoRouter(
        initialLocation: '/payment/order-id',
        routes: [
          GoRoute(
            path: '/payment/:orderId',
            builder: (context, state) =>
                PaymentScreen(orderId: state.pathParameters['orderId'] ?? ''),
          ),
          GoRoute(
            path: '/orders/:orderId',
            builder: (context, state) =>
                const Scaffold(body: Text('ORDER_TRACKING_TEST')),
          ),
          GoRoute(
            path: '/success',
            builder: (context, state) =>
                const Scaffold(body: Text('FAKE_SUCCESS_TEST')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        KioskScope(
          controller: controller,
          disposeController: false,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ORDER_TRACKING_TEST'), findsOneWidget);
      expect(find.text('FAKE_SUCCESS_TEST'), findsNothing);
      expect(controller.activeOrder?.status, OrderStatus.readyForExecution);
    },
  );
}

class _NavigationMenuRepository extends MenuRepository {
  _NavigationMenuRepository() : super(DioClient(baseUrl: 'http://localhost'));

  @override
  Future<RuntimeMenuResult> getRuntimeMenu(String kioskId) async {
    return RuntimeMenuResult(
      snapshotId: 'snapshot-id',
      kioskId: kioskId,
      generatedAt: DateTime.utc(2026, 7, 1),
      expiresAt: DateTime.utc(2026, 7, 1, 0, 5),
      availabilitySource: 'CloudSalesCatalog',
      containsMachineRuntimeState: false,
      items: const [
        RuntimeMenuItem(
          menuId: 'menu-id',
          menuItemId: 'menu-item-id',
          productId: 'product-id',
          productVariantId: 'variant-id',
          menuItemCode: 'MI-001',
          productCode: 'P-001',
          productVariantCode: 'V-001',
          displayName: 'Kem vani',
          price: 35000,
          discountAmount: 0,
          finalPrice: 35000,
          currency: 'VND',
        ),
      ],
    );
  }
}

class _NavigationOrderRepository extends OrderRepository {
  _NavigationOrderRepository() : super(DioClient(baseUrl: 'http://localhost'));

  @override
  Future<OrderResult> createOrder(CreateOrderRequest request) async {
    return _order(OrderStatus.pendingPayment, PaymentStatus.unpaid);
  }

  @override
  Future<PaymentStatusResult> getPaymentStatus(String orderId) async {
    return PaymentStatusResult(
      paymentTransactionId: 'payment-id',
      orderId: orderId,
      provider: 'PayOS',
      paymentTransactionStatus: PaymentTransactionStatus.paid,
      orderPaymentStatus: PaymentStatus.paid,
      orderStatus: OrderStatus.paid,
      amount: 35000,
      paidAmount: 35000,
      currency: 'VND',
      paidAt: DateTime.utc(2026, 7, 1, 10),
      customerStatus: 'Preparing',
      customerStatusMessage: 'Payment successful.',
      canRetryPayment: false,
      requiresStaffSupport: false,
    );
  }

  @override
  Future<OrderResult> getOrder(String orderId) async {
    return _order(OrderStatus.readyForExecution, PaymentStatus.paid);
  }
}

class _NavigationPaymentRepository extends PaymentRepository {
  _NavigationPaymentRepository()
    : super(DioClient(baseUrl: 'http://localhost'));

  @override
  Future<PaymentSessionResult> createPaymentSession(
    String orderId, {
    String? idempotencyKey,
    String? description,
  }) async {
    return PaymentSessionResult(
      paymentTransactionId: 'payment-id',
      orderId: orderId,
      transactionNumber: 'PAY-001',
      provider: 'PayOS',
      qrCodePayload: 'PAYLOAD-001',
      amount: 35000,
      currency: 'VND',
      status: PaymentTransactionStatus.pending,
    );
  }
}

OrderResult _order(OrderStatus status, PaymentStatus paymentStatus) {
  return OrderResult(
    id: 'order-id',
    kioskId: 'kiosk-id',
    orderNumber: 'ORD-001',
    channel: 'Tablet',
    status: status,
    paymentStatus: paymentStatus,
    currency: 'VND',
    subtotalAmount: 35000,
    discountAmount: 0,
    taxAmount: 0,
    totalAmount: 35000,
    paidAmount: paymentStatus == PaymentStatus.paid ? 35000 : 0,
    placedAt: DateTime.utc(2026, 7, 1, 9, 55),
    customerStatus: status.name,
    customerStatusMessage: '',
    canRetryPayment: status == OrderStatus.pendingPayment,
    requiresStaffSupport: false,
    items: const [],
  );
}
