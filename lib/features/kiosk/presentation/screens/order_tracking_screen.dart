import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icebot_kiosk/config/routes/app_router.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/status/kiosk_status_presenter.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_error_panel.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_formatters.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_panels.dart';

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
    final order = controller.activeOrder?.id == widget.orderId
        ? controller.activeOrder
        : null;

    if (order == null && controller.trackingError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trạng thái đơn hàng')),
        body: KioskErrorPanel(
          title: 'Không thể cập nhật đơn hàng',
          error: controller.trackingError,
          actionLabel: 'Thử lại',
          onAction: _retryPolling,
        ),
      );
    }

    if (order == null) {
      return const Scaffold(
        body: KioskLoadingPanel(
          title: 'Đang cập nhật đơn hàng',
          message:
              'IceBot đang kiểm tra trạng thái thanh toán và chuẩn bị món.',
          icon: Icons.receipt_long_outlined,
        ),
      );
    }

    final colors = Theme.of(context).colorScheme;
    final statusView = _timedOut
        ? KioskStatusViewData(
            title: 'Cần kiểm tra đơn hàng',
            message: 'Trạng thái cập nhật chậm. Vui lòng liên hệ nhân viên.',
            icon: Icons.support_agent_outlined,
            color: const Color(0xFFB45309),
          )
        : KioskStatusPresenter.order(
            order,
            primary: colors.primary,
            success: const Color(0xFF15803D),
            warning: const Color(0xFFB45309),
            danger: colors.error,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trạng thái đơn hàng'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: KioskBackdrop(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layout = KioskLayoutSpec.of(context);
              final useWideLayout =
                  !layout.useSingleColumn && constraints.maxWidth >= 980;
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
                canRetryPayment:
                    order.status == OrderStatus.pendingPayment &&
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
                        children: [
                          statusPanel,
                          SizedBox(height: layout.sectionGap),
                          actionPanel,
                          SizedBox(height: layout.bottomOverlayPadding),
                        ],
                      ),
              );
            },
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
      padding: EdgeInsets.all(layout.isCompact ? 22 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: layout.isCompact ? 116 : 136,
            height: layout.isCompact ? 116 : 136,
            decoration: BoxDecoration(
              color: statusView.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: statusView.color.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(
              statusView.icon,
              color: statusView.color,
              size: layout.isCompact ? 72 : 84,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            statusView.title,
            style: Theme.of(
              context,
            ).textTheme.displayLarge?.copyWith(color: statusView.color),
          ),
          const SizedBox(height: 16),
          Text(
            statusView.message,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (isPolling) ...[
            const SizedBox(height: 28),
            const LinearProgressIndicator(minHeight: 6),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            _InlineWarning(message: errorMessage!),
          ],
          const SizedBox(height: 28),
          _OrderStepIndicator(order: order),
          const SizedBox(height: 28),
          Text(
            'Mã đơn: ${order.orderNumber}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            KioskFormatters.money(order.totalAmount, currency: order.currency),
            style: Theme.of(context).textTheme.titleLarge,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.error),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onErrorContainer,
          fontWeight: FontWeight.w700,
        ),
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
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Thông tin đơn hàng',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          _DetailLine(label: 'Trạng thái', value: _orderLabel(order.status)),
          _DetailLine(
            label: 'Thanh toán',
            value: _paymentLabel(order.paymentStatus),
          ),
          _DetailLine(
            label: 'Đặt lúc',
            value: KioskFormatters.shortDateTime(order.placedAt),
          ),
          const SizedBox(height: 28),
          if (canRetryTracking) ...[
            FilledButton.icon(
              onPressed: onRetryTracking,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử cập nhật lại'),
            ),
            const SizedBox(height: 12),
          ],
          if (canRetryPayment) ...[
            FilledButton.icon(
              onPressed: isRetryingPayment ? null : onRetryPayment,
              icon: isRetryingPayment
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : const Icon(Icons.qr_code_2_outlined),
              label: Text(
                isRetryingPayment
                    ? 'Đang tạo lại mã...'
                    : 'Tạo lại mã thanh toán',
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (canCancel)
            OutlinedButton.icon(
              onPressed: isCancelling ? null : onCancel,
              icon: const Icon(Icons.cancel_outlined),
              label: Text(isCancelling ? 'Đang hủy...' : 'Hủy đơn hàng'),
            )
          else if (canResetSession)
            FilledButton.icon(
              onPressed: onResetSession,
              icon: const Icon(Icons.home_outlined),
              label: const Text('Về menu'),
            )
          else
            Text(
              order.status == OrderStatus.ready
                  ? 'Vui lòng nhận món trước khi bắt đầu đơn mới.'
                  : 'Đơn hàng đang được xử lý. Vui lòng chờ cập nhật tiếp theo.',
              style: Theme.of(context).textTheme.bodyLarge,
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

class _OrderStepIndicator extends StatelessWidget {
  const _OrderStepIndicator({required this.order});

  final OrderResult order;

  @override
  Widget build(BuildContext context) {
    final currentStep = _stepFor(order);
    final isFailed = _isProblemState(order);
    final labels = [
      'Đã tạo đơn',
      'Đã thanh toán',
      switch (order.status) {
        OrderStatus.readyForExecution => 'Chờ xử lý',
        OrderStatus.accepted => 'Đã nhận đơn',
        _ => 'Đang chuẩn bị',
      },
      'Hoàn tất',
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useVerticalSteps = constraints.maxWidth < 620;
        final pills = [
          for (var index = 0; index < labels.length; index++)
            _StepPill(
              label: labels[index],
              active: !isFailed && index <= currentStep,
              current: !isFailed && index == currentStep,
              failed: isFailed && index == currentStep,
            ),
        ];

        if (useVerticalSteps) {
          return Column(
            children: [
              for (var index = 0; index < pills.length; index++) ...[
                SizedBox(width: double.infinity, child: pills[index]),
                if (index != pills.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < pills.length; index++) ...[
              Expanded(child: pills[index]),
              if (index != pills.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }

  int _stepFor(OrderResult order) {
    return switch (order.status) {
      OrderStatus.draft || OrderStatus.pendingPayment => 0,
      OrderStatus.paid => 1,
      OrderStatus.readyForExecution ||
      OrderStatus.accepted ||
      OrderStatus.preparing => 2,
      OrderStatus.ready => 2,
      OrderStatus.completed ||
      OrderStatus.refunded ||
      OrderStatus.compensated => 3,
      OrderStatus.cancelled ||
      OrderStatus.failed ||
      OrderStatus.executionRejected ||
      OrderStatus.refundRequired ||
      OrderStatus.unknown => 0,
    };
  }

  bool _isProblemState(OrderResult order) {
    return order.requiresStaffSupport ||
        order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.failed ||
        order.status == OrderStatus.executionRejected ||
        order.status == OrderStatus.refundRequired ||
        order.status == OrderStatus.unknown;
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({
    required this.label,
    required this.active,
    required this.current,
    required this.failed,
  });

  final String label;
  final bool active;
  final bool current;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = failed
        ? colorScheme.error
        : active
        ? colorScheme.primary
        : const Color(0xFFCBD5E1);

    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: failed
            ? const Color(0xFFFEE2E2)
            : active
            ? colorScheme.primaryContainer
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: current || failed ? 2 : 1),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: active || failed ? color : const Color(0xFF64748B),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}
