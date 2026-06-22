import 'package:flutter/material.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';

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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _iconFor(error),
                      color: colorScheme.error,
                      size: 64,
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
                    error?.message ?? 'Đã xảy ra lỗi. Vui lòng thử lại.',
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
                    const SizedBox(height: 28),
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
      ApiErrorType.upstream => 'Nhà cung cấp thanh toán chưa phản hồi.',
      _ => null,
    };
  }
}
