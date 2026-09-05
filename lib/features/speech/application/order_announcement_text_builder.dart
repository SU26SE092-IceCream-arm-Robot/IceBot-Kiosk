import 'package:icebot_kiosk/features/speech/application/kiosk_speech_service.dart';
import 'package:icebot_kiosk/features/speech/domain/order_number_speech_formatter.dart';

class OrderAnnouncementTextBuilder {
  const OrderAnnouncementTextBuilder({
    this.formatter = const OrderNumberSpeechFormatter(),
  });

  final OrderNumberSpeechFormatter formatter;

  String build(String orderNumber, OrderAnnouncementType type) {
    final spokenCode = formatter.format(orderNumber);
    if (spokenCode.isEmpty) {
      return switch (type) {
        OrderAnnouncementType.paymentSuccess =>
          'Thanh toán thành công. Mã đơn hàng đang hiển thị trên màn hình.',
        OrderAnnouncementType.completed =>
          'Mã đơn hàng đang hiển thị trên màn hình đã hoàn thành. Quý khách vui lòng lấy sản phẩm.',
      };
    }

    return switch (type) {
      OrderAnnouncementType.paymentSuccess =>
        'Thanh toán thành công. Mã đơn hàng của quý khách là $spokenCode.',
      OrderAnnouncementType.completed =>
        'Mã đơn hàng $spokenCode đã hoàn thành. Quý khách vui lòng lấy sản phẩm.',
    };
  }
}
