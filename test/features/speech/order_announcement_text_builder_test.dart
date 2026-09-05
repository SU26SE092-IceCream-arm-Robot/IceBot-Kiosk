import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/features/speech/application/kiosk_speech_service.dart';
import 'package:icebot_kiosk/features/speech/application/order_announcement_text_builder.dart';

void main() {
  const builder = OrderAnnouncementTextBuilder();

  test('builds the exact payment success announcement', () {
    expect(
      builder.build('ORD-001', OrderAnnouncementType.paymentSuccess),
      'Thanh toán thành công. Mã đơn hàng của quý khách là không, không, một.',
    );
  });

  test('builds the exact completed announcement', () {
    expect(
      builder.build('ORD-001', OrderAnnouncementType.completed),
      'Mã đơn hàng không, không, một đã hoàn thành. Quý khách vui lòng lấy sản phẩm.',
    );
  });

  test('uses the on-screen fallback when the order number is empty', () {
    expect(
      builder.build('', OrderAnnouncementType.paymentSuccess),
      'Thanh toán thành công. Mã đơn hàng đang hiển thị trên màn hình.',
    );
    expect(
      builder.build('', OrderAnnouncementType.completed),
      'Mã đơn hàng đang hiển thị trên màn hình đã hoàn thành. Quý khách vui lòng lấy sản phẩm.',
    );
  });
}
