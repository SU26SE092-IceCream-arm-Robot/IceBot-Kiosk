import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/kiosk/data/local/order_recovery_store.dart';
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

  test('create order payload matches backend PlaceOrderRequest', () async {
    final orderRepository = _RecordingOrderRepository();
    final controller = _checkoutController(
      orderRepository: orderRepository,
      paymentRepository: _FlakyPaymentRepository(failures: 0),
    );

    await controller.loadMenu();
    controller.addToCart(_menuItem(), quantity: 2);
    final result = await controller.checkout();

    expect(result, isNotNull);
    final json = orderRepository.lastRequest!.toJson();
    expect(json['kioskId'], 'kiosk-id');
    expect(json['channel'], 'Tablet');
    expect(json['runtimeSnapshotId'], 'snapshot-id');
    expect(json['runtimeSnapshotGeneratedAt'], isNotNull);
    expect(json['clientTotalAmount'], 70000);
    expect(json['idempotencyKey'], isNotEmpty);
    expect(json['clientOrderId'], isNotEmpty);
    expect(json['items'], [
      {
        'menuItemId': 'menu-item-id',
        'clientLineId': 'line-menu-item-id',
        'quantity': 2,
      },
    ]);
  });

  test('empty cart cannot create order', () async {
    final orderRepository = _RecordingOrderRepository();
    final controller = _checkoutController(
      orderRepository: orderRepository,
      paymentRepository: _FlakyPaymentRepository(failures: 0),
    );

    await controller.loadMenu();
    final result = await controller.checkout();

    expect(result, isNull);
    expect(orderRepository.createCalls, 0);
    expect(controller.checkoutError?.type, ApiErrorType.validation);
    expect(controller.checkoutError?.message, contains('Giỏ hàng đang trống'));
  });

  test('double submit creates only one order', () async {
    final orderRepository = _BlockingOrderRepository();
    final controller = _checkoutController(
      orderRepository: orderRepository,
      paymentRepository: _FlakyPaymentRepository(failures: 0),
    );

    await controller.loadMenu();
    controller.addToCart(_menuItem());
    final firstSubmit = controller.checkout();
    await orderRepository.started.future;

    final secondSubmit = await controller.checkout();
    orderRepository.complete(_orderResult());
    final firstResult = await firstSubmit;

    expect(secondSubmit, isNull);
    expect(firstResult, isNotNull);
    expect(orderRepository.createCalls, 1);
  });

  test('checkout refresh blocks stale item before create order', () async {
    final menuRepository = _RuntimeMenuRepository([
      _runtimeMenu(items: [_menuItem()]),
      _runtimeMenu(),
    ]);
    final orderRepository = _RecordingOrderRepository();
    final controller = KioskController(
      menuRepository: menuRepository,
      orderRepository: orderRepository,
      paymentRepository: _FlakyPaymentRepository(failures: 0),
      kioskId: 'kiosk-id',
    );

    await controller.loadMenu();
    controller.addToCart(_menuItem());
    final result = await controller.checkout();

    expect(result, isNull);
    expect(orderRepository.createCalls, 0);
    expect(controller.isCartEmpty, isTrue);
    expect(controller.checkoutError?.message, contains('không còn món hợp lệ'));
  });

  test('409 total mismatch refreshes menu and stops before payment', () async {
    final refreshedItem = _menuItem(price: 40000);
    final menuRepository = _RuntimeMenuRepository([
      _runtimeMenu(items: [_menuItem()]),
      _runtimeMenu(items: [_menuItem()]),
      _runtimeMenu(items: [refreshedItem]),
    ]);
    final orderRepository = _ConflictOrderRepository();
    final paymentRepository = _FlakyPaymentRepository(failures: 0);
    final controller = KioskController(
      menuRepository: menuRepository,
      orderRepository: orderRepository,
      paymentRepository: paymentRepository,
      kioskId: 'kiosk-id',
    );

    await controller.loadMenu();
    controller.addToCart(_menuItem());
    final result = await controller.checkout();

    expect(result, isNull);
    expect(orderRepository.createCalls, 1);
    expect(paymentRepository.orderIds, isEmpty);
    expect(controller.cartTotal, 40000);
    expect(
      controller.checkoutError?.message,
      contains('Giỏ hàng đã được cập nhật'),
    );
  });

  test(
    'missing QR and checkout URL keeps order for payment recovery',
    () async {
      final orderRepository = _RecordingOrderRepository();
      final paymentRepository = _MissingPaymentAccessRepository();
      final controller = _checkoutController(
        orderRepository: orderRepository,
        paymentRepository: paymentRepository,
      );

      await controller.loadMenu();
      controller.addToCart(_menuItem());
      final result = await controller.checkout();

      expect(result, isNull);
      expect(controller.activeOrder?.id, 'order-id');
      expect(controller.activePaymentSession, isNull);
      expect(controller.isCartEmpty, isFalse);
      expect(controller.checkoutError?.message, contains('mã QR'));
      expect(orderRepository.createCalls, 1);
    },
  );

  test('uncertain payment retry reuses idempotency key and order', () async {
    final orderRepository = _RecordingOrderRepository();
    final paymentRepository = _UncertainPaymentRepository();
    final controller = _checkoutController(
      orderRepository: orderRepository,
      paymentRepository: paymentRepository,
    );

    await controller.loadMenu();
    controller.addToCart(_menuItem());
    expect(await controller.checkout(), isNull);

    final result = await controller.retryPaymentSession();

    expect(result?.order.id, 'order-id');
    expect(orderRepository.createCalls, 1);
    expect(paymentRepository.orderIds, ['order-id', 'order-id']);
    expect(paymentRepository.idempotencyKeys[0], isNotNull);
    expect(
      paymentRepository.idempotencyKeys[0],
      paymentRepository.idempotencyKeys[1],
    );
  });

  test('payment status guard prevents overlapping requests', () async {
    final orderRepository = _BlockingPaymentStatusOrderRepository();
    final controller = _checkoutController(
      orderRepository: orderRepository,
      paymentRepository: _FlakyPaymentRepository(failures: 0),
    );

    final firstPoll = controller.refreshPaymentStatus('order-id');
    await orderRepository.started.future;
    final overlappingPoll = await controller.refreshPaymentStatus('order-id');

    expect(overlappingPoll, isNull);
    expect(orderRepository.paymentStatusCalls, 1);

    orderRepository.complete(_paymentStatus());
    expect(await firstPoll, isNotNull);
    expect(controller.activePaymentStatus?.orderId, 'order-id');
  });

  test('restores a non-terminal order from safe local recovery', () async {
    final recoveryStore = _MemoryOrderRecoveryStore(
      record: _recoveryRecord(OrderStatus.accepted),
    );
    final controller = KioskController(
      menuRepository: _FakeMenuRepository(),
      orderRepository: _RestorableOrderRepository(
        _orderResult(
          status: OrderStatus.accepted,
          paymentStatus: PaymentStatus.paid,
        ),
      ),
      paymentRepository: _FakePaymentRepository(),
      orderRecoveryStore: recoveryStore,
      kioskId: 'kiosk-id',
    );

    final restored = await controller.restoreActiveOrder();

    expect(restored?.status, OrderStatus.accepted);
    expect(controller.activeOrder?.id, 'order-id');
    expect(controller.recoveryError, isNull);
    expect(recoveryStore.savedOrders, hasLength(1));
  });

  test('terminal order returned during recovery is cleared', () async {
    final recoveryStore = _MemoryOrderRecoveryStore(
      record: _recoveryRecord(OrderStatus.preparing),
    );
    final controller = KioskController(
      menuRepository: _FakeMenuRepository(),
      orderRepository: _RestorableOrderRepository(
        _orderResult(
          status: OrderStatus.completed,
          paymentStatus: PaymentStatus.paid,
        ),
      ),
      paymentRepository: _FakePaymentRepository(),
      orderRecoveryStore: recoveryStore,
      kioskId: 'kiosk-id',
    );

    final restored = await controller.restoreActiveOrder();

    expect(restored, isNull);
    expect(controller.activeOrder, isNull);
    expect(recoveryStore.clearCalls, 1);
  });

  test(
    'restored pending order retries payment without creating an order',
    () async {
      final recoveryStore = _MemoryOrderRecoveryStore(
        record: _recoveryRecord(OrderStatus.pendingPayment),
      );
      final paymentRepository = _FlakyPaymentRepository(failures: 0);
      final orderRepository = _RestorableOrderRepository(_orderResult());
      final controller = KioskController(
        menuRepository: _FakeMenuRepository(),
        orderRepository: orderRepository,
        paymentRepository: paymentRepository,
        orderRecoveryStore: recoveryStore,
        kioskId: 'kiosk-id',
      );

      expect(await controller.restoreActiveOrder(), isNotNull);
      final result = await controller.retryPaymentSession();

      expect(result?.order.id, 'order-id');
      expect(paymentRepository.orderIds, ['order-id']);
      expect(orderRepository.createCalls, 0);
    },
  );

  test('order refresh guard prevents overlapping requests', () async {
    final orderRepository = _BlockingOrderRefreshRepository();
    final controller = _checkoutController(
      orderRepository: orderRepository,
      paymentRepository: _FlakyPaymentRepository(failures: 0),
    );

    final firstPoll = controller.refreshOrder('order-id');
    await orderRepository.started.future;
    final overlappingPoll = await controller.refreshOrder('order-id');

    expect(overlappingPoll, isNull);
    expect(orderRepository.getOrderCalls, 1);

    orderRepository.complete(_orderResult(status: OrderStatus.preparing));
    expect((await firstPoll)?.status, OrderStatus.preparing);
  });

  test('safe result states can reset kiosk session and recovery', () async {
    final recoveryStore = _MemoryOrderRecoveryStore(
      record: _recoveryRecord(OrderStatus.accepted),
    );
    final orderRepository = _RestorableOrderRepository(
      _orderResult(
        status: OrderStatus.accepted,
        paymentStatus: PaymentStatus.paid,
      ),
    );
    final controller = KioskController(
      menuRepository: _CheckoutMenuRepository(),
      orderRepository: orderRepository,
      paymentRepository: _FakePaymentRepository(),
      orderRecoveryStore: recoveryStore,
      kioskId: 'kiosk-id',
    );

    expect(await controller.restoreActiveOrder(), isNotNull);
    await controller.loadMenu();
    controller.addToCart(_menuItem());
    for (final status in [
      OrderStatus.ready,
      OrderStatus.completed,
      OrderStatus.failed,
      OrderStatus.cancelled,
      OrderStatus.executionRejected,
      OrderStatus.refundRequired,
      OrderStatus.refunded,
      OrderStatus.compensated,
    ]) {
      orderRepository.order = _orderResult(
        status: status,
        paymentStatus: PaymentStatus.paid,
      );
      await controller.refreshOrder('order-id');
      expect(controller.canResetKioskSession, isTrue, reason: status.name);
    }

    expect(await controller.resetKioskSession(), isTrue);
    expect(controller.activeOrder, isNull);
    expect(controller.activePaymentSession, isNull);
    expect(controller.isCartEmpty, isTrue);
    expect(recoveryStore.clearCalls, 1);
  });

  test('in-progress state cannot reset or clear recovery', () async {
    final recoveryStore = _MemoryOrderRecoveryStore(
      record: _recoveryRecord(OrderStatus.preparing),
    );
    final controller = KioskController(
      menuRepository: _FakeMenuRepository(),
      orderRepository: _RestorableOrderRepository(
        _orderResult(
          status: OrderStatus.preparing,
          paymentStatus: PaymentStatus.paid,
        ),
      ),
      paymentRepository: _FakePaymentRepository(),
      orderRecoveryStore: recoveryStore,
      kioskId: 'kiosk-id',
    );

    expect(await controller.restoreActiveOrder(), isNotNull);

    expect(controller.canResetKioskSession, isFalse);
    expect(await controller.resetKioskSession(), isFalse);
    expect(controller.activeOrder?.status, OrderStatus.preparing);
    expect(recoveryStore.clearCalls, 0);
  });
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
  required PaymentRepository paymentRepository,
}) {
  return KioskController(
    menuRepository: _CheckoutMenuRepository(),
    orderRepository: orderRepository,
    paymentRepository: paymentRepository,
    kioskId: 'kiosk-id',
  );
}

