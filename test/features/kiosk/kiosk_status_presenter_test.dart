import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/payment_models.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/status/kiosk_status_presenter.dart';

void main() {
  test('detects paid payment status as terminal', () {
    final status = _paymentStatus(
      transactionStatus: PaymentTransactionStatus.paid,
      orderPaymentStatus: PaymentStatus.paid,
      orderStatus: OrderStatus.paid,
    );

    expect(KioskStatusPresenter.isPaymentPaid(status), isTrue);
    expect(KioskStatusPresenter.isPaymentTerminal(status), isTrue);
  });

  test('detects completed order as terminal', () {
    final order = _order(status: OrderStatus.completed);

    expect(KioskStatusPresenter.isOrderTerminal(order), isTrue);
    final view = KioskStatusPresenter.order(
      order,
      primary: Colors.teal,
      success: Colors.green,
      warning: Colors.orange,
      danger: Colors.red,
    );
    expect(view.title, 'Hoàn tất');
  });

  test('shows paid order before robot preparation', () {
    final order = _order(
      status: OrderStatus.paid,
      paymentStatus: PaymentStatus.paid,
    );

    final view = KioskStatusPresenter.order(
      order,
      primary: Colors.teal,
      success: Colors.green,
      warning: Colors.orange,
      danger: Colors.red,
    );

    expect(view.title, 'Đã thanh toán');
  });

  test('uses neutral copy until order is actually preparing', () {
    final readyForExecution = _present(OrderStatus.readyForExecution);
    final accepted = _present(OrderStatus.accepted);
    final preparing = _present(OrderStatus.preparing);

    expect(readyForExecution.title, 'Đơn đang chờ xử lý');
    expect(accepted.title, 'Hệ thống đã nhận đơn');
    expect(preparing.title, 'Robot đang chuẩn bị');
  });

  test('allows cancel only before paid', () {
    final pendingOrder = _order(status: OrderStatus.pendingPayment);
    final paidOrder = _order(
      status: OrderStatus.paid,
      paymentStatus: PaymentStatus.paid,
    );
    final preparingOrder = _order(
      status: OrderStatus.preparing,
      paymentStatus: PaymentStatus.paid,
    );

    expect(
      KioskStatusPresenter.canCancelBeforePaid(pendingOrder, null),
      isTrue,
    );
    expect(KioskStatusPresenter.canCancelBeforePaid(paidOrder, null), isFalse);
    expect(
      KioskStatusPresenter.canCancelBeforePaid(preparingOrder, null),
      isFalse,
    );
  });

  test('failed cancelled and expired payments use terminal customer copy', () {
    expect(
      _presentPayment(PaymentTransactionStatus.failed).title,
      'Thanh toán thất bại',
    );
    expect(
      _presentPayment(PaymentTransactionStatus.cancelled).title,
      'Thanh toán đã hủy',
    );
    expect(
      _presentPayment(PaymentTransactionStatus.expired).title,
      'Mã thanh toán đã hết hạn',
    );
  });

  test('refund-required payment directs customer to staff support', () {
    final status = _paymentStatus(
      transactionStatus: PaymentTransactionStatus.paid,
      orderPaymentStatus: PaymentStatus.paid,
      orderStatus: OrderStatus.refundRequired,
      requiresStaffSupport: true,
    );

    final view = KioskStatusPresenter.payment(
      status,
      order: _order(status: OrderStatus.refundRequired),
      primary: Colors.teal,
      success: Colors.green,
      warning: Colors.orange,
      danger: Colors.red,
      timedOut: false,
    );

    expect(view.title, 'Cần nhân viên hỗ trợ');
    expect(KioskStatusPresenter.isPaymentTerminal(status), isTrue);
  });

  test('canRetryPayment controls payment-session retry visibility', () {
    final order = _order(status: OrderStatus.pendingPayment);
    final retryable = _paymentStatus(
      transactionStatus: PaymentTransactionStatus.expired,
      orderPaymentStatus: PaymentStatus.unpaid,
      orderStatus: OrderStatus.pendingPayment,
      canRetryPayment: true,
    );
    final blocked = _paymentStatus(
      transactionStatus: PaymentTransactionStatus.expired,
      orderPaymentStatus: PaymentStatus.unpaid,
      orderStatus: OrderStatus.pendingPayment,
    );

    expect(
      KioskStatusPresenter.canRetryPaymentSession(
        order,
        retryable,
        expired: true,
        timedOut: false,
        hasTrackingError: false,
      ),
      isTrue,
    );
    expect(
      KioskStatusPresenter.canRetryPaymentSession(
        order,
        blocked,
        expired: true,
        timedOut: false,
        hasTrackingError: false,
      ),
      isFalse,
    );
    expect(
      KioskStatusPresenter.canRetryPaymentSession(
        order,
        retryable,
        expired: true,
        timedOut: false,
        hasTrackingError: true,
      ),
      isFalse,
    );
  });

  test('paid terminal state stops payment polling', () {
    final pending = _paymentStatus(
      transactionStatus: PaymentTransactionStatus.pending,
      orderPaymentStatus: PaymentStatus.unpaid,
      orderStatus: OrderStatus.pendingPayment,
    );
    final paid = _paymentStatus(
      transactionStatus: PaymentTransactionStatus.paid,
      orderPaymentStatus: PaymentStatus.paid,
      orderStatus: OrderStatus.paid,
    );
    final expired = _paymentStatus(
      transactionStatus: PaymentTransactionStatus.expired,
      orderPaymentStatus: PaymentStatus.unpaid,
      orderStatus: OrderStatus.pendingPayment,
      canRetryPayment: true,
    );

    expect(KioskStatusPresenter.shouldPollPayment(pending), isTrue);
    expect(KioskStatusPresenter.shouldPollPayment(paid), isFalse);
    expect(KioskStatusPresenter.shouldPollPayment(expired), isFalse);
  });

  test('local session expiry uses an explicit expired state', () {
    final view = KioskStatusPresenter.payment(
      null,
      order: _order(status: OrderStatus.pendingPayment),
      primary: Colors.teal,
      success: Colors.green,
      warning: Colors.orange,
      danger: Colors.red,
      timedOut: false,
      expired: true,
    );

    expect(view.title, 'Mã thanh toán đã hết hạn');
  });
}

