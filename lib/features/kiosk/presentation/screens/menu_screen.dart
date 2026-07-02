import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/config/routes/app_router.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/floating_cart_badge.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_error_panel.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_formatters.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_panels.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/product_card.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _requestedLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedLoad) {
      return;
    }

    _requestedLoad = true;
    final controller = KioskScope.of(context);
    if (!controller.hasMenu && !controller.isLoadingMenu) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          controller.loadMenu();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = KioskScope.of(context);

    if (controller.isLoadingMenu && !controller.hasMenu) {
      return const _MenuLoadingView();
    }

    if (controller.menuError != null && !controller.hasMenu) {
      return Scaffold(
        body: KioskBackdrop(
          child: KioskErrorPanel(
            title: _errorTitle(controller.menuError!),
            error: controller.menuError,
            actionLabel: 'Thử lại',
            onAction: () => controller.loadMenu(force: true),
          ),
        ),
      );
    }

    final items = controller.menuItems;

    return Scaffold(
      body: SafeArea(
        child: KioskBackdrop(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
                    child: const _StorefrontHeader(),
                  ),
                  const Divider(height: 1),
                  // Content section
                  Expanded(
                    child: items.isEmpty
                        ? _EmptyMenuView(
                            onRetry: () => controller.loadMenu(force: true),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final layout = KioskLayoutSpec.of(context);
                              final isWideLandscape = layout.isWideLandscape;
                              return GridView.builder(
                                padding: EdgeInsets.only(
                                  left: layout.screenPadding,
                                  right: layout.screenPadding,
                                  top: layout.sectionGap,
                                  bottom: layout.bottomOverlayPadding,
                                ),
                                gridDelegate: layout.isPortrait
                                    ? SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount:
                                            layout.portraitMenuColumns,
                                        mainAxisSpacing: layout.sectionGap,
                                        crossAxisSpacing: layout.sectionGap,
                                        childAspectRatio: layout.isCompact
                                            ? 0.86
                                            : 0.76,
                                      )
                                    : SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: isWideLandscape
                                            ? 410
                                            : 350,
                                        mainAxisSpacing: 24,
                                        crossAxisSpacing: 24,
                                        childAspectRatio: isWideLandscape
                                            ? 0.76
                                            : 0.7,
                                      ),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return ProductCard(
                                    item: item,
                                    onTap: () => context.go(
                                      AppRouter.productPath(item.menuItemId),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
              // Floating Cart Badge
              Positioned(
                right: 28,
                bottom: 32,
                child: FloatingCartBadge(
                  itemCount: controller.cartItemCount,
                  totalPriceFormatted: KioskFormatters.money(
                    controller.cartTotal,
                  ),
                  onTap: () => context.go(AppRouter.cart),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _errorTitle(ApiException error) {
    return switch (error.type) {
      ApiErrorType.notFound => 'Không tìm thấy kiosk',
      ApiErrorType.conflict => 'Kiosk đang tạm ngưng',
      ApiErrorType.network || ApiErrorType.timeout => 'Không thể kết nối',
      ApiErrorType.validation => 'Cấu hình kiosk không hợp lệ',
      _ => 'Không thể tải menu',
    };
  }
}

class _StorefrontHeader extends StatelessWidget {
  const _StorefrontHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kem robot sẵn sàng phục vụ',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Chọn món, quét QR và nhận kem trong vài bước.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 20 : 24),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.18),
            ),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StorefrontBrandRow(colorScheme: colorScheme),
                    const SizedBox(height: 18),
                    copy,
                  ],
                )
              : Row(
                  children: [
                    _StorefrontIcon(colorScheme: colorScheme),
                    const SizedBox(width: 20),
                    Expanded(child: copy),
                    if (AppConfig.demoMode) ...[
                      const SizedBox(width: 16),
                      const _DemoPill(),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _StorefrontBrandRow extends StatelessWidget {
  const _StorefrontBrandRow({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StorefrontIcon(colorScheme: colorScheme),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'ICEBOT KIOSK',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (AppConfig.demoMode) const _DemoPill(),
      ],
    );
  }
}

class _StorefrontIcon extends StatelessWidget {
  const _StorefrontIcon({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.icecream_rounded, color: colorScheme.primary, size: 30),
    );
  }
}

class _DemoPill extends StatelessWidget {
  const _DemoPill();

  @override
  Widget build(BuildContext context) {
    return const KioskInfoPill(
      icon: Icons.visibility_outlined,
      label: 'Demo',
      backgroundColor: Color(0xFFFFF7ED),
      foregroundColor: Color(0xFF92400E),
    );
  }
}

class _MenuLoadingView extends StatelessWidget {
  const _MenuLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: KioskBackdrop(
        child: KioskLoadingPanel(
          title: 'IceBot Kiosk',
          message: 'Đang tải menu hôm nay cho bạn.',
          icon: Icons.restaurant_menu_outlined,
        ),
      ),
    );
  }
}

class _EmptyMenuView extends StatelessWidget {
  const _EmptyMenuView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: KioskEmptyState(
        title: 'Menu hiện chưa có món',
        message: 'Vui lòng tải lại sau ít phút hoặc liên hệ nhân viên hỗ trợ.',
        icon: Icons.icecream_outlined,
        actionLabel: 'Tải lại menu',
        onAction: onRetry,
      ),
    );
  }
}
