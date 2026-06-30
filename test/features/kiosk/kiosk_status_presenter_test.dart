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

    expect(
      KioskStatusPresenter.canCancelBeforePaid(pendingOrder, null),
      isTrue,
    );
    expect(KioskStatusPresenter.canCancelBeforePaid(paidOrder, null), isFalse);
  });
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
    canRetryPayment: false,
    requiresStaffSupport: false,
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