RuntimeMenuItem _menuItem({double price = 35000}) {
  return RuntimeMenuItem(
    menuId: 'menu-id',
    menuItemId: 'menu-item-id',
    productId: 'product-id',
    productVariantId: 'variant-id',
    menuItemCode: 'MI-001',
    productCode: 'P-001',
    productVariantCode: 'V-001',
    displayName: 'Kem vani',
    price: price,
    discountAmount: 0,
    finalPrice: price,
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
  CreateOrderRequest? lastRequest;

  @override
  Future<OrderResult> createOrder(CreateOrderRequest request) async {
    createCalls++;
    lastRequest = request;
    return _orderResult();
  }
}

class _BlockingOrderRepository extends OrderRepository {
  _BlockingOrderRepository() : super(DioClient(baseUrl: 'http://localhost'));

  int createCalls = 0;
  final Completer<void> started = Completer<void>();
  final Completer<OrderResult> _result = Completer<OrderResult>();

  @override
  Future<OrderResult> createOrder(CreateOrderRequest request) {
    createCalls++;
    if (!started.isCompleted) {
      started.complete();
    }
    return _result.future;
  }

  void complete(OrderResult order) => _result.complete(order);
}

class _ConflictOrderRepository extends OrderRepository {
  _ConflictOrderRepository() : super(DioClient(baseUrl: 'http://localhost'));

  int createCalls = 0;

  @override
  Future<OrderResult> createOrder(CreateOrderRequest request) async {
    createCalls++;
    throw const ApiException(
      type: ApiErrorType.conflict,
      statusCode: 409,
      message: 'Client total does not match calculated total.',
      details: {'clientTotalAmount': 35000, 'calculatedTotalAmount': 40000},
    );
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

class _MissingPaymentAccessRepository extends PaymentRepository {
  _MissingPaymentAccessRepository()
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
      amount: 35000,
      currency: 'VND',
      status: PaymentTransactionStatus.pending,
    );
  }
}

class _UncertainPaymentRepository extends PaymentRepository {
  _UncertainPaymentRepository() : super(DioClient(baseUrl: 'http://localhost'));

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
    if (orderIds.length == 1) {
      throw const ApiException(
        type: ApiErrorType.network,
        message: 'Connection interrupted.',
      );
    }

    return PaymentSessionResult(
      paymentTransactionId: 'payment-id',
      orderId: orderId,
      transactionNumber: 'PAY-001',
      provider: 'PayOS',
      checkoutUrl: 'https://example.test/payment',
      amount: 35000,
      currency: 'VND',
      status: PaymentTransactionStatus.pending,
    );
  }
}

