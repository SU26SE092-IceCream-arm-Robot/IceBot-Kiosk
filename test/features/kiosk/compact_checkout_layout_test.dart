import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/config/themes/app_theme.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/demo_kiosk_repositories.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/screens/checkout_screen.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/screens/product_detail_screen.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_controller.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';

void main() {
  testWidgets('compact product detail does not overflow', (tester) async {
    final controller = await _demoController();

    await _pumpCompact(
      tester,
      controller,
      ProductDetailScreen(menuItemId: controller.menuItems.first.menuItemId),
    );

    expect(find.text('Chi tiết món'), findsOneWidget);
    expect(find.text('Thêm vào giỏ hàng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact checkout does not overflow', (tester) async {
    final controller = await _demoController();
    controller.addToCart(controller.menuItems.first);

    await _pumpCompact(tester, controller, const CheckoutScreen());

    expect(find.text('Xác nhận đơn hàng'), findsOneWidget);
    expect(find.text('Tạo mã QR thanh toán'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<KioskController> _demoController() async {
  final store = DemoKioskStore();
  final controller = KioskController(
    menuRepository: DemoMenuRepository(store),
    orderRepository: DemoOrderRepository(store),
    paymentRepository: DemoPaymentRepository(store),
    kioskId: AppConfig.demoKioskId,
  );
  await controller.loadMenu();
  return controller;
}

Future<void> _pumpCompact(
  WidgetTester tester,
  KioskController controller,
  Widget screen,
) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    controller.dispose();
  });

  await tester.pumpWidget(
    KioskScope(
      controller: controller,
      disposeController: false,
      child: MaterialApp(theme: AppTheme.lightTheme, home: screen),
    ),
  );
  await tester.pump();
}
