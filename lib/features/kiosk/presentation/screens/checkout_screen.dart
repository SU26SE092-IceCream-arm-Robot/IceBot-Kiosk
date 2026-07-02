import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icebot_kiosk/config/routes/app_router.dart';
import 'package:icebot_kiosk/config/themes/icebot_colors.dart';
import 'package:icebot_kiosk/config/themes/icebot_spacing.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_controller.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/bot_loading_indicator.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/bot_step_rail.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_formatters.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_panels.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = KioskScope.of(context);

    if (controller.isCartEmpty) {
      final checkoutError = controller.checkoutError;
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
                  title: checkoutError == null
                      ? 'Chưa có món để thanh toán'
                      : 'Giỏ hàng cần được cập nhật',
                  message:
                      checkoutError?.message ??
                      'Giỏ hàng đang trống. Vui lòng chọn món trước khi thanh toán.',
                  icon: checkoutError == null
                      ? Icons.shopping_cart_outlined
                      : Icons.sync_problem_outlined,
                  actionLabel: 'Về menu',
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
                      child: BotStepRail(currentStep: 2),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        IconButton(
                          iconSize: 32,
                          onPressed: controller.isCheckingOut
                              ? null
                              : () => context.go(AppRouter.cart),
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: IceBotColors.botNavy,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Xác nhận đơn hàng',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.displayMedium,
                          ),
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
                    final useWideLayout =
                        !layout.useSingleColumn && constraints.maxWidth >= 980;

                    return Padding(
                      padding: EdgeInsets.all(layout.screenPadding),
                      child: useWideLayout
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: _CheckoutItems(
                                    lines: controller.cartLines,
                                  ),
                                ),
                                const SizedBox(width: 28),
                                Expanded(
                                  flex: 4,
                                  child: _CheckoutAction(
                                    controller: controller,
                                  ),
                                ),
                              ],
                            )
                          : ListView(
                              padding: EdgeInsets.only(
                                bottom: layout.bottomOverlayPadding,
                              ),
                              children: [
                                SizedBox(
                                  height: _checkoutItemsHeight(
                                    controller.cartLines.length,
                                    layout,
                                  ),
                                  child: _CheckoutItems(
                                    lines: controller.cartLines,
                                  ),
                                ),
                                SizedBox(height: layout.sectionGap),
                                _CheckoutAction(controller: controller),
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
      bottomNavigationBar: KioskBottomActionBar(
        primaryLabel: controller.isCheckingOut
            ? 'Đang tạo mã...'
            : 'Tạo mã QR thanh toán',
        primaryIcon: Icons.qr_code_2_outlined,
        onPrimary: controller.isCheckingOut
            ? null
            : () async {
                final result = await controller.checkout();
                if (context.mounted && result != null) {
                  context.go(AppRouter.paymentPath(result.order.id));
                }
              },
        secondaryLabel: 'Về giỏ hàng',
        secondaryIcon: Icons.arrow_back,
        onSecondary: controller.isCheckingOut
            ? null
            : () => context.go(AppRouter.cart),
        leading: Text(
          'Cần thanh toán: ${KioskFormatters.money(controller.cartTotal)}',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  double _checkoutItemsHeight(int lineCount, KioskLayoutSpec layout) {
    final baseHeight = layout.isCompact ? 220.0 : 360.0;
    final itemHeight = layout.isCompact ? 68.0 : 92.0;
    final wantedHeight = baseHeight + lineCount * itemHeight;
    if (layout.isCompact) {
      return wantedHeight.clamp(300.0, 420.0).toDouble();
    }
    if (layout.isTallKiosk) {
      return wantedHeight.clamp(480.0, 780.0).toDouble();
    }
    return wantedHeight.clamp(400.0, 580.0).toDouble();
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
          LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: IceBotColors.botNavy,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Chi tiết đơn hàng',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: constraints.maxWidth < 380
                        ? Theme.of(context).textTheme.headlineMedium
                        : Theme.of(context).textTheme.displayMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Vui lòng kiểm tra lại số lượng và món trước khi tạo mã thanh toán.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: lines.length,
              separatorBuilder: (context, index) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(),
              ),
              itemBuilder: (context, index) {
                final line = lines[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: IceBotColors.frostSurface,
                        border: Border.all(color: IceBotColors.frostBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'x${line.quantity}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: IceBotColors.botNavy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.item.displayName,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            KioskFormatters.money(
                              line.item.finalPrice,
                              currency: line.item.currency,
                            ),
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: IceBotColors.botNavyMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 112,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          KioskFormatters.money(
                            line.lineTotal,
                            currency: line.item.currency,
                          ),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
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
          const _PaymentInstructionBanner(),
          const SizedBox(height: 28),
          Text(
            'Tổng thanh toán',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            KioskFormatters.money(controller.cartTotal),
            style: Theme.of(
              context,
            ).textTheme.displayLarge?.copyWith(color: IceBotColors.icePrimary),
          ),
          const SizedBox(height: 24),
          if (controller.isCheckingOut) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: BotLoadingIndicator(size: 48),
              ),
            ),
            Text(
              'IceBot đang kết nối hệ thống thanh toán.\nVui lòng không thao tác khác.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: IceBotColors.botNavyMuted),
            ),
          ] else ...[
            Text(
              'IceBot sẽ tạo đơn hàng và phiên thanh toán. Vui lòng không tắt màn hình trong lúc xử lý.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          if (controller.checkoutError != null) ...[
            const SizedBox(height: 20),
            _CheckoutErrorMessage(error: controller.checkoutError!),
          ],
        ],
      ),
    );
  }
}

class _PaymentInstructionBanner extends StatelessWidget {
  const _PaymentInstructionBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(IceBotSpacing.cardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.qr_code_scanner_rounded,
            color: colorScheme.onPrimaryContainer,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Quét mã QR để thanh toán ở bước tiếp theo',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutErrorMessage extends StatelessWidget {
  const _CheckoutErrorMessage({required this.error});

  final ApiException error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IceBotColors.dangerContainer,
        borderRadius: BorderRadius.circular(IceBotSpacing.cardRadius),
        border: Border.all(
          color: IceBotColors.dangerRed.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: IceBotColors.dangerRed,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _friendlyMessage(error),
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

  String _friendlyMessage(ApiException error) {
    if (error.type == ApiErrorType.upstream) {
      return 'Chưa thể tạo mã thanh toán. Vui lòng thử lại hoặc nhờ nhân viên hỗ trợ. Chi tiết: ${error.message}';
    }
    return error.message;
  }
}
