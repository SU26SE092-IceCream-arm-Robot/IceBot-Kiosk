import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/runtime_menu_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/menu_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/order_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/payment_repository.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/screens/menu_screen.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_controller.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';

void main() {
  testWidgets('shows empty state when backend returns no menu items', (
    tester,
  ) async {
    await _pumpMenu(tester, response: _emptyMenu());

    expect(find.text('Menu hiện chưa có món'), findsOneWidget);
    expect(find.text('Tải lại menu'), findsOneWidget);
  });

  testWidgets('shows retry state when backend is offline', (tester) async {
    await _pumpMenu(
      tester,
      response: const ApiException(
        type: ApiErrorType.network,
        message: 'Không thể kết nối đến máy chủ.',
      ),
    );

    expect(find.text('Không thể kết nối'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('shows clear invalid kiosk state for backend 404', (
    tester,
  ) async {
    await _pumpMenu(
      tester,
      response: const ApiException(
        type: ApiErrorType.notFound,
        statusCode: 404,
        message: 'Kiosk not found.',
      ),
    );

    expect(find.text('Không tìm thấy kiosk'), findsOneWidget);
    expect(find.textContaining('chưa được cấu hình'), findsOneWidget);
  });

  testWidgets('shows validation error state when kioskId is missing', (tester) async {
    await _pumpMenu(
      tester,
      response: _emptyMenu(),
      kioskId: '', // Empty kioskId triggers validation error
    );

    expect(find.text('Cấu hình kiosk không hợp lệ'), findsOneWidget);
    expect(find.textContaining('Kiosk chưa được cấu hình. Vui lòng thiết lập Kiosk ID.'), findsOneWidget);
  });
}

Future<void> _pumpMenu(WidgetTester tester, {required Object response, String? kioskId}) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final controller = KioskController(
    menuRepository: _StubMenuRepository(response),
    orderRepository: _StubOrderRepository(),
    paymentRepository: _StubPaymentRepository(),
    kioskId: kioskId ?? 'aec68c48-207d-433d-b2fd-e7ddf7d5346a',
  );

  await tester.pumpWidget(
    MaterialApp(
      home: KioskScope(controller: controller, child: const MenuScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

RuntimeMenuResult _emptyMenu() {
  return RuntimeMenuResult(
    snapshotId: 'snapshot-id',
    kioskId: 'aec68c48-207d-433d-b2fd-e7ddf7d5346a',
    generatedAt: DateTime.utc(2026, 7, 1),
    expiresAt: DateTime.utc(2026, 7, 1, 0, 0, 15),
    availabilitySource: 'CloudSalesCatalog',
    containsMachineRuntimeState: false,
    items: const [],
  );
}

class _StubMenuRepository extends MenuRepository {
  _StubMenuRepository(this.response)
    : super(DioClient(baseUrl: 'http://localhost'));

  final Object response;

  @override
  Future<RuntimeMenuResult> getRuntimeMenu(String kioskId) async {
    if (response is ApiException) {
      throw response;
    }
    return response as RuntimeMenuResult;
  }
}

class _StubOrderRepository extends OrderRepository {
  _StubOrderRepository() : super(DioClient(baseUrl: 'http://localhost'));
}

class _StubPaymentRepository extends PaymentRepository {
  _StubPaymentRepository() : super(DioClient(baseUrl: 'http://localhost'));
}
