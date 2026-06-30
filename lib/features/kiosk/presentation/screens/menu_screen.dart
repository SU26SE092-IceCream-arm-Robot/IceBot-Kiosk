import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/config/routes/app_router.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/runtime_menu_models.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_error_panel.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_formatters.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_panels.dart';

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
      appBar: AppBar(
        title: const Text('IceBot Kiosk'),
        actions: [
          IconButton(
            tooltip: 'Tải lại menu',
            onPressed: controller.isLoadingMenu
                ? null
                : () => controller.loadMenu(force: true),
            icon: const Icon(Icons.refresh),
          ),
          _CartButton(count: controller.cartItemCount),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: KioskBackdrop(
          child: items.isEmpty
              ? _EmptyMenuView(onRetry: () => controller.loadMenu(force: true))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final layout = KioskLayoutSpec.of(context);
                    final isWideLandscape = layout.isWideLandscape;
                    return Padding(
                      padding: EdgeInsets.all(layout.screenPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MenuHeader(
                            itemCount: items.length,
                            containsMachineRuntimeState:
                                controller.menu?.containsMachineRuntimeState ==
                                true,
                          ),
                          SizedBox(height: layout.sectionGap),
                          Expanded(
                            child: layout.isPortrait && items.length == 1
                                ? ListView(
                                    padding: EdgeInsets.only(
                                      bottom: layout.bottomOverlayPadding,
                                    ),
                                    children: [
                                      Align(
                                        alignment: Alignment.topCenter,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: layout.isCompact
                                                ? double.infinity
                                                : 560,
                                          ),
                                          child: AspectRatio(
                                            aspectRatio: layout.isCompact
                                                ? 0.86
                                                : 0.78,
                                            child: _MenuItemCard(
                                              item: items[0],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : GridView.builder(
                                    padding: EdgeInsets.only(
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
                                      return _MenuItemCard(item: items[index]);
                                    },
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
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

class _MenuHeader extends StatelessWidget {
  const _MenuHeader({
    required this.itemCount,
    required this.containsMachineRuntimeState,
  });

  final int itemCount;
  final bool containsMachineRuntimeState;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return KioskSectionCard(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 20,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Menu hôm nay',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  containsMachineRuntimeState
                      ? 'Chọn món kem bạn muốn mua. IceBot sẽ hướng dẫn từng bước đến khi thanh toán.'
                      : 'Chọn món từ menu hiện tại. Tình trạng máy và nguyên liệu sẽ được xác nhận khi tạo đơn.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (AppConfig.demoMode)
                const KioskInfoPill(
                  icon: Icons.visibility_outlined,
                  label: 'Chế độ demo',
                  backgroundColor: Color(0xFFFFF7ED),
                  foregroundColor: Color(0xFF92400E),
                ),
              KioskInfoPill(
                icon: Icons.icecream_outlined,
                label: '$itemCount món trong menu',
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ],
      ),
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
    return KioskBackdrop(
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

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({required this.item});

  final RuntimeMenuItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return KioskSectionCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.go(AppRouter.productPath(item.menuItemId)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.imageUrl == null || item.imageUrl!.isEmpty
                      ? Container(
                          color: colorScheme.primaryContainer,
                          child: Icon(
                            Icons.icecream_outlined,
                            size: 86,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: item.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            color: colorScheme.primaryContainer,
                            child: Icon(
                              Icons.icecream_outlined,
                              size: 86,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                  Positioned(
                    left: 18,
                    bottom: 18,
                    child: KioskInfoPill(
                      label: KioskFormatters.money(
                        item.finalPrice,
                        currency: item.currency,
                      ),
                      backgroundColor: Colors.white,
                      foregroundColor: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.description?.isNotEmpty == true
                        ? item.description!
                        : 'Kem tươi IceBot',
                    maxLines: KioskLayoutSpec.of(context).isCompact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      KioskInfoPill(
                        icon: Icons.timer_outlined,
                        label: KioskFormatters.durationSeconds(
                          item.preparationTimeSeconds,
                        ),
                        backgroundColor: const Color(0xFFFFF7ED),
                        foregroundColor: const Color(0xFF8A5200),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () =>
                          context.go(AppRouter.productPath(item.menuItemId)),
                      icon: const Icon(Icons.touch_app_outlined),
                      label: const Text('Chọn món'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final layout = KioskLayoutSpec.of(context);

    if (layout.isCompact) {
      return Badge.count(
        count: count,
        isLabelVisible: count > 0,
        child: IconButton(
          tooltip: 'Giỏ hàng',
          onPressed: () => context.go(AppRouter.cart),
          icon: const Icon(Icons.shopping_cart_outlined),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Badge.count(
        count: count,
        isLabelVisible: count > 0,
        child: FilledButton.icon(
          onPressed: () => context.go(AppRouter.cart),
          icon: const Icon(Icons.shopping_cart_outlined),
          label: const Text('Giỏ hàng'),
        ),
      ),
    );
  }
}
