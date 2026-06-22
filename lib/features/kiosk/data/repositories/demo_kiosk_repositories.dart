import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/payment_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/runtime_menu_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/menu_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/order_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/payment_repository.dart';

class DemoKioskStore {
  DemoKioskStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, _DemoOrderRecord> _orders = {};

  RuntimeMenuResult getRuntimeMenu() {
    final now = _clock().toUtc();
    return RuntimeMenuResult(
      snapshotId: _DemoIds.snapshotId,
      kioskId: AppConfig.effectiveKioskId,
      generatedAt: now,
      expiresAt: now.add(const Duration(minutes: 10)),
      availabilitySource: 'DemoLocalData',
      containsMachineRuntimeState: false,
      items: demoMenuItems,
    );
  }

  OrderResult createOrder(CreateOrderRequest request) {
    if (request.items.isEmpty) {
      throw const ApiException(
        type: ApiErrorType.validation,
        message: 'Đơn demo cần ít nhất một món.',
      );
    }

    final now = _clock().toUtc();
    final lines = request.items
        .map((line) {
          final item = _findMenuItem(line.menuItemId);
          if (item == null) {
            throw ApiException(
              type: ApiErrorType.notFound,
              message: 'Món demo không tồn tại: ${line.menuItemId}',
            );
          }
          if (line.quantity <= 0) {
            throw const ApiException(
              type: ApiErrorType.validation,
              message: 'Số lượng món demo phải lớn hơn 0.',
            );
          }
          return _DemoOrderLine(item: item, quantity: line.quantity);
        })
        .toList(growable: false);

    final subtotal = lines.fold<double>(
      0,
      (total, line) => total + line.item.finalPrice * line.quantity,
    );
    if (request.clientTotalAmount != null &&
        (request.clientTotalAmount! - subtotal).abs() > 0.01) {
      throw const ApiException(
        type: ApiErrorType.conflict,
        message: 'Tổng tiền demo không khớp với giỏ hàng.',
      );
    }

    final orderId = _DemoIds.orderId(_orders.length + 1);
    final record = _DemoOrderRecord(
      orderId: orderId,
      orderNumber: 'DEMO-${now.millisecondsSinceEpoch.toString().substring(5)}',
      clientOrderId: request.clientOrderId,
      snapshotId: request.runtimeSnapshotId,
      snapshotGeneratedAt: request.runtimeSnapshotGeneratedAt,
      createdAt: now,
      lines: lines,
      totalAmount: subtotal,
    );
    _orders[orderId] = record;
    return _buildOrder(record);
  }

  PaymentSessionResult createPaymentSession(String orderId) {
    final record = _readRecord(orderId);
    final now = _clock().toUtc();
    record.paymentTransactionId ??= _DemoIds.paymentTransactionId(orderId);
    record.paymentSessionCreatedAt ??= now;
    return PaymentSessionResult(
      paymentTransactionId: record.paymentTransactionId!,
      orderId: record.orderId,
      transactionNumber: 'PAY-DEMO-${record.orderNumber}',
      provider: 'DemoLocal',
      providerOrderCode: 'DEMO-ORDER-CODE',
      providerPaymentLinkId: 'DEMO-PAYMENT-LINK',
      checkoutUrl: null,
      qrCodePayload:
          'DEMO-QR|IceBot|${record.orderNumber}|${record.totalAmount.toStringAsFixed(0)}|Không dùng để thanh toán thật',
      amount: record.totalAmount,
      currency: 'VND',
      status: PaymentTransactionStatus.pending,
      expiresAt: now.add(const Duration(minutes: 5)),
    );
  }

  PaymentStatusResult getPaymentStatus(String orderId) {
    final record = _readRecord(orderId);
    _applyDemoProgress(record);
    return PaymentStatusResult(
      paymentTransactionId:
          record.paymentTransactionId ?? _DemoIds.paymentTransactionId(orderId),
      orderId: record.orderId,
      provider: 'DemoLocal',
      paymentTransactionStatus: record.paymentTransactionStatus,
      orderPaymentStatus: record.paymentStatus,
      orderStatus: record.orderStatus,
      amount: record.totalAmount,
      paidAmount: record.paymentStatus == PaymentStatus.paid
          ? record.totalAmount
          : null,
      currency: 'VND',
      paidAt: record.paidAt,
      expiresAt: record.paymentSessionCreatedAt?.add(
        const Duration(minutes: 5),
      ),
      customerStatus: _customerStatus(record.orderStatus),
      customerStatusMessage: _customerStatusMessage(record.orderStatus),
      canRetryPayment: record.orderStatus == OrderStatus.pendingPayment,
      requiresStaffSupport: false,
    );
  }

