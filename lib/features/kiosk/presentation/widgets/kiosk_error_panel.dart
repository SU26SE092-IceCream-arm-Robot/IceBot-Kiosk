import 'package:flutter/material.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_panels.dart';

class KioskErrorPanel extends StatelessWidget {
  const KioskErrorPanel({
    required this.title,
    required this.error,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final ApiException? error;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final helperText = _helperText(error);
    final primaryMessage = _primaryMessage(error);
    final layout = KioskLayoutSpec.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: layout.maxPortraitPanelWidth),
        child: Padding(
          padding: EdgeInsets.all(layout.screenPadding),
          child: KioskSectionCard(
            padding: EdgeInsets.symmetric(
              horizontal: layout.isCompact ? 26 : 42,
              vertical: layout.isCompact ? 34 : 46,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: layout.isCompact ? 104 : 116,
                  height: layout.isCompact ? 104 : 116,
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.error),
                  ),
                  child: Icon(
                    _iconFor(error),
                    color: colorScheme.error,
                    size: layout.isCompact ? 58 : 66,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  primaryMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (helperText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    helperText,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 30),
                  FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.refresh),
                    label: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(ApiException? error) {
    return switch (error?.type) {
      ApiErrorType.timeout => Icons.timer_off_outlined,
      ApiErrorType.network => Icons.wifi_off_outlined,
      ApiErrorType.notFound => Icons.search_off_outlined,
      ApiErrorType.conflict => Icons.pause_circle_outline,
      ApiErrorType.upstream => Icons.payments_outlined,
      _ => Icons.error_outline,
    };
  }

  String? _helperText(ApiException? error) {
    return switch (error?.type) {
      ApiErrorType.timeout =>
        'Kết nối đang chậm. Vui lòng thử lại sau vài giây.',
      ApiErrorType.network => 'Kiểm tra mạng của kiosk hoặc kết nối backend.',
      ApiErrorType.notFound => 'Kiosk hoặc dữ liệu menu chưa được cấu hình.',
      ApiErrorType.conflict =>
        'Kiosk hoặc sản phẩm đang tạm thời không sẵn sàng.',
      ApiErrorType.upstream =>
        error?.message == null ? null : 'Chi tiết kỹ thuật: ${error!.message}',
      _ => null,
    };
  }

  String _primaryMessage(ApiException? error) {
    if (error?.type == ApiErrorType.upstream) {
      return 'Chưa thể tạo mã thanh toán. Vui lòng thử lại hoặc nhờ nhân viên hỗ trợ.';
    }

    return error?.message ?? 'Đã xảy ra lỗi. Vui lòng thử lại.';
  }
}
