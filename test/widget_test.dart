import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/menu_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/order_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/payment_repository.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_controller.dart';
import 'package:icebot_kiosk/main.dart';

void main() {
  testWidgets('app shows the tablet setup path when it is not provisioned', (
    WidgetTester tester,
  ) async {
    final controller = KioskController(
      menuRepository: MenuRepository(DioClient(baseUrl: 'https://api.test')),
      orderRepository: OrderRepository(DioClient(baseUrl: 'https://api.test')),
      paymentRepository: PaymentRepository(
        DioClient(baseUrl: 'https://api.test'),
      ),
    );

    await tester.pumpWidget(MyApp(kioskController: controller));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tablet'), findsOneWidget);
  });
}