  OrderResult getOrder(String orderId) {
    final record = _readRecord(orderId);
    _applyDemoProgress(record);
    return _buildOrder(record);
  }

  OrderResult cancelOrder(String orderId, {String? reason}) {
    final record = _readRecord(orderId);
    _applyDemoProgress(record);
    if (record.paymentStatus == PaymentStatus.paid ||
        record.orderStatus != OrderStatus.pendingPayment) {
      throw const ApiException(
        type: ApiErrorType.conflict,
        message: 'Đơn demo đã qua bước thanh toán nên không thể hủy.',
      );
    }

    record.orderStatus = OrderStatus.cancelled;
    record.paymentStatus = PaymentStatus.cancelled;
    record.paymentTransactionStatus = PaymentTransactionStatus.cancelled;
    record.cancelledAt = _clock().toUtc();
    return _buildOrder(record);
  }

  RuntimeMenuItem? _findMenuItem(String menuItemId) {
    for (final item in demoMenuItems) {
      if (item.menuItemId == menuItemId) {
        return item;
      }
    }
    return null;
  }

  _DemoOrderRecord _readRecord(String orderId) {
    final record = _orders[orderId];
    if (record == null) {
      throw const ApiException(
        type: ApiErrorType.notFound,
        message: 'Không tìm thấy đơn demo.',
      );
    }
    return record;
  }

  void _applyDemoProgress(_DemoOrderRecord record) {
    if (record.orderStatus == OrderStatus.cancelled) {
      return;
    }

    final sessionCreatedAt = record.paymentSessionCreatedAt;
    if (sessionCreatedAt == null) {
      record.orderStatus = OrderStatus.pendingPayment;
      record.paymentStatus = PaymentStatus.unpaid;
      record.paymentTransactionStatus = PaymentTransactionStatus.pending;
      return;
    }

    final elapsed = _clock().toUtc().difference(sessionCreatedAt);
    if (elapsed < const Duration(seconds: 3)) {
      record.orderStatus = OrderStatus.pendingPayment;
      record.paymentStatus = PaymentStatus.unpaid;
      record.paymentTransactionStatus = PaymentTransactionStatus.pending;
      return;
    }

    record.paidAt ??= sessionCreatedAt.add(const Duration(seconds: 3));
    record.paymentStatus = PaymentStatus.paid;
    record.paymentTransactionStatus = PaymentTransactionStatus.paid;

    final afterPaid = _clock().toUtc().difference(record.paidAt!);
    if (afterPaid < const Duration(seconds: 3)) {
      record.orderStatus = OrderStatus.paid;
    } else if (afterPaid < const Duration(seconds: 6)) {
      record.orderStatus = OrderStatus.preparing;
    } else if (afterPaid < const Duration(seconds: 9)) {
      record.orderStatus = OrderStatus.ready;
    } else {
      record.orderStatus = OrderStatus.completed;
      record.completedAt ??= record.paidAt!.add(const Duration(seconds: 9));
    }
  }

  OrderResult _buildOrder(_DemoOrderRecord record) {
    return OrderResult(
      id: record.orderId,
      kioskId: AppConfig.effectiveKioskId,
      storeId: _DemoIds.storeId,
      organizationId: _DemoIds.organizationId,
      orderNumber: record.orderNumber,
      clientOrderId: record.clientOrderId,
      runtimeSnapshotId: record.snapshotId,
      runtimeSnapshotGeneratedAt: record.snapshotGeneratedAt,
      channel: AppConfig.appChannel,
      status: record.orderStatus,
      paymentStatus: record.paymentStatus,
      currency: 'VND',
      subtotalAmount: record.totalAmount,
      discountAmount: 0,
      taxAmount: 0,
      totalAmount: record.totalAmount,
      paidAmount: record.paymentStatus == PaymentStatus.paid
          ? record.totalAmount
          : 0,
      placedAt: record.createdAt,
      paidAt: record.paidAt,
      completedAt: record.completedAt,
      cancelledAt: record.cancelledAt,
      customerStatus: _customerStatus(record.orderStatus),
      customerStatusMessage: _customerStatusMessage(record.orderStatus),
      canRetryPayment: record.orderStatus == OrderStatus.pendingPayment,
      requiresStaffSupport: false,
      items: [
        for (var i = 0; i < record.lines.length; i++)
          _buildOrderItem(record.lines[i], i),
      ],
    );
  }

