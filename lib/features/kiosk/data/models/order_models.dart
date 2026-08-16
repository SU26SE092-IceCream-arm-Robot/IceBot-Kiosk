import 'package:icebot_kiosk/config/app_config.dart';

enum OrderStatus {
  draft,
  pendingPayment,
  paid,
  readyForFulfillment,
  accepted,
  preparing,
  ready,
  completed,
  cancelled,
  failed,
  executionRejected,
  refundRequired,
  refunded,
  compensated,
  fulfillmentIssue,
  unknown,
}

enum PaymentStatus {
  unpaid,
  authorized,
  paid,
  partiallyRefunded,
  refunded,
  failed,
  cancelled,
  unknown,
}

class CreateOrderRequest {
  const CreateOrderRequest({
    required this.kioskId,
    required this.items,
    this.idempotencyKey,
    this.clientOrderId,
    this.runtimeSnapshotId,
    this.runtimeSnapshotGeneratedAt,
    this.clientTotalAmount,
    this.channel = AppConfig.appChannel,
    this.customerName,
    this.customerPhoneNumber,
    this.notes,
  });

  final String kioskId;
  final String? idempotencyKey;
  final String? clientOrderId;
  final String? runtimeSnapshotId;
  final DateTime? runtimeSnapshotGeneratedAt;
  final double? clientTotalAmount;
  final String channel;
  final String? customerName;
  final String? customerPhoneNumber;
  final String? notes;
  final List<CreateOrderItemRequest> items;

  Map<String, dynamic> toJson() => _removeNulls({
    'kioskId': kioskId,
    'clientOrderId': clientOrderId,
    'clientTotalAmount': clientTotalAmount,
    'customerName': customerName,
    'customerPhoneNumber': customerPhoneNumber,
    'notes': notes,
    'items': items.map((item) => item.toJson()).toList(growable: false),
  });
}

class CreateOrderItemRequest {
  const CreateOrderItemRequest({
    required this.menuItemId,
    required this.quantity,
    this.clientLineId,
    this.selectedOptions = const [],
  });

  final String menuItemId;
  final String? clientLineId;
  final int quantity;
  final List<SelectedProductOptionRequest> selectedOptions;

  Map<String, dynamic> toJson() => _removeNulls({
    'menuItemId': menuItemId,
    'clientLineId': clientLineId,
    'quantity': quantity,
    'selectedOptions': selectedOptions
        .map((option) => option.toJson())
        .toList(growable: false),
  });
}

class SelectedProductOptionRequest {
  const SelectedProductOptionRequest({required this.productOptionId});

  final String productOptionId;

  Map<String, dynamic> toJson() => {'productOptionId': productOptionId};
}

class OrderResult {
  const OrderResult({
    required this.id,
    required this.kioskId,
    this.orderAccessToken,
    this.storeId,
    this.organizationId,
    required this.orderNumber,
    this.clientOrderId,
    this.runtimeSnapshotId,
    this.runtimeSnapshotGeneratedAt,
    required this.channel,
    required this.status,
    required this.paymentStatus,
    required this.currency,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.taxAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.placedAt,
    this.paymentDeadlineAt,
    this.paidAt,
    this.completedAt,
    this.cancelledAt,
    required this.customerStatus,
    required this.customerStatusMessage,
    required this.canRetryPayment,
    required this.requiresStaffSupport,
    required this.items,
  });

  final String id;
  final String kioskId;
  final String? orderAccessToken;
  final String? storeId;
  final String? organizationId;
  final String orderNumber;
  final String? clientOrderId;
  final String? runtimeSnapshotId;
  final DateTime? runtimeSnapshotGeneratedAt;
  final String channel;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final String currency;
  final double subtotalAmount;
  final double discountAmount;
  final double taxAmount;
  final double totalAmount;
  final double paidAmount;
  final DateTime placedAt;
  final DateTime? paymentDeadlineAt;
  final DateTime? paidAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String customerStatus;
  final String customerStatusMessage;
  final bool canRetryPayment;
  final bool requiresStaffSupport;
  final List<OrderItemResult> items;

