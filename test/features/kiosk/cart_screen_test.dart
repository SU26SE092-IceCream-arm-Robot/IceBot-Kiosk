import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/config/themes/app_theme.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/demo_kiosk_repositories.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/screens/cart_screen.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_controller.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';

void main() {
  testWidgets('compact cart does not overflow and keeps quantity actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(650, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = DemoKioskStore();
    final controller = KioskController(
      menuRepository: DemoMenuRepository(store),
      orderRepository: DemoOrderRepository(store),
      paymentRepository: DemoPaymentRepository(store),
      kioskId: AppConfig.demoKioskId,
    );
    await controller.loadMenu();
    controller.addToCart(controller.menuItems.first);

    await tester.pumpWidget(
      KioskScope(
        controller: controller,
        disposeController: false,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CartScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Tiếp tục thanh toán'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    expect(controller.cartItemCount, 2);
    expect(controller.cartTotal, 70000);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pump();
    expect(controller.cartItemCount, 1);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(controller.isCartEmpty, isTrue);
    expect(find.text('Giỏ hàng đang trống'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