class _BlockingPaymentStatusOrderRepository extends OrderRepository {
  _BlockingPaymentStatusOrderRepository()
    : super(DioClient(baseUrl: 'http://localhost'));

  int paymentStatusCalls = 0;
  final Completer<void> started = Completer<void>();
  final Completer<PaymentStatusResult> _result =
      Completer<PaymentStatusResult>();

  @override
  Future<PaymentStatusResult> getPaymentStatus(String orderId) {
    paymentStatusCalls++;
    if (!started.isCompleted) {
      started.complete();
    }
    return _result.future;
  }

  void complete(PaymentStatusResult status) => _result.complete(status);
}

class _RestorableOrderRepository extends OrderRepository {
  _RestorableOrderRepository(this.order)
    : super(DioClient(baseUrl: 'http://localhost'));

  OrderResult order;
  int createCalls = 0;

  @override
  Future<OrderResult> createOrder(CreateOrderRequest request) async {
    createCalls++;
    return order;
  }

  @override
  Future<OrderResult> getOrder(String orderId) async => order;
}

class _BlockingOrderRefreshRepository extends OrderRepository {
  _BlockingOrderRefreshRepository()
    : super(DioClient(baseUrl: 'http://localhost'));

  int getOrderCalls = 0;
  final Completer<void> started = Completer<void>();
  final Completer<OrderResult> _result = Completer<OrderResult>();

