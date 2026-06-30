import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/payment_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/runtime_menu_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/menu_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/order_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/payment_repository.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_controller.dart';

void main() {
  test('cart supports add, quantity changes, remove, and clear', () {
    final controller = KioskController(
      menuRepository: _FakeMenuRepository(),
      orderRepository: _FakeOrderRepository(),
      paymentRepository: _FakePaymentRepository(),
    );

    controller.addToCart(_menuItem(), quantity: 2);
    expect(controller.cartItemCount, 2);
    expect(controller.cartTotal, 70000);

    controller.increaseQuantity('menu-item-id');
    expect(controller.cartItemCount, 3);
    expect(controller.cartTotal, 105000);

    controller.decreaseQuantity('menu-item-id');
    expect(controller.cartItemCount, 2);

    controller.removeFromCart('menu-item-id');
    expect(controller.isCartEmpty, isTrue);

    controller.addToCart(_menuItem());
    controller.clearCart();
    expect(controller.isCartEmpty, isTrue);
  });

  test('retains created order when payment session creation fails', () async {
    final orderRepository = _RecordingOrderRepository();
    final paymentRepository = _FlakyPaymentRepository(failures: 1);
    final controller = _checkoutController(
      orderRepository: orderRepository,
      paymentRepository: paymentRepository,
    );

    await controller.loadMenu();
    controller.addToCart(_menuItem());

    final result = await controller.checkout();

    expect(result, isNull);
    expect(controller.activeOrder?.id, 'order-id');
    expect(controller.isCartEmpty, isFalse);
    expect(controller.checkoutError?.type, ApiErrorType.upstream);
    expect(orderRepository.createCalls, 1);
  });

  test('payment retry reuses order and does not create a duplicate', () async {
    final orderRepository = _RecordingOrderRepository();
    final paymentRepository = _FlakyPaymentRepository(failures: 1);
    final controller = _checkoutController(
      orderRepository: orderRepository,
      paymentRepository: paymentRepository,
    );

    await controller.loadMenu();
    controller.addToCart(_menuItem());
    expect(await controller.checkout(), isNull);

    final retryResult = await controller.retryPaymentSession();

    expect(retryResult?.order.id, 'order-id');
    expect(retryResult?.paymentSession.orderId, 'order-id');
    expect(orderRepository.createCalls, 1);
    expect(paymentRepository.orderIds, ['order-id', 'order-id']);
    expect(paymentRepository.idempotencyKeys, hasLength(2));
    expect(
      paymentRepository.idempotencyKeys[0],
      isNot(paymentRepository.idempotencyKeys[1]),
    );
    expect(controller.isCartEmpty, isTrue);
  });

  test(
    'order retry preserves idempotency key for the checkout intent',
    () async {
      final orderRepository = _NetworkThenSuccessOrderRepository();
      final paymentRepository = _FlakyPaymentRepository(failures: 0);
      final controller = _checkoutController(
        orderRepository: orderRepository,
        paymentRepository: paymentRepository,
      );

      await controller.loadMenu();
      controller.addToCart(_menuItem());
      expect(await controller.checkout(), isNull);

      final result = await controller.checkout();

      expect(result?.order.id, 'order-id');
      expect(orderRepository.idempotencyKeys, hasLength(2));
      expect(
        orderRepository.idempotencyKeys.first,
        orderRepository.idempotencyKeys.last,
      );
    },
  );

  test('runtime menu exposes valid backend items', () async {
    final repository = _RuntimeMenuRepository([
      _runtimeMenu(items: [_menuItem()]),
    ]);
    final controller = _menuController(repository);

    await controller.loadMenu();

    expect(controller.hasMenu, isTrue);
    expect(controller.menuError, isNull);
    expect(controller.menuItems.single.displayName, 'Kem vani');
    expect(controller.menuItems.single.finalPrice, 35000);
  });

  test('empty runtime menu remains a successful empty state', () async {
    final controller = _menuController(
      _RuntimeMenuRepository([_runtimeMenu()]),
    );

    await controller.loadMenu();

    expect(controller.hasMenu, isTrue);
    expect(controller.menuItems, isEmpty);
    expect(controller.menuError, isNull);
  });

  test('runtime menu backend error is retained for retry UI', () async {
    final controller = _menuController(
      _RuntimeMenuRepository([
        const ApiException(
          type: ApiErrorType.network,
          message: 'Không thể kết nối đến máy chủ.',
        ),
      ]),
    );

    await controller.loadMenu();

    expect(controller.hasMenu, isFalse);
    expect(controller.menuError?.type, ApiErrorType.network);
  });

  test(
    'menu refresh removes unavailable cart item and blocks stale add',
    () async {
      final repository = _RuntimeMenuRepository([
        _runtimeMenu(items: [_menuItem()]),
        _runtimeMenu(),
      ]);
      final controller = _menuController(repository);

      await controller.loadMenu();
      final staleItem = controller.menuItems.single;
      expect(controller.addToCart(staleItem), isTrue);
      expect(controller.cartItemCount, 1);

      await controller.loadMenu(force: true);

      expect(controller.menuItems, isEmpty);
      expect(controller.isCartEmpty, isTrue);
      expect(controller.addToCart(staleItem), isFalse);
    },
  );
}

