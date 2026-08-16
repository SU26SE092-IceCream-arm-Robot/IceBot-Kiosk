import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/status/runtime_menu_availability_presenter.dart';

void main() {
  test('distinguishes store closed from a sales pause', () {
    final closed = RuntimeMenuAvailabilityPresenter.fromError(
      const ApiException(
        type: ApiErrorType.conflict,
        message: 'Store is currently closed.',
      ),
    );
    final paused = RuntimeMenuAvailabilityPresenter.fromError(
      const ApiException(
        type: ApiErrorType.conflict,
        message: 'Store is temporarily not accepting new orders.',
      ),
    );

    expect(closed.title, 'Cửa hàng hiện đang đóng cửa');
    expect(paused.title, 'Cửa hàng đang tạm dừng nhận đơn');
  });

  test('distinguishes connectivity from kiosk lifecycle readiness', () {
    final unreachable = RuntimeMenuAvailabilityPresenter.fromError(
      const ApiException(
        type: ApiErrorType.conflict,
        message: 'Kiosk is not currently reachable for online sales.',
      ),
    );
    final inactive = RuntimeMenuAvailabilityPresenter.fromError(
      const ApiException(
        type: ApiErrorType.conflict,
        message: 'Kiosk is not active for sales.',
      ),
    );

    expect(unreachable.title, 'Kiosk đang mất kết nối');
    expect(inactive.title, 'Kiosk chưa sẵn sàng phục vụ');
  });

  test('maps operational pauses without exposing backend enum text', () {
    final maintenance = RuntimeMenuAvailabilityPresenter.fromError(
      const ApiException(
        type: ApiErrorType.conflict,
        message:
            'Kiosk is not accepting orders while its operational state is Maintenance.',
      ),
    );

    expect(maintenance.title, 'Kiosk đang được bảo trì');
    expect(maintenance.message, isNot(contains('Maintenance')));
  });
}
