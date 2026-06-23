import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/config/routes/app_router.dart';
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
      controller.loadMenu();
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
        body: KioskErrorPanel(
          title: 'Kiosk đang tạm ngưng',
          error: controller.menuError,
          actionLabel: 'Thử lại',
          onAction: () => controller.loadMenu(force: true),
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
        child: items.isEmpty
            ? const _EmptyMenuView()
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1000;
                  return Padding(
                    padding: EdgeInsets.all(isWide ? 32 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MenuHeader(itemCount: items.length),
                        SizedBox(height: isWide ? 30 : 22),
                        Expanded(
                          child: GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: isWide ? 410 : 350,
                                  mainAxisSpacing: 24,
                                  crossAxisSpacing: 24,
                                  childAspectRatio: isWide ? 0.76 : 0.7,
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
    );
  }
}

class _MenuHeader extends StatelessWidget {
  const _MenuHeader({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
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
                'Chọn món kem bạn muốn mua. Giá và món bán theo menu đang hoạt động của kiosk.',
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
              label: '$itemCount món',
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
            ),
          ],
        ),
      ],
    );
  }
}

class _MenuLoadingView extends StatelessWidget {
  const _MenuLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: KioskLoadingPanel(
        title: 'IceBot Kiosk',
        message: 'Đang tải menu hôm nay cho bạn.',
        icon: Icons.restaurant_menu_outlined,
      ),
    );
  }
}

class _EmptyMenuView extends StatelessWidget {
  const _EmptyMenuView();

  @override
  Widget build(BuildContext context) {
    return const KioskEmptyState(
      title: 'Chưa có món sẵn sàng bán',
      message:
          'Menu kiosk hiện chưa có sản phẩm khả dụng. Vui lòng quay lại sau hoặc liên hệ nhân viên hỗ trợ.',
      icon: Icons.icecream_outlined,
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({required this.item});

  final RuntimeMenuItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
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
                    left: 16,
                    bottom: 16,
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
              padding: const EdgeInsets.all(20),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  KioskInfoPill(
                    icon: Icons.timer_outlined,
                    label: KioskFormatters.durationSeconds(
                      item.preparationTimeSeconds,
                    ),
                  ),
                  const SizedBox(height: 14),
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
