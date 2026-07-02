import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icebot_kiosk/config/routes/app_router.dart';
import 'package:icebot_kiosk/config/themes/icebot_colors.dart';
import 'package:icebot_kiosk/config/themes/icebot_spacing.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_controller.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/bot_step_rail.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_formatters.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_panels.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/quantity_stepper_large.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = KioskScope.of(context);

    if (controller.isCartEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(28, 20, 28, 12),
                child: BotStepRail(currentStep: 1),
              ),
              Expanded(
                child: KioskEmptyState(
                  title: 'Giỏ hàng đang trống',
                  message: 'Chọn món kem yêu thích để bắt đầu đơn hàng tại kiosk.',
                  icon: Icons.shopping_cart_outlined,
                  actionLabel: 'Về menu chọn món',
                  onAction: () => context.go(AppRouter.menu),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                      child: BotStepRail(currentStep: 1),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        IconButton(
                          iconSize: 32,
                          onPressed: () => context.go(AppRouter.menu),
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: IceBotColors.botNavy,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Giỏ hàng của bạn',
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
                    final list = ListView.separated(
                      padding: EdgeInsets.only(
                        top: layout.sectionGap,
                        bottom: layout.bottomOverlayPadding,
                      ),
                      itemCount: controller.cartLines.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        return _CartLineTile(line: controller.cartLines[index]);
                      },
                    );

                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: layout.screenPadding),
                      child: useWideLayout
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 7, child: list),
                                const SizedBox(width: 28),
                                Expanded(
                                  flex: 3,
                                  child: Padding(
                                    padding: EdgeInsets.only(top: layout.sectionGap),
                                    child: _CartSummary(controller: controller),
                                  ),
                                ),
                              ],
                            )
                          : ListView(
                              padding: EdgeInsets.only(
                                top: layout.sectionGap,
                                bottom: layout.bottomOverlayPadding,
                              ),
                              children: [
                                for (var index = 0; index < controller.cartLines.length; index++) ...[
                                  _CartLineTile(line: controller.cartLines[index]),
                                  if (index != controller.cartLines.length - 1) const SizedBox(height: 16),
                                ],
                                SizedBox(height: layout.sectionGap),
                                _CartSummary(controller: controller),
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
      bottomNavigationBar: controller.isCartEmpty
          ? null
          : KioskBottomActionBar(
              primaryLabel: 'Tiếp tục thanh toán',
              primaryIcon: Icons.receipt_long_outlined,
              onPrimary: () => context.go(AppRouter.checkout),
              secondaryLabel: 'Chọn thêm món',
              secondaryIcon: Icons.add_circle_outline,
              onSecondary: () => context.go(AppRouter.menu),
              leading: Text(
                'Tổng cộng: ${KioskFormatters.money(controller.cartTotal)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactLine = constraints.maxWidth < 640;

        return KioskSectionCard(
          padding: EdgeInsets.all(isCompactLine ? 18 : 24),
          child: isCompactLine
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _CartItemIcon(colorScheme: colorScheme),
                        const SizedBox(width: 16),
                        Expanded(child: _CartItemTitle(line: line)),
                        IconButton(
                          iconSize: 32,
                          color: IceBotColors.botNavyMuted,
                          tooltip: 'Xóa món',
                          onPressed: () => controller.removeFromCart(line.item.menuItemId),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        QuantityStepperLarge(
                          quantity: line.quantity,
                          onDecrease: () => controller.decreaseQuantity(line.item.menuItemId),
                          onIncrease: () => controller.increaseQuantity(line.item.menuItemId),
                          minQuantity: 1,
                        ),
                        const Spacer(),
                        Text(
                          KioskFormatters.money(line.lineTotal, currency: line.item.currency),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: IceBotColors.icePrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    _CartItemIcon(colorScheme: colorScheme),
                    const SizedBox(width: 24),
                    Expanded(child: _CartItemTitle(line: line)),
                    const SizedBox(width: 16),
                    QuantityStepperLarge(
                      quantity: line.quantity,
                      onDecrease: () => controller.decreaseQuantity(line.item.menuItemId),
                      onIncrease: () => controller.increaseQuantity(line.item.menuItemId),
                      minQuantity: 1,
                    ),
                    const SizedBox(width: 32),
                    SizedBox(
                      width: 160,
                      child: Text(
                        KioskFormatters.money(line.lineTotal, currency: line.item.currency),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: IceBotColors.icePrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      iconSize: 32,
                      color: IceBotColors.botNavyMuted,
                      tooltip: 'Xóa món',
                      onPressed: () => controller.removeFromCart(line.item.menuItemId),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _CartItemIcon extends StatelessWidget {
  const _CartItemIcon({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(IceBotSpacing.cardRadius),
        border: Border.all(color: IceBotColors.frostBorder),
      ),
      child: Icon(
        Icons.icecream_outlined,
        color: colorScheme.onPrimaryContainer,
        size: 46,
      ),
    );
  }
}

class _CartItemTitle extends StatelessWidget {
  const _CartItemTitle({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line.item.displayName,
          style: Theme.of(context).textTheme.headlineMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          KioskFormatters.money(line.item.finalPrice, currency: line.item.currency),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: IceBotColors.botNavyMuted,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
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
          Row(
            children: [
              Icon(Icons.shopping_bag_outlined, color: IceBotColors.botNavy, size: 28),
              const SizedBox(width: 12),
              Text('Tóm tắt đơn hàng', style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Số lượng món', style: Theme.of(context).textTheme.bodyLarge),
              Text(
                '${controller.cartItemCount}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tổng cộng', style: Theme.of(context).textTheme.titleLarge),
              Text(
                KioskFormatters.money(controller.cartTotal),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(color: IceBotColors.icePrimary),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: controller.clearCart,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Xóa toàn bộ giỏ hàng'),
              style: OutlinedButton.styleFrom(
                foregroundColor: IceBotColors.dangerRed,
                side: const BorderSide(color: IceBotColors.dangerRed),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
