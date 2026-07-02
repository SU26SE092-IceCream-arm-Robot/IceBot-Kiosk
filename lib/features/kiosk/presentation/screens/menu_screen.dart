import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/config/routes/app_router.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/bot_step_rail.dart';
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
                  // Header section with Step Rail
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
                    child: Column(
                      children: [
                        const BotStepRail(currentStep: 0),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Chọn món kem',
                              style: Theme.of(context).textTheme.displayMedium,
                            ),
                            if (AppConfig.demoMode)
                              const KioskInfoPill(
                                icon: Icons.visibility_outlined,
                                label: 'Demo',
                                backgroundColor: Color(0xFFFFF7ED),
                                foregroundColor: Color(0xFF92400E),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Content section
                  Expanded(
                    child: items.isEmpty
                        ? _EmptyMenuView(onRetry: () => controller.loadMenu(force: true))
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
                                        crossAxisCount: layout.portraitMenuColumns,
                                        mainAxisSpacing: layout.sectionGap,
                                        crossAxisSpacing: layout.sectionGap,
                                        childAspectRatio: layout.isCompact ? 0.86 : 0.76,
                                      )
                                    : SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: isWideLandscape ? 410 : 350,
                                        mainAxisSpacing: 24,
                                        crossAxisSpacing: 24,
                                        childAspectRatio: isWideLandscape ? 0.76 : 0.7,
                                      ),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return ProductCard(
                                    item: item,
                                    onTap: () => context.go(AppRouter.productPath(item.menuItemId)),
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
                  totalPriceFormatted: KioskFormatters.money(controller.cartTotal),
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
