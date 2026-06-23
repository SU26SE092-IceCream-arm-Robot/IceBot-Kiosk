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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedPolling) {
      return;
    }

    _startedPolling = true;
    _startedAt = DateTime.now();
    _pollNow();
    _timer = Timer.periodic(_pollInterval, (_) => _pollNow());
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  Future<void> _pollNow() async {
    if (!mounted || _timedOut) {
      return;
    }

    final controller = KioskScope.of(context);
    final session = controller.activePaymentSession;
    final now = DateTime.now();
    final expiredBySession =
        session?.expiresAt != null && now.isAfter(session!.expiresAt!);
    final expiredByTimeout =
        _startedAt != null && now.difference(_startedAt!) > _pollTimeout;

    if (expiredBySession || expiredByTimeout) {
      setState(() => _timedOut = true);
      _stopPolling();
      return;
    }

    final status = await controller.refreshPaymentStatus(widget.orderId);
    if (!mounted || status == null) {
      return;
    }

    if (KioskStatusPresenter.isPaymentPaid(status)) {
      _stopPolling();
      await controller.refreshOrder(widget.orderId);
      if (mounted) {
        context.go(AppRouter.orderPath(widget.orderId));
      }
      return;
    }

    if (KioskStatusPresenter.isPaymentTerminal(status)) {
      _stopPolling();
    }
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
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét mã để thanh toán'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            final summary = _PaymentSummary(
              order: order,
              session: session,
              statusView: statusView,
              isPolling: _timer != null,
              errorMessage: controller.trackingError?.message,
              canCancel: KioskStatusPresenter.canCancelBeforePaid(
                order,
                controller.activePaymentStatus,
              ),
              isCancelling: controller.isCancellingOrder,
              onCancel: () async {
                _stopPolling();
                final cancelled = await controller.cancelActiveOrder();
                await controller.refreshPaymentStatus(widget.orderId);
                if (mounted && cancelled == null) {
                  _timer = Timer.periodic(_pollInterval, (_) => _pollNow());
                }
              },
            );
            final qrPanel = _QrPayloadPanel(session: session);

            return Padding(
              padding: EdgeInsets.all(isWide ? 32 : 24),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 5, child: summary),
                        const SizedBox(width: 28),
                        Expanded(flex: 6, child: qrPanel),
                      ],
                    )
                  : ListView(
                      children: [summary, const SizedBox(height: 20), qrPanel],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _PaymentSummary extends StatelessWidget {
  const _PaymentSummary({
    required this.order,
    required this.session,
    required this.statusView,
    required this.isPolling,
    required this.errorMessage,
    required this.canCancel,
    required this.isCancelling,
    required this.onCancel,
  });

  final OrderResult order;
  final PaymentSessionResult session;
  final KioskStatusViewData statusView;
  final bool isPolling;
  final String? errorMessage;
  final bool canCancel;
  final bool isCancelling;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) {
    return KioskSectionCard(
      padding: const EdgeInsets.all(30),
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
          _InfoRow(label: 'Mã đơn', value: order.orderNumber),
          _InfoRow(
            label: 'Số tiền',
            value: KioskFormatters.money(
              session.amount,
              currency: session.currency,
            ),
          ),
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
          if (isPolling) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 6),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            _InlineWarning(message: errorMessage!),
          ],
          const SizedBox(height: 28),
          if (canCancel)
            OutlinedButton.icon(
              onPressed: isCancelling ? null : onCancel,
              icon: const Icon(Icons.cancel_outlined),
              label: Text(isCancelling ? 'Đang hủy...' : 'Hủy đơn hàng'),
            )
          else
            OutlinedButton.icon(
              onPressed: () => context.go(AppRouter.menu),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Tạo đơn mới'),
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
    final checkoutUrl = session.checkoutUrl?.trim();

    return KioskSectionCard(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mã thanh toán',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Dùng ứng dụng ngân hàng hoặc ví điện tử để quét mã. Nếu backend chỉ trả về nội dung thanh toán, nội dung sẽ hiển thị bên dưới.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Container(
            constraints: const BoxConstraints(minHeight: 300),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
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
                        size: 96,
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
