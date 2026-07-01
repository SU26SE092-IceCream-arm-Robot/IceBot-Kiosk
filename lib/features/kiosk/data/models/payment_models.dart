import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';

enum PaymentTransactionStatus {
  pending,
  authorized,
  paid,
  failed,
  cancelled,
  refunded,
  expired,
  unknown,
}

class PaymentSessionResult {
  const PaymentSessionResult({
    required this.paymentTransactionId,
    required this.orderId,
    required this.transactionNumber,
    required this.provider,
    this.providerOrderCode,
    this.providerPaymentLinkId,
    this.checkoutUrl,
    this.qrCodePayload,
    required this.amount,
    required this.currency,
    required this.status,
    this.expiresAt,
  });

  final String paymentTransactionId;
  final String orderId;
  final String transactionNumber;
  final String provider;
  final String? providerOrderCode;
  final String? providerPaymentLinkId;
  final String? checkoutUrl;
  final String? qrCodePayload;
  final double amount;
  final String currency;
  final PaymentTransactionStatus status;
  final DateTime? expiresAt;

  bool get hasQrCodePayload => qrCodePayload?.trim().isNotEmpty == true;

  bool get hasUsableCheckoutUrl {
    final uri = Uri.tryParse(checkoutUrl?.trim() ?? '');
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  bool get hasPaymentAccess => hasQrCodePayload || hasUsableCheckoutUrl;

  bool isExpiredAt(DateTime now) {
    final expiry = expiresAt;
    return expiry != null && !now.isBefore(expiry);
  }

  factory PaymentSessionResult.fromJson(Object? json) {
    final map = _asMap(json);
    return PaymentSessionResult(
      paymentTransactionId: map['paymentTransactionId'] as String? ?? '',
      orderId: map['orderId'] as String? ?? '',
      transactionNumber: map['transactionNumber'] as String? ?? '',
      provider: map['provider'] as String? ?? '',
      providerOrderCode: map['providerOrderCode'] as String?,
      providerPaymentLinkId: map['providerPaymentLinkId'] as String?,
      checkoutUrl: map['checkoutUrl'] as String?,
      qrCodePayload: map['qrCodePayload'] as String?,
      amount: _readDouble(map['amount']),
      currency: map['currency'] as String? ?? 'VND',
      status: PaymentTransactionStatusMapper.fromJson(map['status']),
      expiresAt: _readNullableDateTime(map['expiresAt']),
    );
  }
}

class PaymentStatusResult {
  const PaymentStatusResult({
    required this.paymentTransactionId,
    required this.orderId,
    required this.provider,
    required this.paymentTransactionStatus,
    required this.orderPaymentStatus,
    required this.orderStatus,
    required this.amount,
    this.paidAmount,
    required this.currency,
    this.paidAt,
    this.expiresAt,
    required this.customerStatus,
    required this.customerStatusMessage,
    required this.canRetryPayment,
    required this.requiresStaffSupport,
  });

  final String paymentTransactionId;
  final String orderId;
  final String provider;
  final PaymentTransactionStatus paymentTransactionStatus;
  final PaymentStatus orderPaymentStatus;
  final OrderStatus orderStatus;
  final double amount;
  final double? paidAmount;
  final String currency;
  final DateTime? paidAt;
  final DateTime? expiresAt;
  final String customerStatus;
  final String customerStatusMessage;
  final bool canRetryPayment;
  final bool requiresStaffSupport;

  factory PaymentStatusResult.fromJson(Object? json) {
    final map = _asMap(json);
    return PaymentStatusResult(
      paymentTransactionId: map['paymentTransactionId'] as String? ?? '',
      orderId: map['orderId'] as String? ?? '',
      provider: map['provider'] as String? ?? '',
      paymentTransactionStatus: PaymentTransactionStatusMapper.fromJson(
        map['paymentTransactionStatus'],
      ),
      orderPaymentStatus: PaymentStatusMapper.fromJson(
        map['orderPaymentStatus'],
      ),
      orderStatus: OrderStatusMapper.fromJson(map['orderStatus']),
      amount: _readDouble(map['amount']),
      paidAmount: _readNullableDouble(map['paidAmount']),
      currency: map['currency'] as String? ?? 'VND',
      paidAt: _readNullableDateTime(map['paidAt']),
      expiresAt: _readNullableDateTime(map['expiresAt']),
      customerStatus: map['customerStatus'] as String? ?? '',
      customerStatusMessage: map['customerStatusMessage'] as String? ?? '',
      canRetryPayment: map['canRetryPayment'] == true,
      requiresStaffSupport: map['requiresStaffSupport'] == true,
    );
  }
}

class PaymentTransactionStatusMapper {
  PaymentTransactionStatusMapper._();

  static PaymentTransactionStatus fromJson(Object? value) {
    return switch (value?.toString()) {
      'Pending' => PaymentTransactionStatus.pending,
      'Authorized' => PaymentTransactionStatus.authorized,
      'Paid' => PaymentTransactionStatus.paid,
      'Failed' => PaymentTransactionStatus.failed,
      'Cancelled' => PaymentTransactionStatus.cancelled,
      'Refunded' => PaymentTransactionStatus.refunded,
      'Expired' => PaymentTransactionStatus.expired,
      _ => PaymentTransactionStatus.unknown,
    };
  }
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

DateTime? _readNullableDateTime(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

double _readDouble(Object? value) {
  return _readNullableDouble(value) ?? 0;
}

double? _readNullableDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}
