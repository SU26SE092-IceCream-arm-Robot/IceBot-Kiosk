import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icebot_kiosk/config/routes/app_router.dart';
import 'package:icebot_kiosk/config/themes/icebot_colors.dart';
import 'package:icebot_kiosk/config/themes/icebot_spacing.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/status/kiosk_status_presenter.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/bot_loading_indicator.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/bot_step_rail.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_error_panel.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_formatters.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_panels.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/order_timeline.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({required this.orderId, super.key});

  final String orderId;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  static const Duration _pollInterval = Duration(seconds: 3);
  static const Duration _pollTimeout = Duration(minutes: 20);

  Timer? _timer;
  DateTime? _startedAt;
  bool _startedPolling = false;
  bool _timedOut = false;
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

    final now = DateTime.now();
    if (_startedAt != null && now.difference(_startedAt!) > _pollTimeout) {
      setState(() => _timedOut = true);
      _stopPolling();
      return;
    }

    _pollInFlight = true;
    try {
      final controller = KioskScope.of(context);
      final order = await controller.refreshOrder(widget.orderId);
      if (!mounted) {
        return;
      }
      if (order == null) {
        if (controller.trackingError != null) {
          setState(() => _pollPausedForError = true);
          _stopPolling();
        }
        return;
      }

      if (_pollPausedForError) {
        setState(() => _pollPausedForError = false);
      }

      if (KioskStatusPresenter.isOrderTerminal(order)) {
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

  void _retryPolling() {
    setState(() {
      _timedOut = false;
      _pollPausedForError = false;
      _startedAt = DateTime.now();
    });
    _startPolling();
  }

  @override
  Widget build(BuildContext context) {
    final controller = KioskScope.of(context);
    final order = controller.activeOrder?.id == widget.orderId ? controller.activeOrder : null;

    if (order == null && controller.trackingError != null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(28, 20, 28, 12),
                child: BotStepRail(currentStep: 3),
              ),
              Expanded(
                child: KioskErrorPanel(
                  title: 'Không thể cập nhật đơn hàng',
                  error: controller.trackingError,
                  actionLabel: 'Thử lại',
                  onAction: _retryPolling,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (order == null) {
      return const Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(28, 20, 28, 12),
                child: BotStepRail(currentStep: 3),
              ),
              Expanded(
                child: KioskLoadingPanel(
                  title: 'Đang cập nhật đơn hàng',
                  message: 'IceBot đang kiểm tra trạng thái thanh toán và chuẩn bị món.',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final statusView = _timedOut
        ? KioskStatusViewData(
            title: 'Cần kiểm tra đơn hàng',
            message: 'Trạng thái cập nhật chậm. Vui lòng liên hệ nhân viên.',
            icon: Icons.support_agent_rounded,
            color: IceBotColors.warningAmber,
          )
        : KioskStatusPresenter.order(
            order,
            primary: IceBotColors.icePrimary,
            success: IceBotColors.mintSuccess,
            warning: IceBotColors.warningAmber,
            danger: IceBotColors.dangerRed,
          );

    return Scaffold(
      body: SafeArea(
        child: KioskBackdrop(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
                child: Column(
                  children: [
                    const BotStepRail(currentStep: 3),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          'Trạng thái đơn hàng',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final layout = KioskLayoutSpec.of(context);
                    final useWideLayout = !layout.useSingleColumn && constraints.maxWidth >= 980;
                    final statusPanel = _OrderStatusPanel(
                      order: order,
                      statusView: statusView,
                      isPolling: _timer != null,
                      errorMessage: controller.trackingError?.message,
                    );
                    final actionPanel = _OrderActionPanel(
                      order: order,
                      canCancel: KioskStatusPresenter.canCancelBeforePaid(
                        order,
                        controller.activePaymentStatus,
                      ),
                      isCancelling: controller.isCancellingOrder,
                      canRetryPayment: order.status == OrderStatus.pendingPayment &&
                          controller.activePaymentSession == null &&
                          controller.canRetryPayment,
                      isRetryingPayment: controller.isCheckingOut,
                      canRetryTracking: _pollPausedForError || _timedOut,
                      canResetSession: controller.canResetKioskSession,
                      onRetryTracking: _retryPolling,
                      onRetryPayment: () async {
                        final result = await controller.retryPaymentSession();
                        if (context.mounted && result != null) {
                          context.go(AppRouter.paymentPath(result.order.id));
                        }
                      },
                      onCancel: () async {
                        _stopPolling();
                        final cancelled = await controller.cancelActiveOrder();
                        if (mounted && cancelled == null) {
                          _startPolling();
                        }
                      },
                      onResetSession: () async {
                        final reset = await controller.resetKioskSession();
                        if (context.mounted && reset) {
                          context.go(AppRouter.menu);
                        }
                      },
                    );

                    return Padding(
                      padding: EdgeInsets.all(layout.screenPadding),
                      child: useWideLayout
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 6, child: statusPanel),
                                const SizedBox(width: 28),
                                Expanded(flex: 4, child: actionPanel),
                              ],
                            )
                          : ListView(
                              padding: EdgeInsets.only(bottom: layout.bottomOverlayPadding),
                              children: [
                                statusPanel,
                                SizedBox(height: layout.sectionGap),
                                actionPanel,
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
}

class _OrderStatusPanel extends StatelessWidget {
  const _OrderStatusPanel({
    required this.order,
    required this.statusView,
    required this.isPolling,
    required this.errorMessage,
  });

  final OrderResult order;
  final KioskStatusViewData statusView;
  final bool isPolling;
  final String? errorMessage;

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
              Container(
                width: layout.isCompact ? 96 : 112,
                height: layout.isCompact ? 96 : 112,
                decoration: BoxDecoration(
                  color: statusView.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(IceBotSpacing.cardRadius),
                  border: Border.all(
                    color: statusView.color.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  statusView.icon,
                  color: statusView.color,
                  size: layout.isCompact ? 64 : 72,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusView.title,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(color: statusView.color),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statusView.message,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: IceBotColors.botNavyMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isPolling) ...[
            const SizedBox(height: 32),
            Center(
              child: BotLoadingIndicator(size: 48, color: statusView.color),
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 24),
            _InlineWarning(message: errorMessage!),
          ],
          const SizedBox(height: 32),
          OrderTimeline(order: order),
          const SizedBox(height: 48),
          const Divider(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mã đơn hàng', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    order.orderNumber,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(color: IceBotColors.botNavy),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Tổng tiền', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    KioskFormatters.money(order.totalAmount, currency: order.currency),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(color: IceBotColors.botNavy),
                  ),
                ],
              ),
            ],
          ),
        ],
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

class _OrderActionPanel extends StatelessWidget {
  const _OrderActionPanel({
    required this.order,
    required this.canCancel,
    required this.isCancelling,
    required this.canRetryPayment,
    required this.isRetryingPayment,
    required this.canRetryTracking,
    required this.canResetSession,
    required this.onRetryTracking,
    required this.onRetryPayment,
    required this.onCancel,
    required this.onResetSession,
  });

  final OrderResult order;
  final bool canCancel;
  final bool isCancelling;
  final bool canRetryPayment;
  final bool isRetryingPayment;
  final bool canRetryTracking;
  final bool canResetSession;
  final VoidCallback onRetryTracking;
  final Future<void> Function() onRetryPayment;
  final Future<void> Function() onCancel;
  final Future<void> Function() onResetSession;

  @override
  Widget build(BuildContext context) {
    return KioskSectionCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Thông tin chi tiết',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 24),
          _DetailLine(label: 'Trạng thái', value: _orderLabel(order.status)),
          _DetailLine(
            label: 'Thanh toán',
            value: _paymentLabel(order.paymentStatus),
          ),
          _DetailLine(
            label: 'Đặt lúc',
            value: KioskFormatters.shortDateTime(order.placedAt),
          ),
          const Spacer(),
          const SizedBox(height: 32),
          if (canRetryTracking) ...[
            FilledButton.icon(
              onPressed: onRetryTracking,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử cập nhật lại'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 24),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (canRetryPayment) ...[
            FilledButton.icon(
              onPressed: isRetryingPayment ? null : onRetryPayment,
              icon: isRetryingPayment
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : const Icon(Icons.qr_code_2_rounded),
              label: Text(
                isRetryingPayment ? 'Đang tạo lại mã...' : 'Tạo lại mã thanh toán',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 24),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (canCancel)
            OutlinedButton.icon(
              onPressed: isCancelling ? null : onCancel,
              icon: const Icon(Icons.cancel_outlined),
              label: Text(isCancelling ? 'Đang hủy...' : 'Hủy đơn hàng'),
              style: OutlinedButton.styleFrom(
                foregroundColor: IceBotColors.dangerRed,
                side: const BorderSide(color: IceBotColors.dangerRed),
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
            )
          else if (canResetSession)
            FilledButton.icon(
              onPressed: onResetSession,
              icon: const Icon(Icons.home_outlined),
              label: const Text('Về menu chính'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 24),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: IceBotColors.frostSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: IceBotColors.frostBorder),
              ),
              child: Text(
                order.status == OrderStatus.ready
                    ? 'Vui lòng nhận món trước khi bắt đầu đơn mới.'
                    : 'Đơn hàng đang được xử lý.\nVui lòng chờ cập nhật tiếp theo.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: IceBotColors.botNavyMuted),
              ),
            ),
        ],
      ),
    );
  }

  String _paymentLabel(PaymentStatus status) {
    return switch (status) {
      PaymentStatus.unpaid => 'Chưa thanh toán',
      PaymentStatus.authorized => 'Đang xác nhận',
      PaymentStatus.paid => 'Đã thanh toán',
      PaymentStatus.partiallyRefunded => 'Hoàn tiền một phần',
      PaymentStatus.refunded => 'Đã hoàn tiền',
      PaymentStatus.failed => 'Thanh toán lỗi',
      PaymentStatus.cancelled => 'Đã hủy',
      PaymentStatus.unknown => 'Chưa xác định',
    };
  }

  String _orderLabel(OrderStatus status) {
    return switch (status) {
      OrderStatus.draft => 'Đang nhập đơn',
      OrderStatus.pendingPayment => 'Đang chờ thanh toán',
      OrderStatus.paid => 'Đã thanh toán',
      OrderStatus.readyForExecution => 'Đơn đang chờ xử lý',
      OrderStatus.accepted => 'Hệ thống đã nhận đơn',
      OrderStatus.preparing => 'Robot đang chuẩn bị',
      OrderStatus.ready => 'Món đã sẵn sàng',
      OrderStatus.completed => 'Hoàn tất',
      OrderStatus.cancelled => 'Đã hủy',
      OrderStatus.failed => 'Đơn hàng gặp lỗi',
      OrderStatus.executionRejected => 'Không thể chuẩn bị món',
      OrderStatus.refundRequired => 'Cần hỗ trợ hoàn tiền',
      OrderStatus.refunded => 'Đã hoàn tiền',
      OrderStatus.compensated => 'Đã hỗ trợ bù',
      OrderStatus.unknown => 'Chưa xác định',
    };
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

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
