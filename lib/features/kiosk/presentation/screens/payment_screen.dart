import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/config/routes/app_router.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/payment_models.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/status/kiosk_status_presenter.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_formatters.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_panels.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final expiredByTimeout =
        _startedAt != null && now.difference(_startedAt!) > _pollTimeout;

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
        appBar: AppBar(title: const Text('Thanh toán QR')),
        body: KioskEmptyState(
          title: 'Chưa có phiên thanh toán',
          message: 'Vui lòng tạo đơn hàng từ giỏ hàng trước khi thanh toán.',
          icon: Icons.qr_code_2_outlined,
          actionLabel: 'Về menu',
          onAction: () => context.go(AppRouter.menu),
        ),
      );
    }

    final colors = Theme.of(context).colorScheme;
    final statusView = KioskStatusPresenter.payment(
      controller.activePaymentStatus,
      order: order,
      primary: colors.primary,
      success: const Color(0xFF15803D),
      warning: const Color(0xFFB45309),
      danger: colors.error,
      timedOut: _timedOut,
      expired: _expired,
    );
    final paymentStatus = controller.activePaymentStatus;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét mã để thanh toán'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: KioskBackdrop(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layout = KioskLayoutSpec.of(context);
              final useWideLayout =
                  !layout.useSingleColumn && constraints.maxWidth >= 980;
              final summary = _PaymentSummary(
                order: order,
                session: session,
                statusView: statusView,
                isPolling: _timer != null,
                remainingTime: _remainingTime(session.expiresAt),
                errorMessage:
                    controller.checkoutError?.message ??
                    controller.trackingError?.message,
                canRetryPayment: KioskStatusPresenter.canRetryPaymentSession(
                  order,
                  paymentStatus,
                  expired: _expired,
                  timedOut: _timedOut,
                  hasTrackingError: controller.trackingError != null,
                ),
                canRetryStatus: _pollPausedForError,
                isRetryingPayment: controller.isCheckingOut,
                canCancel: KioskStatusPresenter.canCancelBeforePaid(
                  order,
                  controller.activePaymentStatus,
                ),
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
              final qrPanel = _QrPayloadPanel(session: session);

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
                        children: [
                          summary,
                          SizedBox(height: layout.sectionGap),
                          qrPanel,
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

  String? _remainingTime(DateTime? expiresAt) {
    if (expiresAt == null || _expired) {
      return null;
    }

    final remaining = expiresAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      return 'Đã hết hạn';
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
      padding: EdgeInsets.all(layout.isCompact ? 22 : 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(statusView.icon, color: statusView.color, size: 84),
          const SizedBox(height: 18),
          Text(
            statusView.title,
            style: Theme.of(
              context,
            ).textTheme.displayMedium?.copyWith(color: statusView.color),
          ),
          const SizedBox(height: 12),
          Text(
            statusView.message,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          Text(
            'Số tiền cần thanh toán',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            KioskFormatters.money(session.amount, currency: session.currency),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 22),
          _InfoRow(label: 'Mã đơn', value: order.orderNumber),
          _InfoRow(
            label: 'Nhà cung cấp',
            value: session.provider.isEmpty
                ? 'Đang cập nhật'
                : session.provider,
          ),
          _InfoRow(
            label: 'Hết hạn',
            value: KioskFormatters.shortDateTime(session.expiresAt),
          ),
          if (remainingTime != null)
            _InfoRow(label: 'Thời gian còn lại', value: remainingTime!),
          if (AppConfig.demoMode) ...[
            const SizedBox(height: 4),
            const _DemoPaymentSummaryNotice(),
          ],
          if (isPolling) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 6),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            _InlineWarning(message: errorMessage!),
          ],
          const SizedBox(height: 28),
          if (canRetryStatus) ...[
            FilledButton.icon(
              onPressed: onRetryStatus,
              icon: const Icon(Icons.sync),
              label: const Text('Kiểm tra lại thanh toán'),
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
                  : const Icon(Icons.refresh),
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
            OutlinedButton.icon(
              onPressed: onResetSession,
              icon: const Icon(Icons.home_outlined),
              label: const Text('Về menu'),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Text(
        'Chế độ demo: không dùng để thanh toán thật.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: const Color(0xFF92400E),
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

class _QrPayloadPanel extends StatelessWidget {
  const _QrPayloadPanel({required this.session});

  final PaymentSessionResult session;

  @override
  Widget build(BuildContext context) {
    final payload = session.qrCodePayload?.trim();
    final checkoutUrl = session.hasUsableCheckoutUrl
        ? session.checkoutUrl!.trim()
        : null;
    final layout = KioskLayoutSpec.of(context);

    return KioskSectionCard(
      padding: EdgeInsets.all(layout.isCompact ? 22 : 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nội dung thanh toán',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Dùng ứng dụng ngân hàng hoặc ví điện tử để quét mã. Nếu chưa có ảnh QR, hãy dùng nội dung thanh toán hoặc mở trang thanh toán.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Container(
            constraints: BoxConstraints(
              minHeight: layout.isCompact ? 260 : 320,
            ),
            padding: EdgeInsets.all(layout.isCompact ? 18 : 24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD8E3DF)),
            ),
            child: payload == null || payload.isEmpty
                ? Center(
                    child: Text(
                      'Chưa có nội dung QR. Vui lòng mở trang thanh toán nếu có.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.qr_code_2_outlined,
                        size: layout.isCompact ? 82 : 104,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Nội dung thanh toán',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 150,
                        child: SingleChildScrollView(
                          child: SelectableText(
                            payload,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          if (AppConfig.demoMode) ...[
            const SizedBox(height: 14),
            _DemoQrNotice(),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: payload == null || payload.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: payload));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép nội dung thanh toán'),
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.copy),
            label: const Text('Sao chép nội dung thanh toán'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: checkoutUrl == null || checkoutUrl.isEmpty
                ? null
                : () => launchUrl(
                    Uri.parse(checkoutUrl),
                    mode: LaunchMode.externalApplication,
                  ),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Mở trang thanh toán'),
          ),
        ],
      ),
    );
  }
}

class _DemoQrNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Text(
        'QR demo - không dùng để thanh toán thật. '
        'Màn hình này chỉ phục vụ review giao diện TOMKO.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: const Color(0xFF92400E),
          fontWeight: FontWeight.w800,
        ),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }
}
