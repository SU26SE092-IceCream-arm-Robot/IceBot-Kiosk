import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/setup/data/local/auth_session_store.dart';
import 'package:icebot_kiosk/features/setup/data/repositories/auth_repository.dart';
import 'package:icebot_kiosk/features/setup/presentation/state/auth_controller.dart';
import 'package:icebot_kiosk/main.dart';

void main() {
  testWidgets('app builds and requires Manager setup', (
    WidgetTester tester,
  ) async {
    final authController = AuthController(
      repository: AuthRepository(DioClient(baseUrl: 'https://api.test')),
      sessionStore: MemoryAuthSessionStore(),
    );
    await authController.restore();
    await tester.pumpWidget(MyApp(authController: authController));
    await tester.pump();

    expect(find.text('Thiết lập IceBot Kiosk'), findsOneWidget);
    expect(find.text('Đăng nhập Manager'), findsOneWidget);
    expect(find.textContaining('ICEBOT_KIOSK_ID'), findsNothing);
  });
}
