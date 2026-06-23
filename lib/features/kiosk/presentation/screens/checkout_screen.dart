import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icebot_kiosk/config/routes/app_router.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_controller.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_formatters.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_panels.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = KioskScope.of(context);

    if (controller.isCartEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Xác nhận đơn hàng')),
        body: KioskEmptyState(
          title: 'Chưa có món để thanh toán',
          message:
              'Giỏ hàng đang trống. Vui lòng chọn món trước khi tạo mã thanh toán.',
          icon: Icons.shopping_cart_outlined,
          actionLabel: 'Về menu',
          onAction: () => context.go(AppRouter.menu),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác nhận đơn hàng'),
        leading: IconButton(
          tooltip: 'Về giỏ hàng',
          onPressed: controller.isCheckingOut
              ? null
              : () => context.go(AppRouter.cart),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            return Padding(
              padding: EdgeInsets.all(isWide ? 32 : 24),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 7,
                          child: _CheckoutItems(lines: controller.cartLines),
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          flex: 4,
                          child: _CheckoutAction(controller: controller),
                        ),
                      ],
                    )
                  : ListView(
                      children: [
                        SizedBox(
                          height: 420,
                          child: _CheckoutItems(lines: controller.cartLines),
                        ),
                        const SizedBox(height: 20),
                        _CheckoutAction(controller: controller),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _CheckoutItems extends StatelessWidget {
  const _CheckoutItems({required this.lines});

  final List<CartLine> lines;

  @override
  Widget build(BuildContext context) {
    return KioskSectionCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đơn hàng của bạn',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Vui lòng kiểm tra lại trước khi tạo mã thanh toán.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: lines.length,
              separatorBuilder: (context, index) => const Divider(height: 28),
              itemBuilder: (context, index) {
                final line = lines[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.item.displayName,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Số lượng: ${line.quantity}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      KioskFormatters.money(
                        line.lineTotal,
                        currency: line.item.currency,
                      ),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutAction extends StatelessWidget {
  const _CheckoutAction({required this.controller});

  final KioskController controller;

  @override
  Widget build(BuildContext context) {
    return KioskSectionCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KioskInfoPill(
            icon: Icons.qr_code_2_outlined,
            label: 'Thanh toán bằng mã QR ở bước tiếp theo',
          ),
          const SizedBox(height: 22),
          Text('Cần thanh toán', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            KioskFormatters.money(controller.cartTotal),
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 20),
          Text(
            'IceBot sẽ tạo đơn hàng và phiên thanh toán. Vui lòng không tắt màn hình trong lúc xử lý.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (controller.checkoutError != null) ...[
            const SizedBox(height: 20),
            _CheckoutErrorMessage(message: controller.checkoutError!.message),
          ],
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: controller.isCheckingOut
                ? null
                : () async {
                    final result = await controller.checkout();
                    if (context.mounted && result != null) {
                      context.go(AppRouter.paymentPath(result.order.id));
                    }
                  },
            icon: controller.isCheckingOut
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : const Icon(Icons.qr_code_2_outlined),
            label: Text(
              controller.isCheckingOut
                  ? 'Đang tạo mã thanh toán...'
                  : 'Tạo mã thanh toán',
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutErrorMessage extends StatelessWidget {
  const _CheckoutErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