  factory OrderResult.fromJson(Object? json) {
    final map = _asMap(json);
    return OrderResult(
      id: map['id'] as String? ?? '',
      kioskId: map['kioskId'] as String? ?? '',
      orderAccessToken: map['orderAccessToken'] as String?,
      storeId: map['storeId'] as String?,
      organizationId: map['organizationId'] as String?,
      orderNumber: map['orderNumber'] as String? ?? '',
      clientOrderId: map['clientOrderId'] as String?,
      runtimeSnapshotId: map['runtimeSnapshotId'] as String?,
      runtimeSnapshotGeneratedAt: _readNullableDateTime(
        map['runtimeSnapshotGeneratedAt'],
      ),
      channel: map['channel'] as String? ?? AppConfig.appChannel,
      status: OrderStatusMapper.fromJson(
        map['status'],
        customerStatus: map['customerStatus'],
      ),
      paymentStatus: PaymentStatusMapper.fromJson(
        map['paymentStatus'],
        customerStatus: map['customerStatus'],
      ),
      currency: map['currency'] as String? ?? 'VND',
      subtotalAmount: _readDouble(map['subtotalAmount']),
      discountAmount: _readDouble(map['discountAmount']),
      taxAmount: _readDouble(map['taxAmount']),
      totalAmount: _readDouble(map['totalAmount']),
      paidAmount: _readDouble(map['paidAmount']),
      placedAt: _readDateTime(map['placedAt']),
      paymentDeadlineAt: _readNullableDateTime(map['paymentDeadlineAt']),
      paidAt: _readNullableDateTime(map['paidAt']),
      completedAt: _readNullableDateTime(map['completedAt']),
      cancelledAt: _readNullableDateTime(map['cancelledAt']),
      customerStatus: map['customerStatus'] as String? ?? '',
      customerStatusMessage: map['customerStatusMessage'] as String? ?? '',
      canRetryPayment: map['canRetryPayment'] == true,
      requiresStaffSupport: map['requiresStaffSupport'] == true,
      items: _readList(map['items'], OrderItemResult.fromJson),
    );
  }
}

class OrderItemResult {
  const OrderItemResult({
    required this.id,
    required this.menuItemId,
    required this.productId,
    required this.productVariantId,
    this.recipeId,
    this.clientLineId,
    required this.menuItemCodeSnapshot,
    required this.menuItemNameSnapshot,
    required this.productCodeSnapshot,
    required this.productNameSnapshot,
    required this.productVariantCodeSnapshot,
    required this.productVariantNameSnapshot,
    this.recipeVersionSnapshot,
    required this.quantity,
    required this.unitPrice,
    required this.discountAmount,
    required this.totalAmount,
    required this.status,
    this.selectedOptions = const [],
  });

  final String id;
  final String menuItemId;
  final String productId;
  final String productVariantId;
  final String? recipeId;
  final String? clientLineId;
  final String menuItemCodeSnapshot;
  final String menuItemNameSnapshot;
  final String productCodeSnapshot;
  final String productNameSnapshot;
  final String productVariantCodeSnapshot;
  final String productVariantNameSnapshot;
  final int? recipeVersionSnapshot;
  final int quantity;
  final double unitPrice;
  final double discountAmount;
  final double totalAmount;
  final String status;
  final List<OrderItemOptionResult> selectedOptions;

  factory OrderItemResult.fromJson(Object? json) {
    final map = _asMap(json);
    return OrderItemResult(
      id: map['id'] as String? ?? '',
      menuItemId: map['menuItemId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productVariantId: map['productVariantId'] as String? ?? '',
      recipeId: map['recipeId'] as String?,
      clientLineId: map['clientLineId'] as String?,
      menuItemCodeSnapshot:
          map['menuItemCode'] as String? ??
          map['menuItemCodeSnapshot'] as String? ??
          '',
      menuItemNameSnapshot:
          map['menuItemName'] as String? ??
          map['menuItemNameSnapshot'] as String? ??
          '',
      productCodeSnapshot:
          map['productCode'] as String? ??
          map['productCodeSnapshot'] as String? ??
          '',
      productNameSnapshot:
          map['productName'] as String? ??
          map['productNameSnapshot'] as String? ??
          '',
      productVariantCodeSnapshot:
          map['productVariantCode'] as String? ??
          map['productVariantCodeSnapshot'] as String? ??
          '',
      productVariantNameSnapshot:
          map['productVariantName'] as String? ??
          map['productVariantNameSnapshot'] as String? ??
          '',
      recipeVersionSnapshot:
          _readInt(map['recipeVersion']) ??
          _readInt(map['recipeVersionSnapshot']),
      quantity: _readInt(map['quantity']) ?? 0,
      unitPrice: _readDouble(map['unitPrice']),
      discountAmount: _readDouble(map['discountAmount']),
      totalAmount: _readDouble(map['totalAmount']),
      status: map['status'] as String? ?? '',
      selectedOptions: _readList(
        map['selectedOptions'],
        OrderItemOptionResult.fromJson,
      ),
    );
  }
}

class OrderItemOptionResult {
  const OrderItemOptionResult({
    required this.productOptionId,
    required this.optionGroupCode,
    required this.code,
    required this.name,
    required this.priceDelta,
  });

