import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/config/routes/app_router.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/runtime_menu_models.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_error_panel.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_formatters.dart';

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
        title: const Text('IceBot'),
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
                        SizedBox(height: isWide ? 28 : 20),
                        Expanded(
                          child: GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: isWide ? 390 : 340,
                                  mainAxisSpacing: 22,
                                  crossAxisSpacing: 22,
                                  childAspectRatio: isWide ? 0.78 : 0.72,
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

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Menu hôm nay',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Chọn món kem bạn muốn mua. Menu hiển thị theo cấu hình bán hàng của kiosk.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            AppConfig.demoMode ? 'Demo - $itemCount món' : '$itemCount món',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
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
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(strokeWidth: 5),
            ),
            SizedBox(height: 24),
            Text(
              'Đang tải menu kiosk...',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMenuView extends StatelessWidget {
  const _EmptyMenuView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.icecream_outlined,
              size: 88,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Chưa có món sẵn sàng bán',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Vui lòng quay lại sau hoặc liên hệ nhân viên hỗ trợ.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(AppRouter.productPath(item.menuItemId)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: item.imageUrl == null || item.imageUrl!.isEmpty
                  ? Container(
                      color: colorScheme.primaryContainer,
                      child: Icon(
                        Icons.icecream_outlined,
                        size: 76,
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
                          size: 76,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
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
                  Text(
                    KioskFormatters.money(
                      item.finalPrice,
                      currency: item.currency,
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    KioskFormatters.durationSeconds(
                      item.preparationTimeSeconds,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
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
}