  OrderItemResult _buildOrderItem(_DemoOrderLine line, int index) {
    final item = line.item;
    return OrderItemResult(
      id: _DemoIds.orderItemId(index + 1),
      menuItemId: item.menuItemId,
      productId: item.productId,
      productVariantId: item.productVariantId,
      recipeId: item.recipeId,
      clientLineId: 'demo-line-${index + 1}',
      menuItemCodeSnapshot: item.menuItemCode,
      menuItemNameSnapshot: item.displayName,
      productCodeSnapshot: item.productCode,
      productNameSnapshot: item.displayName,
      productVariantCodeSnapshot: item.productVariantCode,
      productVariantNameSnapshot: item.sizeCode ?? 'Ly tiêu chuẩn',
      recipeVersionSnapshot: item.recipeVersion,
      quantity: line.quantity,
      unitPrice: item.finalPrice,
      discountAmount: 0,
      totalAmount: item.finalPrice * line.quantity,
      status: 'Demo',
    );
  }

  String _customerStatus(OrderStatus status) {
    return switch (status) {
      OrderStatus.pendingPayment => 'DemoWaitingForPayment',
      OrderStatus.paid ||
      OrderStatus.readyForExecution ||
      OrderStatus.accepted ||
      OrderStatus.preparing => 'DemoPreparing',
      OrderStatus.ready => 'DemoReady',
      OrderStatus.completed => 'DemoCompleted',
      OrderStatus.cancelled => 'DemoCancelled',
      _ => 'Demo',
    };
  }

  String _customerStatusMessage(OrderStatus status) {
    return switch (status) {
      OrderStatus.pendingPayment => 'Demo: đang chờ xác nhận thanh toán.',
      OrderStatus.paid ||
      OrderStatus.readyForExecution ||
      OrderStatus.accepted ||
      OrderStatus.preparing => 'Demo: đang mô phỏng bước chuẩn bị.',
      OrderStatus.ready => 'Demo: đơn đã sẵn sàng để nhận.',
      OrderStatus.completed => 'Demo: luồng khách hàng đã hoàn tất.',
      OrderStatus.cancelled => 'Demo: đơn đã hủy.',
      _ => 'Demo: trạng thái mô phỏng.',
    };
  }
}

class DemoMenuRepository extends MenuRepository {
  DemoMenuRepository(this._store) : super(DioClient(baseUrl: _demoBaseUrl));

  final DemoKioskStore _store;

  @override
  Future<RuntimeMenuResult> getRuntimeMenu(String kioskId) async {
    return _store.getRuntimeMenu();
  }
}

class DemoOrderRepository extends OrderRepository {
  DemoOrderRepository(this._store) : super(DioClient(baseUrl: _demoBaseUrl));

  final DemoKioskStore _store;

  @override
  Future<OrderResult> createOrder(CreateOrderRequest request) async {
    return _store.createOrder(request);
  }

  @override
  Future<OrderResult> getOrder(String orderId) async {
    return _store.getOrder(orderId);
  }

  @override
  Future<PaymentStatusResult> getPaymentStatus(String orderId) async {
    return _store.getPaymentStatus(orderId);
  }

  @override
  Future<OrderResult> cancelOrder(String orderId, {String? reason}) async {
    return _store.cancelOrder(orderId, reason: reason);
  }
}

class DemoPaymentRepository extends PaymentRepository {
  DemoPaymentRepository(this._store) : super(DioClient(baseUrl: _demoBaseUrl));

  final DemoKioskStore _store;

  @override
  Future<PaymentSessionResult> createPaymentSession(
    String orderId, {
    String? idempotencyKey,
    String? description,
  }) async {
    return _store.createPaymentSession(orderId);
  }
}

const String _demoBaseUrl = 'http://demo.icebot.local';