  final String productOptionId;
  final String optionGroupCode;
  final String code;
  final String name;
  final double priceDelta;

  factory OrderItemOptionResult.fromJson(Object? json) {
    final map = _asMap(json);
    return OrderItemOptionResult(
      productOptionId: map['productOptionId'] as String? ?? '',
      optionGroupCode: map['optionGroupCode'] as String? ?? '',
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? '',
      priceDelta: _readDouble(map['priceDelta']),
    );
  }
}

class OrderStatusMapper {
  OrderStatusMapper._();

  static OrderStatus fromJson(Object? value, {Object? customerStatus}) {
    final raw = value?.toString();
    if (raw != null && raw.isNotEmpty) {
      return switch (raw) {
        'Draft' => OrderStatus.draft,
        'PendingPayment' => OrderStatus.pendingPayment,
        'Paid' => OrderStatus.paid,
        'ReadyForFulfillment' => OrderStatus.readyForFulfillment,
        'Accepted' => OrderStatus.accepted,
        'Preparing' => OrderStatus.preparing,
        'Ready' => OrderStatus.ready,
        'Completed' => OrderStatus.completed,
        'Cancelled' => OrderStatus.cancelled,
        'Failed' => OrderStatus.failed,
        'ExecutionRejected' => OrderStatus.executionRejected,
        'RefundRequired' => OrderStatus.refundRequired,
        'Refunded' => OrderStatus.refunded,
        'Compensated' => OrderStatus.compensated,
        'FulfillmentIssue' => OrderStatus.fulfillmentIssue,
        _ => OrderStatus.unknown,
      };
    }

    return switch (customerStatus?.toString()) {
      'Draft' => OrderStatus.draft,
      'WaitingForPayment' ||
      'PaymentFailed' ||
      'PaymentCancelled' ||
      'PaymentExpired' => OrderStatus.pendingPayment,
      'Preparing' || 'Delayed' || 'PendingRecovery' => OrderStatus.preparing,
      'Ready' => OrderStatus.ready,
      'Completed' => OrderStatus.completed,
      'Cancelled' => OrderStatus.cancelled,
      'SupportRequired' => OrderStatus.fulfillmentIssue,
      'RefundRequired' => OrderStatus.refundRequired,
      'Refunded' => OrderStatus.refunded,
      'Compensated' => OrderStatus.compensated,
      _ => OrderStatus.unknown,
    };
  }
}

class PaymentStatusMapper {
  PaymentStatusMapper._();

  static PaymentStatus fromJson(Object? value, {Object? customerStatus}) {
    final raw = value?.toString();
    if (raw != null && raw.isNotEmpty) {
      return switch (raw) {
        'Unpaid' => PaymentStatus.unpaid,
        'Authorized' => PaymentStatus.authorized,
        'Paid' => PaymentStatus.paid,
        'PartiallyRefunded' => PaymentStatus.partiallyRefunded,
        'Refunded' => PaymentStatus.refunded,
        'Failed' => PaymentStatus.failed,
        'Cancelled' => PaymentStatus.cancelled,
        _ => PaymentStatus.unknown,
      };
    }

    return switch (customerStatus?.toString()) {
      'Draft' ||
      'WaitingForPayment' ||
      'PaymentFailed' ||
      'PaymentCancelled' ||
      'PaymentExpired' => PaymentStatus.unpaid,
      'Preparing' ||
      'Delayed' ||
      'PendingRecovery' ||
      'Ready' ||
      'Completed' ||
      'SupportRequired' ||
      'RefundRequired' ||
      'Compensated' => PaymentStatus.paid,
      'Refunded' => PaymentStatus.refunded,
      _ => PaymentStatus.unknown,
    };
  }
}

Map<String, dynamic> _removeNulls(Map<String, dynamic> map) {
  return Map<String, dynamic>.fromEntries(
    map.entries.where((entry) => entry.value != null),
  );
}

Map<String, dynamic> _asMap(Object? json) {
  if (json is Map<String, dynamic>) {
    return json;
  }
  if (json is Map) {
    return Map<String, dynamic>.from(json);
  }
  throw const FormatException('Expected a JSON object.');
}

List<T> _readList<T>(Object? value, T Function(Object? json) decode) {
  if (value is! List) {
    return const [];
  }

  return value.map(decode).toList(growable: false);
}

DateTime _readDateTime(Object? value) {
  return _readNullableDateTime(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _readNullableDateTime(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

double _readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}

int? _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
