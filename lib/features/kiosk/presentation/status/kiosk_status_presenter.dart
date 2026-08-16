import 'package:flutter/material.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/payment_models.dart';

class KioskStatusViewData {
  const KioskStatusViewData({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;
}

class KioskStatusPresenter {
  KioskStatusPresenter._();

  static KioskStatusViewData payment(
    PaymentStatusResult? status, {
    OrderResult? order,
    required Color primary,
    required Color success,
    required Color warning,
    required Color danger,
    required bool timedOut,
    bool expired = false,
  }) {
    final requiresStaffSupport =
        status?.requiresStaffSupport == true ||
        order?.requiresStaffSupport == true ||
        status?.orderStatus == OrderStatus.refundRequired ||
        status?.orderStatus == OrderStatus.executionRejected ||
        status?.orderStatus == OrderStatus.fulfillmentIssue ||
        order?.status == OrderStatus.refundRequired ||
        order?.status == OrderStatus.executionRejected ||
        order?.status == OrderStatus.fulfillmentIssue;
    if (requiresStaffSupport) {
      return KioskStatusViewData(
        title: 'Cần nhân viên hỗ trợ',
        message: status?.customerStatusMessage.isNotEmpty == true
            ? status!.customerStatusMessage
            : 'Vui lòng liên hệ nhân viên tại kiosk để được hỗ trợ.',
        icon: Icons.support_agent_outlined,
        color: warning,
      );
    }

    if (expired) {
      return KioskStatusViewData(
        title: 'Mã thanh toán đã hết hạn',
        message: 'Bạn có thể tạo lại mã nếu đơn hàng vẫn cho phép thanh toán.',
        icon: Icons.hourglass_disabled_outlined,
        color: warning,
      );
    }

    if (timedOut) {
      return KioskStatusViewData(
        title: 'Chưa ghi nhận thanh toán',
        message: 'Vui lòng thử lại hoặc mở trang thanh toán.',
        icon: Icons.timer_off_outlined,
        color: warning,
      );
    }

    final transactionStatus = status?.paymentTransactionStatus;
    final orderPaymentStatus = status?.orderPaymentStatus;
    final currentOrderPaymentStatus = order?.paymentStatus;
    final currentOrderStatus = order?.status;

    if (transactionStatus == PaymentTransactionStatus.paid ||
        orderPaymentStatus == PaymentStatus.paid ||
        currentOrderPaymentStatus == PaymentStatus.paid) {
      return KioskStatusViewData(
        title: 'Đã thanh toán',
        message: 'IceBot đã ghi nhận thanh toán và đang cập nhật đơn hàng.',
        icon: Icons.check_circle_outline,
        color: success,
      );
    }

    if (transactionStatus == PaymentTransactionStatus.cancelled ||
        orderPaymentStatus == PaymentStatus.cancelled ||
        currentOrderPaymentStatus == PaymentStatus.cancelled ||
        currentOrderStatus == OrderStatus.cancelled) {
      return KioskStatusViewData(
        title: 'Thanh toán đã hủy',
        message: 'Bạn có thể tạo đơn mới khi sẵn sàng.',
        icon: Icons.cancel_outlined,
        color: warning,
      );
    }

    if (transactionStatus == PaymentTransactionStatus.failed ||
        orderPaymentStatus == PaymentStatus.failed ||
        currentOrderStatus == OrderStatus.failed) {
      return KioskStatusViewData(
        title: 'Thanh toán thất bại',
        message: 'Vui lòng thử lại hoặc liên hệ nhân viên hỗ trợ.',
        icon: Icons.error_outline,
        color: danger,
      );
    }

    if (transactionStatus == PaymentTransactionStatus.expired) {
      return KioskStatusViewData(
        title: 'Mã thanh toán đã hết hạn',
        message: 'Bạn có thể tạo lại mã nếu đơn hàng vẫn cho phép thanh toán.',
        icon: Icons.hourglass_disabled_outlined,
        color: warning,
      );
    }

    if (transactionStatus == PaymentTransactionStatus.authorized ||
        orderPaymentStatus == PaymentStatus.authorized) {
      return KioskStatusViewData(
        title: 'Đang xác nhận thanh toán',
        message: 'Vui lòng chờ trong giây lát.',
        icon: Icons.sync_outlined,
        color: primary,
      );
    }

    return KioskStatusViewData(
      title: 'Đang chờ thanh toán',
      message: 'Quét mã QR và hoàn tất thanh toán trên thiết bị của bạn.',
      icon: Icons.qr_code_2_outlined,
      color: primary,
    );
  }

  static bool isPaymentTerminal(PaymentStatusResult status) {
    return status.paymentTransactionStatus == PaymentTransactionStatus.paid ||
        status.paymentTransactionStatus == PaymentTransactionStatus.failed ||
        status.paymentTransactionStatus == PaymentTransactionStatus.cancelled ||
        status.paymentTransactionStatus == PaymentTransactionStatus.expired ||
        status.paymentTransactionStatus == PaymentTransactionStatus.refunded ||
        status.orderPaymentStatus == PaymentStatus.paid ||
        status.orderPaymentStatus == PaymentStatus.failed ||
        status.orderPaymentStatus == PaymentStatus.cancelled ||
        status.orderPaymentStatus == PaymentStatus.refunded ||
        status.requiresStaffSupport ||
        status.orderStatus == OrderStatus.cancelled ||
        status.orderStatus == OrderStatus.failed ||
        status.orderStatus == OrderStatus.executionRejected ||
        status.orderStatus == OrderStatus.refundRequired ||
        status.orderStatus == OrderStatus.refunded ||
        status.orderStatus == OrderStatus.compensated ||
        status.orderStatus == OrderStatus.completed;
  }

  static bool isPaymentPaid(PaymentStatusResult status) {
    return status.paymentTransactionStatus == PaymentTransactionStatus.paid ||
        status.orderPaymentStatus == PaymentStatus.paid;
  }

  static bool shouldPollPayment(PaymentStatusResult? status) {
    return status == null || !isPaymentTerminal(status);
  }

  static bool canRetryPaymentSession(
    OrderResult order,
    PaymentStatusResult? status, {
    required bool expired,
    required bool timedOut,
    required bool hasTrackingError,
  }) {
    if (hasTrackingError) {
      return false;
    }

    final retryAllowed = status?.canRetryPayment ?? order.canRetryPayment;
    final reachedRetryState =
        expired || timedOut || (status != null && isPaymentTerminal(status));
    return retryAllowed && reachedRetryState;
  }

  static KioskStatusViewData order(
    OrderResult order, {
    required Color primary,
    required Color success,
    required Color warning,
    required Color danger,
  }) {
    if (order.requiresStaffSupport) {
      return KioskStatusViewData(
        title: 'Cần nhân viên hỗ trợ',
        message: order.customerStatusMessage.isNotEmpty
            ? order.customerStatusMessage
            : 'Vui lòng liên hệ nhân viên tại kiosk.',
        icon: Icons.support_agent_outlined,
        color: warning,
      );
    }

    return switch (order.status) {
      OrderStatus.draft => KioskStatusViewData(
        title: 'Đơn hàng đang nhập',
        message: 'Đơn hàng chưa được gửi đi.',
        icon: Icons.edit_note_outlined,
        color: warning,
      ),
      OrderStatus.pendingPayment => KioskStatusViewData(
        title: 'Đang chờ thanh toán',
        message: 'Vui lòng hoàn tất thanh toán QR.',
        icon: Icons.qr_code_2_outlined,
        color: primary,
      ),
      OrderStatus.paid => KioskStatusViewData(
        title: 'Đã thanh toán',
        message: 'IceBot đã ghi nhận thanh toán và sắp chuẩn bị đơn hàng.',
        icon: Icons.check_circle_outline,
        color: success,
      ),
      OrderStatus.readyForFulfillment => KioskStatusViewData(
        title: 'Sẵn sàng hoàn tất đơn',
        message: 'Hệ thống đang chuẩn bị hoàn tất đơn hàng của bạn.',
        icon: Icons.schedule_outlined,
        color: primary,
      ),
      OrderStatus.accepted => KioskStatusViewData(
        title: 'Hệ thống đã nhận đơn',
        message: 'Đơn hàng đã được tiếp nhận và đang chờ bước chuẩn bị.',
        icon: Icons.inventory_2_outlined,
        color: primary,
      ),
      OrderStatus.preparing => KioskStatusViewData(
        title: 'Robot đang chuẩn bị',
        message: 'Đơn hàng đang được xử lý. Vui lòng đợi trong giây lát.',
        icon: Icons.blender_outlined,
        color: primary,
      ),
      OrderStatus.ready => KioskStatusViewData(
        title: 'Món đã sẵn sàng',
        message: 'Vui lòng nhận kem tại khu vực lấy hàng.',
        icon: Icons.shopping_bag_outlined,
        color: success,
      ),
      OrderStatus.completed => KioskStatusViewData(
        title: 'Hoàn tất',
        message: 'Cảm ơn bạn đã sử dụng IceBot.',
        icon: Icons.check_circle_outline,
        color: success,
      ),
      OrderStatus.cancelled => KioskStatusViewData(
        title: 'Đơn hàng đã hủy',
        message: 'Bạn có thể tạo đơn mới khi sẵn sàng.',
        icon: Icons.cancel_outlined,
        color: warning,
      ),
      OrderStatus.failed ||
      OrderStatus.executionRejected ||
      OrderStatus.fulfillmentIssue => KioskStatusViewData(
        title: 'Đơn hàng gặp lỗi',
        message: 'Vui lòng liên hệ nhân viên hỗ trợ.',
        icon: Icons.error_outline,
        color: danger,
      ),
      OrderStatus.refundRequired => KioskStatusViewData(
        title: 'Cần hỗ trợ hoàn tiền',
        message: 'Vui lòng liên hệ nhân viên hỗ trợ.',
        icon: Icons.support_agent_outlined,
        color: warning,
      ),
      OrderStatus.refunded => KioskStatusViewData(
        title: 'Đã hoàn tiền',
        message: 'Giao dịch đã được hoàn tiền.',
        icon: Icons.currency_exchange_outlined,
        color: success,
      ),
      OrderStatus.compensated => KioskStatusViewData(
        title: 'Đã hỗ trợ bù',
        message: 'Giao dịch đã được xử lý hỗ trợ.',
        icon: Icons.redeem_outlined,
        color: success,
      ),
      OrderStatus.unknown => KioskStatusViewData(
        title: 'Trạng thái chưa xác định',
        message: 'Vui lòng đợi hoặc liên hệ nhân viên hỗ trợ.',
        icon: Icons.help_outline,
        color: warning,
      ),
    };
  }

  static bool isOrderTerminal(OrderResult order) {
    if (order.requiresStaffSupport) {
      return true;
    }

    return switch (order.status) {
      OrderStatus.completed ||
      OrderStatus.cancelled ||
      OrderStatus.failed ||
      OrderStatus.executionRejected ||
      OrderStatus.fulfillmentIssue ||
      OrderStatus.refundRequired ||
      OrderStatus.refunded ||
      OrderStatus.compensated => true,
      _ => false,
    };
  }

  static bool canCancelBeforePaid(
    OrderResult? order,
    PaymentStatusResult? status,
  ) {
    if (order == null) {
      return false;
    }

    final paid =
        order.paymentStatus == PaymentStatus.paid ||
        status?.orderPaymentStatus == PaymentStatus.paid ||
        status?.paymentTransactionStatus == PaymentTransactionStatus.paid;
    if (paid) {
      return false;
    }

    return order.status == OrderStatus.draft ||
        order.status == OrderStatus.pendingPayment;
  }
}