KioskStatusViewData _presentPayment(PaymentTransactionStatus status) {
  return KioskStatusPresenter.payment(
    _paymentStatus(
      transactionStatus: status,
      orderPaymentStatus: status == PaymentTransactionStatus.cancelled
          ? PaymentStatus.cancelled
          : status == PaymentTransactionStatus.failed
          ? PaymentStatus.failed
          : PaymentStatus.unpaid,
      orderStatus: OrderStatus.pendingPayment,
    ),
    order: _order(status: OrderStatus.pendingPayment),
    primary: Colors.teal,
    success: Colors.green,
    warning: Colors.orange,
    danger: Colors.red,
    timedOut: false,
  );
}

KioskStatusViewData _present(OrderStatus status) {
  return KioskStatusPresenter.order(
    _order(status: status, paymentStatus: PaymentStatus.paid),
    primary: Colors.teal,
    success: Colors.green,
    warning: Colors.orange,
    danger: Colors.red,
  );
}

PaymentStatusResult _paymentStatus({
  required PaymentTransactionStatus transactionStatus,
  required PaymentStatus orderPaymentStatus,
  required OrderStatus orderStatus,
  bool canRetryPayment = false,
  bool requiresStaffSupport = false,
}) {
  return PaymentStatusResult(
    paymentTransactionId: 'payment-id',
    orderId: 'order-id',
    provider: 'PayOS',
    paymentTransactionStatus: transactionStatus,
    orderPaymentStatus: orderPaymentStatus,
    orderStatus: orderStatus,
    amount: 35000,
    currency: 'VND',
    customerStatus: 'Preparing',
    customerStatusMessage: 'Preparing order.',
    canRetryPayment: canRetryPayment,
    requiresStaffSupport: requiresStaffSupport,
  );
}

OrderResult _order({
  required OrderStatus status,
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
    placedAt: DateTime.utc(2026, 6, 18),
    customerStatus: status.name,
    customerStatusMessage: '',
    canRetryPayment: false,
    requiresStaffSupport: false,
    items: const [],
  );
}
