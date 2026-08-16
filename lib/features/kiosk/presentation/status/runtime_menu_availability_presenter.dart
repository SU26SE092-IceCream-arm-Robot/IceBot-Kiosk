import 'package:icebot_kiosk/core/error/api_exception.dart';

class RuntimeMenuAvailabilityViewData {
  const RuntimeMenuAvailabilityViewData({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;
}

abstract final class RuntimeMenuAvailabilityPresenter {
  static RuntimeMenuAvailabilityViewData fromError(ApiException error) {
    final message = error.message.trim();

    return switch (message) {
      'Kiosk not found.' => const RuntimeMenuAvailabilityViewData(
        title: 'Không tìm thấy kiosk',
        message: 'Kiosk này chưa được đăng ký hoặc không còn tồn tại.',
      ),
      'Kiosk is not active for sales.' => const RuntimeMenuAvailabilityViewData(
        title: 'Kiosk chưa sẵn sàng phục vụ',
        message: 'Kiosk chưa được kích hoạt để nhận đơn hàng.',
      ),
      'Kiosk is not currently reachable for online sales.' =>
        const RuntimeMenuAvailabilityViewData(
          title: 'Kiosk đang mất kết nối',
          message: 'Chưa thể nhận đơn mới cho đến khi kết nối được khôi phục.',
        ),
      'Store is temporarily not accepting new orders.' =>
        const RuntimeMenuAvailabilityViewData(
          title: 'Cửa hàng đang tạm dừng nhận đơn',
          message: 'Vui lòng quay lại sau hoặc liên hệ nhân viên tại cửa hàng.',
        ),
      'Store is currently closed.' => const RuntimeMenuAvailabilityViewData(
        title: 'Cửa hàng hiện đang đóng cửa',
        message: 'Vui lòng quay lại trong khung giờ hoạt động của cửa hàng.',
      ),
      'Store is not active for sales.' => const RuntimeMenuAvailabilityViewData(
        title: 'Cửa hàng chưa sẵn sàng phục vụ',
        message: 'Cửa hàng chưa được kích hoạt để nhận đơn hàng.',
      ),
      'Organization is not active for sales.' =>
        const RuntimeMenuAvailabilityViewData(
          title: 'Điểm bán chưa sẵn sàng phục vụ',
          message: 'Hiện chưa thể nhận đơn hàng tại điểm bán này.',
        ),
      'Kiosk sales scope could not be verified.' =>
        const RuntimeMenuAvailabilityViewData(
          title: 'Kiosk chưa hoàn tất thiết lập',
          message: 'Phạm vi cửa hàng của kiosk chưa được cấu hình đầy đủ.',
        ),
      'Store opening hours configuration is invalid.' ||
      'Store time zone configuration is invalid.' =>
        const RuntimeMenuAvailabilityViewData(
          title: 'Chưa xác định được giờ phục vụ',
          message: 'Vui lòng liên hệ nhân viên để kiểm tra cấu hình cửa hàng.',
        ),
      _
          when message.startsWith(
            'Kiosk is not accepting orders while its operational state is ',
          ) =>
        RuntimeMenuAvailabilityViewData(
          title: _operationalTitle(message),
          message: 'Kiosk hiện không nhận đơn mới. Vui lòng quay lại sau.',
        ),
      _ => RuntimeMenuAvailabilityViewData(
        title: switch (error.type) {
          ApiErrorType.notFound => 'Không tìm thấy kiosk',
          ApiErrorType.conflict => 'Kiosk chưa sẵn sàng phục vụ',
          ApiErrorType.network || ApiErrorType.timeout => 'Không thể kết nối',
          ApiErrorType.validation => 'Cấu hình kiosk không hợp lệ',
          _ => 'Không thể tải menu',
        },
        message: error.type == ApiErrorType.conflict
            ? 'Kiosk hiện không thể nhận đơn mới. Vui lòng thử lại sau.'
            : message,
      ),
    };
  }

  static String _operationalTitle(String message) {
    if (message.contains('Maintenance')) return 'Kiosk đang được bảo trì';
    if (message.contains('Cleaning')) return 'Kiosk đang được vệ sinh';
    if (message.contains('Restocking')) return 'Kiosk đang bổ sung hàng';
    if (message.contains('EmergencyStopRequested')) {
      return 'Kiosk đang tạm dừng khẩn cấp';
    }
    if (message.contains('OutOfService')) return 'Kiosk đang ngừng phục vụ';
    return 'Kiosk đang tạm dừng nhận đơn';
  }
}
