import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/config/routes/app_router.dart';
import 'package:icebot_kiosk/config/themes/icebot_colors.dart';
import 'package:icebot_kiosk/config/themes/icebot_spacing.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/payment_models.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/status/kiosk_status_presenter.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/bot_loading_indicator.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/bot_step_rail.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_formatters.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_panels.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/payment_qr_panel.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({required this.orderId, super.key});

  final String orderId;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const Duration _pollInterval = Duration(seconds: 3);
  static const Duration _pollTimeout = Duration(minutes: 5);

  Timer? _timer;
  DateTime? _startedAt;
  bool _startedPolling = false;
  bool _timedOut = false;
  bool _expired = false;
  bool _pollPausedForError = false;
  bool _pollInFlight = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedPolling) {
      return;
    }

    _startedPolling = true;
    _startedAt = DateTime.now();
    _startPolling();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  Future<void> _pollNow() async {
    if (!mounted || _timedOut || _pollInFlight) {
      return;
    }

    final controller = KioskScope.of(context);
    final session = controller.activePaymentSession;
    final now = DateTime.now();
    final expiredBySession = session?.isExpiredAt(now) == true;
    final expiredByTimeout = _startedAt != null && now.difference(_startedAt!) > _pollTimeout;

    if (expiredBySession || expiredByTimeout) {
      setState(() {
        _expired = expiredBySession;
        _timedOut = !expiredBySession;
      });
      _stopPolling();
      return;
    }

    _pollInFlight = true;
    try {
      final status = await controller.refreshPaymentStatus(widget.orderId);
      if (!mounted) {
        return;
      }
      if (status == null) {
        if (controller.trackingError != null) {
          setState(() => _pollPausedForError = true);
          _stopPolling();
        }
        return;
      }

      if (_pollPausedForError) {
        setState(() => _pollPausedForError = false);
      }

      if (KioskStatusPresenter.isPaymentPaid(status)) {
        _stopPolling();
        await controller.refreshOrder(widget.orderId);
        if (mounted) {
          context.go(AppRouter.orderPath(widget.orderId));
        }
        return;
      }

      if (!KioskStatusPresenter.shouldPollPayment(status)) {
        _stopPolling();
      }
    } finally {
      _pollInFlight = false;
    }
  }

  void _startPolling() {
    _stopPolling();
    _pollPausedForError = false;
    _timer = Timer.periodic(_pollInterval, (_) => _pollNow());
    _pollNow();
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = KioskScope.of(context);
    final order = controller.activeOrder;
    final session = controller.activePaymentSession;

    if (order == null || session == null || order.id != widget.orderId) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(28, 20, 28, 12),
                child: BotStepRail(currentStep: 2),
              ),
              Expanded(
                child: KioskEmptyState(
                  title: 'Chưa có phiên thanh toán',
                  message: 'Vui lòng tạo đơn hàng từ giỏ hàng trước khi thanh toán.',
                  icon: Icons.qr_code_2_rounded,
                  actionLabel: 'Về menu',
                  onAction: () => context.go(AppRouter.menu),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final statusView = KioskStatusPresenter.payment(
      controller.activePaymentStatus,
      order: order,
      primary: IceBotColors.icePrimary,
      success: IceBotColors.mintSuccess,
      warning: IceBotColors.warningAmber,
      danger: IceBotColors.dangerRed,
      timedOut: _timedOut,
      expired: _expired,
    );
    final paymentStatus = controller.activePaymentStatus;
    final canCancel = KioskStatusPresenter.canCancelBeforePaid(order, paymentStatus);

    return Scaffold(
      body: SafeArea(
        child: KioskBackdrop(
          child: Column(
            children: [
              // Header section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 28, 12),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: BotStepRail(currentStep: 2),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (canCancel)
                          IconButton(
                            iconSize: 32,
                            onPressed: controller.isCancellingOrder
                                ? null
                                : () async {
                                    _stopPolling();
                                    final cancelled = await controller.cancelActiveOrder();
                                    await controller.refreshPaymentStatus(widget.orderId);
                                    if (mounted && cancelled == null) {
                                      _startPolling();
                                    }
                                  },
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: IceBotColors.botNavy,
                            tooltip: 'Hủy đơn hàng và quay lại',
                          )
                        else
                          const SizedBox(width: 48), // Padding equivalent to icon button
                        const SizedBox(width: 8),
                        Text(
                          'Thanh toán',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content section
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final layout = KioskLayoutSpec.of(context);
                    final useWideLayout = !layout.useSingleColumn && constraints.maxWidth >= 980;
                    final summary = _PaymentSummary(
                      order: order,
                      session: session,
                      statusView: statusView,
                      isPolling: _timer != null,
                      remainingTime: _remainingTime(session.expiresAt),
                      errorMessage: controller.checkoutError?.message ?? controller.trackingError?.message,
                      canRetryPayment: KioskStatusPresenter.canRetryPaymentSession(
                        order,
                        paymentStatus,
                        expired: _expired,
                        timedOut: _timedOut,
                        hasTrackingError: controller.trackingError != null,
                      ),
                      canRetryStatus: _pollPausedForError,
                      isRetryingPayment: controller.isCheckingOut,
                      canCancel: canCancel,
                      canResetSession: controller.canResetKioskSession,
                      isCancelling: controller.isCancellingOrder,
                      onCancel: () async {
                        _stopPolling();
                        final cancelled = await controller.cancelActiveOrder();
                        await controller.refreshPaymentStatus(widget.orderId);
                        if (mounted && cancelled == null) {
                          _startPolling();
                        }
                      },
                      onRetryStatus: () async {
                        setState(() {
                          _pollPausedForError = false;
                          _startedAt = DateTime.now();
                        });
                        _startPolling();
                      },
                      onRetryPayment: () async {
                        _stopPolling();
                        final result = await controller.retryPaymentSession();
                        if (!mounted) {
                          return;
                        }
                        if (result != null) {
                          setState(() {
                            _timedOut = false;
                            _expired = false;
                            _pollPausedForError = false;
                            _startedAt = DateTime.now();
                          });
                          _startPolling();
                        }
                      },
                      onResetSession: () async {
                        _stopPolling();
                        final reset = await controller.resetKioskSession();
                        if (context.mounted && reset) {
                          context.go(AppRouter.menu);
                        }
                      },
                    );
                    final qrPanel = PaymentQrPanel(session: session);

                    return Padding(
                      padding: EdgeInsets.all(layout.screenPadding),
                      child: useWideLayout
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 5, child: summary),
                                const SizedBox(width: 28),
                                Expanded(flex: 6, child: qrPanel),
                              ],
                            )
                          : ListView(
                              padding: EdgeInsets.only(bottom: layout.bottomOverlayPadding),
                              children: [
                                summary,
                                SizedBox(height: layout.sectionGap),
                                qrPanel,
                              ],
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _remainingTime(DateTime? expiresAt) {
    if (expiresAt == null || _expired) {
      return null;
    }

    final remaining = expiresAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      return 'Mã thanh toán đã hết hạn';
    }

    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _PaymentSummary extends StatelessWidget {
  const _PaymentSummary({
    required this.order,
    required this.session,
    required this.statusView,
    required this.isPolling,
    required this.remainingTime,
    required this.errorMessage,
    required this.canRetryPayment,
    required this.canRetryStatus,
    required this.isRetryingPayment,
    required this.canCancel,
    required this.canResetSession,
    required this.isCancelling,
    required this.onCancel,
    required this.onRetryStatus,
    required this.onRetryPayment,
    required this.onResetSession,
  });

  final OrderResult order;
  final PaymentSessionResult session;
  final KioskStatusViewData statusView;
  final bool isPolling;
  final String? remainingTime;
  final String? errorMessage;
  final bool canRetryPayment;
  final bool canRetryStatus;
  final bool isRetryingPayment;
  final bool canCancel;
  final bool canResetSession;
  final bool isCancelling;
  final Future<void> Function() onCancel;
  final Future<void> Function() onRetryStatus;
  final Future<void> Function() onRetryPayment;
  final Future<void> Function() onResetSession;

  @override
  Widget build(BuildContext context) {
    final layout = KioskLayoutSpec.of(context);

    return KioskSectionCard(
      padding: EdgeInsets.all(layout.isCompact ? 24 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusView.icon, color: statusView.color, size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  statusView.title,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(color: statusView.color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            statusView.message,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 32),
          Text(
            'Số tiền cần thanh toán',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            KioskFormatters.money(session.amount, currency: session.currency),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: IceBotColors.icePrimary,
                ),
          ),
          const SizedBox(height: 32),
          _InfoRow(label: 'Mã đơn hàng', value: order.orderNumber),
          _InfoRow(
            label: 'Nhà cung cấp',
            value: session.provider.isEmpty ? 'Đang cập nhật' : session.provider,
          ),
          if (remainingTime != null) _InfoRow(label: 'Thời gian chờ mã', value: remainingTime!),
          if (AppConfig.demoMode) ...[
            const SizedBox(height: 16),
            const _DemoPaymentSummaryNotice(),
          ],
          if (isPolling) ...[
            const SizedBox(height: 24),
            Text(
              'Đang chờ xác nhận thanh toán...',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: IceBotColors.botNavyMuted),
            ),
            const SizedBox(height: 12),
            const BotBeamScanner(),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 24),
            _InlineWarning(message: errorMessage!),
          ],
          const SizedBox(height: 32),
          if (canRetryStatus) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onRetryStatus,
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Kiểm tra lại thanh toán'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (canRetryPayment) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isRetryingPayment ? null : onRetryPayment,
                icon: isRetryingPayment
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(isRetryingPayment ? 'Đang tạo lại mã...' : 'Tạo lại mã thanh toán'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (canCancel)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isCancelling ? null : onCancel,
                icon: const Icon(Icons.cancel_outlined),
                label: Text(isCancelling ? 'Đang hủy...' : 'Hủy đơn hàng'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: IceBotColors.dangerRed,
                  side: const BorderSide(color: IceBotColors.dangerRed),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            )
          else if (canResetSession)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onResetSession,
                icon: const Icon(Icons.home_outlined),
                label: const Text('Về menu chính'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DemoPaymentSummaryNotice extends StatelessWidget {
  const _DemoPaymentSummaryNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IceBotColors.warningContainer,
        borderRadius: BorderRadius.circular(IceBotSpacing.cardRadius),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Text(
        'Chế độ demo: không dùng để thanh toán thật.\nVui lòng liên hệ nhân viên nếu cần hỗ trợ.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: IceBotColors.warningAmber,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IceBotColors.dangerContainer,
        borderRadius: BorderRadius.circular(IceBotSpacing.cardRadius),
        border: Border.all(color: IceBotColors.dangerRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: IceBotColors.dangerRed),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: IceBotColors.dangerRed,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleLarge),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: IceBotColors.botNavy,
                ),
          ),
        ],
      ),
    );
  }
}
