import 'dart:async';

import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/payment_models.dart';
import 'package:icebot_kiosk/features/speech/application/kiosk_speech_service.dart';

class OrderAnnouncementCoordinator {
  OrderAnnouncementCoordinator(this._speechService);

  final KioskSpeechService _speechService;
  final Set<String> _consumed = <String>{};

  void prepareOrder(OrderResult order) {
    unawaited(
      _speechService
          .prepareOrder(orderId: order.id, orderNumber: order.orderNumber)
          .catchError((Object _) {}),
    );
  }

  void registerRestoredOrder(OrderResult order) {
    if (order.paymentStatus == PaymentStatus.paid) {
      _consumed.add(_key(order.id, OrderAnnouncementType.paymentSuccess));
    }
    if (order.status == OrderStatus.completed) {
      _consumed.add(_key(order.id, OrderAnnouncementType.completed));
    }
    prepareOrder(order);
  }

  void observePayment(OrderResult? order, PaymentStatusResult status) {
    if (order == null ||
        status.paymentTransactionStatus != PaymentTransactionStatus.paid &&
            status.orderPaymentStatus != PaymentStatus.paid) {
      return;
    }

    _announceOnce(order, OrderAnnouncementType.paymentSuccess);
  }

  void observeOrder(OrderResult order) {
    if (order.status == OrderStatus.completed) {
      _announceOnce(order, OrderAnnouncementType.completed);
    }
  }

  void _announceOnce(OrderResult order, OrderAnnouncementType type) {
    if (!_consumed.add(_key(order.id, type))) {
      return;
    }
    unawaited(
      _speechService
          .playOrderAnnouncement(
            orderId: order.id,
            orderNumber: order.orderNumber,
            type: type,
          )
          .catchError((Object _) => const SpeechPlaybackResult(success: false)),
    );
  }

  String _key(String orderId, OrderAnnouncementType type) =>
      '$orderId:${type.name}';
}
