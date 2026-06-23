import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icebot_kiosk/config/routes/app_router.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_controller.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_formatters.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_panels.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = KioskScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giỏ hàng của bạn'),
        leading: IconButton(
          tooltip: 'Về menu',
          onPressed: () => context.go(AppRouter.menu),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: controller.isCartEmpty
            ? const _EmptyCartView()
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 980;
                  final list = ListView.separated(
                    itemCount: controller.cartLines.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return _CartLineTile(line: controller.cartLines[index]);
                    },
                  );

                  return Padding(
                    padding: EdgeInsets.all(isWide ? 32 : 24),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 7, child: list),
                              const SizedBox(width: 28),
                              Expanded(
                                flex: 3,
                                child: _CartSummary(controller: controller),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(child: list),
                              const SizedBox(height: 20),
                              _CartSummary(controller: controller),
                            ],
                          ),
                  );
                },
              ),
      ),
    );
  }
}

class _EmptyCartView extends StatelessWidget {
  const _EmptyCartView();

  @override
  Widget build(BuildContext context) {
    return KioskEmptyState(
      title: 'Giỏ hàng đang trống',
      message: 'Chọn món kem yêu thích để bắt đầu đơn hàng tại kiosk.',
      icon: Icons.shopping_cart_outlined,
      actionLabel: 'Tiếp tục chọn món',
      onAction: () => context.go(AppRouter.menu),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final controller = KioskScope.of(context);

    final colorScheme = Theme.of(context).colorScheme;

    return KioskSectionCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.icecream_outlined,
              color: colorScheme.onPrimaryContainer,
              size: 46,
            ),
          ),
          const SizedBox(width: 20),
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
                  KioskFormatters.money(
                    line.item.finalPrice,
                    currency: line.item.currency,
                  ),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IconButton.filledTonal(
            iconSize: 30,
            onPressed: () => controller.decreaseQuantity(line.item.menuItemId),
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 72,
            child: Text(
              '${line.quantity}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          IconButton.filledTonal(
            iconSize: 30,
            onPressed: () => controller.increaseQuantity(line.item.menuItemId),
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 160,
            child: Text(
              KioskFormatters.money(
                line.lineTotal,
                currency: line.item.currency,
              ),
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            tooltip: 'Xóa món',
            onPressed: () => controller.removeFromCart(line.item.menuItemId),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  const _CartSummary({required this.controller});

  final KioskController controller;

  @override
  Widget build(BuildContext context) {
    return KioskSectionCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tổng cộng', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Text(
            KioskFormatters.money(controller.cartTotal),
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 12),
          Text(
            '${controller.cartItemCount} món trong giỏ',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => context.go(AppRouter.checkout),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Tiếp tục thanh toán'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.go(AppRouter.menu),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Tiếp tục chọn món'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: controller.clearCart,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Xóa giỏ hàng'),
          ),
        ],
      ),
    );
  }
}