const List<RuntimeMenuItem> demoMenuItems = [
  RuntimeMenuItem(
    menuId: _DemoIds.menuId,
    menuItemId: '00000000-0000-7000-8000-000000000101',
    productId: '00000000-0000-7000-8000-000000000201',
    productVariantId: '00000000-0000-7000-8000-000000000301',
    recipeId: '00000000-0000-7000-8000-000000000401',
    menuItemCode: 'DEMO-VANILLA',
    productCode: 'ICE-VANILLA',
    productVariantCode: 'CUP-M',
    displayName: 'Kem Vanilla',
    description: 'Vị vanilla dịu nhẹ, phù hợp để review luồng mua hàng.',
    sizeCode: 'M',
    price: 35000,
    discountAmount: 0,
    finalPrice: 35000,
    currency: 'VND',
    preparationTimeSeconds: 75,
    recipeVersion: 1,
  ),
  RuntimeMenuItem(
    menuId: _DemoIds.menuId,
    menuItemId: '00000000-0000-7000-8000-000000000102',
    productId: '00000000-0000-7000-8000-000000000202',
    productVariantId: '00000000-0000-7000-8000-000000000302',
    recipeId: '00000000-0000-7000-8000-000000000402',
    menuItemCode: 'DEMO-CHOCOLATE',
    productCode: 'ICE-CHOCOLATE',
    productVariantCode: 'CUP-M',
    displayName: 'Kem Chocolate',
    description: 'Chocolate đậm vị, dữ liệu demo không nối máy thật.',
    sizeCode: 'M',
    price: 39000,
    discountAmount: 0,
    finalPrice: 39000,
    currency: 'VND',
    preparationTimeSeconds: 80,
    recipeVersion: 1,
  ),
  RuntimeMenuItem(
    menuId: _DemoIds.menuId,
    menuItemId: '00000000-0000-7000-8000-000000000103',
    productId: '00000000-0000-7000-8000-000000000203',
    productVariantId: '00000000-0000-7000-8000-000000000303',
    recipeId: '00000000-0000-7000-8000-000000000403',
    menuItemCode: 'DEMO-STRAWBERRY',
    productCode: 'ICE-STRAWBERRY',
    productVariantCode: 'CUP-M',
    displayName: 'Kem Dâu',
    description: 'Vị dâu tươi, dùng để kiểm tra giao diện tablet.',
    sizeCode: 'M',
    price: 37000,
    discountAmount: 0,
    finalPrice: 37000,
    currency: 'VND',
    preparationTimeSeconds: 78,
    recipeVersion: 1,
  ),
  RuntimeMenuItem(
    menuId: _DemoIds.menuId,
    menuItemId: '00000000-0000-7000-8000-000000000104',
    productId: '00000000-0000-7000-8000-000000000204',
    productVariantId: '00000000-0000-7000-8000-000000000304',
    recipeId: '00000000-0000-7000-8000-000000000404',
    menuItemCode: 'DEMO-CARAMEL-SUNDAE',
    productCode: 'SUNDAE-CARAMEL',
    productVariantCode: 'CUP-L',
    displayName: 'Sundae Caramel',
    description: 'Sundae caramel demo, QR hiển thị chỉ để review UI.',
    sizeCode: 'L',
    price: 45000,
    discountAmount: 0,
    finalPrice: 45000,
    currency: 'VND',
    preparationTimeSeconds: 95,
    recipeVersion: 1,
  ),
];

class _DemoOrderLine {
  const _DemoOrderLine({required this.item, required this.quantity});

  final RuntimeMenuItem item;
  final int quantity;
}

class _DemoOrderRecord {
  _DemoOrderRecord({
    required this.orderId,
    required this.orderNumber,
    required this.clientOrderId,
    required this.snapshotId,
    required this.snapshotGeneratedAt,
    required this.createdAt,
    required this.lines,
    required this.totalAmount,
  });

  final String orderId;
  final String orderNumber;
  final String? clientOrderId;
  final String? snapshotId;
  final DateTime? snapshotGeneratedAt;
  final DateTime createdAt;
  final List<_DemoOrderLine> lines;
  final double totalAmount;
  String? paymentTransactionId;
  DateTime? paymentSessionCreatedAt;
  DateTime? paidAt;
  DateTime? completedAt;
  DateTime? cancelledAt;
  OrderStatus orderStatus = OrderStatus.pendingPayment;
  PaymentStatus paymentStatus = PaymentStatus.unpaid;
  PaymentTransactionStatus paymentTransactionStatus =
      PaymentTransactionStatus.pending;
}

class _DemoIds {
  _DemoIds._();

  static const String organizationId = '00000000-0000-7000-8000-000000000010';
  static const String storeId = '00000000-0000-7000-8000-000000000020';
  static const String menuId = '00000000-0000-7000-8000-000000000030';
  static const String snapshotId = '00000000-0000-7000-8000-000000000040';

  static String orderId(int index) =>
      '00000000-0000-7000-8000-${index.toString().padLeft(12, '0')}';

  static String orderItemId(int index) =>
      '00000000-0000-7000-8001-${index.toString().padLeft(12, '0')}';

  static String paymentTransactionId(String orderId) {
    return orderId.replaceFirst('0000-7000-8000-', '0000-7000-9000-');
  }
}