  @override
  Future<OrderResult> getOrder(String orderId) {
    getOrderCalls++;
    if (!started.isCompleted) {
      started.complete();
    }
    return _result.future;
  }

  void complete(OrderResult order) => _result.complete(order);
}

class _MemoryOrderRecoveryStore implements OrderRecoveryStore {
  _MemoryOrderRecoveryStore({this.record});

  OrderRecoveryRecord? record;
  int clearCalls = 0;
  final List<OrderResult> savedOrders = [];

  @override
  Future<void> save(OrderResult order, {DateTime? paymentExpiresAt}) async {
    savedOrders.add(order);
  }

  @override
  Future<OrderRecoveryRecord?> read(String kioskId) async => record;

  @override
  Future<void> clear() async {
    clearCalls++;
    record = null;
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

OrderResult _orderResult({
  OrderStatus status = OrderStatus.pendingPayment,
  PaymentStatus paymentStatus = PaymentStatus.unpaid,
}) {
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
    placedAt: DateTime.utc(2026, 6, 30),
    customerStatus: 'WaitingForPayment',
    customerStatusMessage: 'Waiting for payment.',
    canRetryPayment: status == OrderStatus.pendingPayment,
    requiresStaffSupport: false,
    items: const [],
  );
}

OrderRecoveryRecord _recoveryRecord(OrderStatus status) {
  return OrderRecoveryRecord(
    orderId: 'order-id',
    kioskId: 'kiosk-id',
    orderStatus: status,
    paymentStatus: status == OrderStatus.pendingPayment
        ? PaymentStatus.unpaid
        : PaymentStatus.paid,
    savedAt: DateTime.utc(2026, 7, 1, 10),
    recoveryExpiresAt: DateTime.utc(2026, 7, 2, 10),
  );
}

PaymentStatusResult _paymentStatus() {
  return PaymentStatusResult(
    paymentTransactionId: 'payment-id',
    orderId: 'order-id',
    provider: 'PayOS',
    paymentTransactionStatus: PaymentTransactionStatus.pending,
    orderPaymentStatus: PaymentStatus.unpaid,
    orderStatus: OrderStatus.pendingPayment,
    amount: 35000,
    currency: 'VND',
    customerStatus: 'WaitingForPayment',
    customerStatusMessage: 'Waiting for payment.',
    canRetryPayment: true,
    requiresStaffSupport: false,
  );
}