KioskController _menuController(MenuRepository menuRepository) {
  return KioskController(
    menuRepository: menuRepository,
    orderRepository: _FakeOrderRepository(),
    paymentRepository: _FakePaymentRepository(),
    kioskId: 'kiosk-id',
  );
}

KioskController _checkoutController({
  required OrderRepository orderRepository,
  required _FlakyPaymentRepository paymentRepository,
}) {
  return KioskController(
    menuRepository: _CheckoutMenuRepository(),
    orderRepository: orderRepository,
    paymentRepository: paymentRepository,
    kioskId: 'kiosk-id',
  );
}

RuntimeMenuItem _menuItem() {
  return const RuntimeMenuItem(
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
  );
}

RuntimeMenuResult _runtimeMenu({List<RuntimeMenuItem> items = const []}) {
  return RuntimeMenuResult(
    snapshotId: 'snapshot-id',
    kioskId: 'kiosk-id',
    generatedAt: DateTime.utc(2026, 7, 1),
    expiresAt: DateTime.utc(2026, 7, 1, 0, 0, 15),
    availabilitySource: 'CloudSalesCatalog',
    containsMachineRuntimeState: false,
    items: items,
  );
}

class _FakeMenuRepository extends MenuRepository {
  _FakeMenuRepository() : super(DioClient(baseUrl: 'http://localhost'));
}

class _FakeOrderRepository extends OrderRepository {
  _FakeOrderRepository() : super(DioClient(baseUrl: 'http://localhost'));
}

class _FakePaymentRepository extends PaymentRepository {
  _FakePaymentRepository() : super(DioClient(baseUrl: 'http://localhost'));
}

class _CheckoutMenuRepository extends MenuRepository {
  _CheckoutMenuRepository() : super(DioClient(baseUrl: 'http://localhost'));

  @override
  Future<RuntimeMenuResult> getRuntimeMenu(String kioskId) async {
    return RuntimeMenuResult(
      snapshotId: 'snapshot-id',
      kioskId: kioskId,
      generatedAt: DateTime.utc(2026, 6, 30),
      expiresAt: DateTime.utc(2026, 6, 30, 0, 5),
      availabilitySource: 'CloudSalesCatalog',
      containsMachineRuntimeState: false,
      items: [_menuItem()],
    );
  }
}

class _RuntimeMenuRepository extends MenuRepository {
  _RuntimeMenuRepository(this.responses)
    : super(DioClient(baseUrl: 'http://localhost'));

  final List<Object> responses;
  int _index = 0;

  @override
  Future<RuntimeMenuResult> getRuntimeMenu(String kioskId) async {
    final response = responses[_index++];
    if (response is ApiException) {
      throw response;
    }
    return response as RuntimeMenuResult;
  }
}

class _RecordingOrderRepository extends OrderRepository {
  _RecordingOrderRepository() : super(DioClient(baseUrl: 'http://localhost'));

  int createCalls = 0;

  @override
  Future<OrderResult> createOrder(CreateOrderRequest request) async {
    createCalls++;
    return _orderResult();
  }
}

class _FlakyPaymentRepository extends PaymentRepository {
  _FlakyPaymentRepository({required this.failures})
    : super(DioClient(baseUrl: 'http://localhost'));

  int failures;
  final List<String> orderIds = [];
  final List<String?> idempotencyKeys = [];

  @override
  Future<PaymentSessionResult> createPaymentSession(
    String orderId, {
    String? idempotencyKey,
    String? description,
  }) async {
    orderIds.add(orderId);
    idempotencyKeys.add(idempotencyKey);
    if (failures > 0) {
      failures--;
      throw const ApiException(
        type: ApiErrorType.upstream,
        statusCode: 502,
        message: 'Payment provider unavailable.',
      );
    }

    return PaymentSessionResult(
      paymentTransactionId: 'payment-id',
      orderId: orderId,
      transactionNumber: 'PAY-001',
      provider: 'PayOS',
      checkoutUrl: 'https://example.test/payment',
      qrCodePayload: 'qr-payload',
      amount: 35000,
      currency: 'VND',
      status: PaymentTransactionStatus.pending,
    );
  }
}

class _NetworkThenSuccessOrderRepository extends OrderRepository {
  _NetworkThenSuccessOrderRepository()
    : super(DioClient(baseUrl: 'http://localhost'));

  final List<String?> idempotencyKeys = [];

  @override
  Future<OrderResult> createOrder(CreateOrderRequest request) async {
    idempotencyKeys.add(request.idempotencyKey);
    if (idempotencyKeys.length == 1) {
      throw const ApiException(
        type: ApiErrorType.network,
        message: 'Connection interrupted.',
      );
    }
    return _orderResult();
  }
}

OrderResult _orderResult() {
  return OrderResult(
    id: 'order-id',
    kioskId: 'kiosk-id',
    orderNumber: 'ORD-001',
    channel: 'Tablet',
    status: OrderStatus.pendingPayment,
    paymentStatus: PaymentStatus.unpaid,
    currency: 'VND',
    subtotalAmount: 35000,
    discountAmount: 0,
    taxAmount: 0,
    totalAmount: 35000,
    paidAmount: 0,
    placedAt: DateTime.utc(2026, 6, 30),
    customerStatus: 'WaitingForPayment',
    customerStatusMessage: 'Waiting for payment.',
    canRetryPayment: true,
    requiresStaffSupport: false,
    items: const [],
  );
}
