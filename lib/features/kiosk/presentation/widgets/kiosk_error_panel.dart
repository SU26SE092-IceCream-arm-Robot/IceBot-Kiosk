import 'package:flutter/material.dart';
import 'package:icebot_kiosk/config/themes/icebot_colors.dart';
import 'package:icebot_kiosk/config/themes/icebot_spacing.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_panels.dart';

/// Full-screen error panel — Frost-Tech reskin.
///
/// Maps [ApiException.type] to a contextual icon and helper text.
/// The public constructor and all parameters are unchanged — all existing call
/// sites continue to compile without modification.
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
    final scheme = Theme.of(context).colorScheme;
    final layout = KioskLayoutSpec.of(context);
    final helperText = _helperText(error);
    final primaryMessage = _primaryMessage(error);
    final iconBoxSize = layout.isCompact ? 104.0 : 120.0;
    final iconSize = layout.isCompact ? 58.0 : 70.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: layout.maxPortraitPanelWidth),
        child: Padding(
          padding: EdgeInsets.all(layout.screenPadding),
          child: KioskSectionCard(
            padding: EdgeInsets.symmetric(
              horizontal: layout.isCompact ? 28 : 44,
              vertical: layout.isCompact ? 36 : 50,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Error icon box
                Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  decoration: BoxDecoration(
                    color: IceBotColors.dangerContainer,
                    borderRadius: BorderRadius.circular(IceBotSpacing.cardRadius),
                    border: Border.all(
                      color: IceBotColors.dangerRed.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(
                    _iconFor(error),
                    color: IceBotColors.dangerRed,
                    size: iconSize,
                  ),
                ),
                const SizedBox(height: 28),
                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 16),
                // Primary message
                Text(
                  primaryMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                // Helper text
                if (helperText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    helperText,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                // Action button
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.refresh_rounded, size: 22),
                    label: Text(actionLabel!),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(
                        double.minPositive,
                        IceBotSpacing.primaryCTAHeight,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  IconData _iconFor(ApiException? error) {
    return switch (error?.type) {
      ApiErrorType.timeout => Icons.timer_off_outlined,
      ApiErrorType.network => Icons.wifi_off_outlined,
      ApiErrorType.notFound => Icons.search_off_outlined,
      ApiErrorType.conflict => Icons.pause_circle_outline,
      ApiErrorType.upstream => Icons.payments_outlined,
      _ => Icons.error_outline_rounded,
    };
  }

  String? _helperText(ApiException? error) {
    return switch (error?.type) {
      ApiErrorType.timeout =>
        'Kết nối đang chậm. Vui lòng thử lại sau vài giây.',
      ApiErrorType.network =>
        'Kiểm tra mạng của kiosk hoặc kết nối backend.',
      ApiErrorType.notFound =>
        'Kiosk hoặc dữ liệu menu chưa được cấu hình.',
      ApiErrorType.conflict =>
        'Kiosk hoặc sản phẩm đang tạm thời không sẵn sàng.',
      ApiErrorType.upstream => error?.message == null
          ? null
          : 'Chi tiết kỹ thuật: ${error!.message}',
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
