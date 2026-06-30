import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icebot_kiosk/config/routes/app_router.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/runtime_menu_models.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_formatters.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_panels.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({required this.menuItemId, super.key});

  final String menuItemId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final controller = KioskScope.of(context);
    final item = controller.findMenuItem(widget.menuItemId);

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết món')),
        body: KioskEmptyState(
          title: 'Món này không còn trong menu',
          message:
              'Menu có thể vừa được cập nhật. Vui lòng quay lại menu để chọn món khác.',
          icon: Icons.search_off_outlined,
          actionLabel: 'Về menu',
          onAction: () => context.go(AppRouter.menu),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết món'),
        leading: IconButton(
          tooltip: 'Về menu',
          onPressed: () => context.go(AppRouter.menu),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Giỏ hàng',
            onPressed: () => context.go(AppRouter.cart),
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: KioskBackdrop(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layout = KioskLayoutSpec.of(context);
              final useWideLayout =
                  !layout.useSingleColumn && constraints.maxWidth >= 900;
              final info = _ProductInfo(
                item: item,
                quantity: _quantity,
                onDecrease: _quantity <= 1
                    ? null
                    : () => setState(() => _quantity -= 1),
                onIncrease: () => setState(() => _quantity += 1),
              );

              return Padding(
                padding: EdgeInsets.all(layout.screenPadding),
                child: useWideLayout
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 5, child: _ProductImage(item: item)),
                          const SizedBox(width: 32),
                          Expanded(flex: 5, child: info),
                        ],
                      )
                    : ListView(
                        children: [
                          SizedBox(
                            height: _portraitImageHeight(layout),
                            child: _ProductImage(item: item),
                          ),
                          SizedBox(height: layout.sectionGap),
                          info,
                          SizedBox(height: layout.bottomOverlayPadding),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: KioskBottomActionBar(
        primaryLabel: 'Thêm vào giỏ hàng',
        primaryIcon: Icons.add_shopping_cart,
        onPrimary: () {
          controller.addToCart(item, quantity: _quantity);
          context.go(AppRouter.cart);
        },
        secondaryLabel: 'Về menu',
        secondaryIcon: Icons.arrow_back,
        onSecondary: () => context.go(AppRouter.menu),
        leading: Text(
          'Tạm tính: ${KioskFormatters.money(item.finalPrice * _quantity, currency: item.currency)}',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  double _portraitImageHeight(KioskLayoutSpec layout) {
    if (layout.isCompact) {
      return 260;
    }
    if (layout.isTallKiosk) {
      return 520;
    }
    return 340;
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.item});

  final RuntimeMenuItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: item.imageUrl == null || item.imageUrl!.isEmpty
          ? Container(
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                border: Border.all(color: const Color(0xFFD8E3DF)),
              ),
              child: Center(
                child: Icon(
                  Icons.icecream_outlined,
                  size: 150,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            )
          : CachedNetworkImage(
              imageUrl: item.imageUrl!,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(
                color: colorScheme.primaryContainer,
                child: Icon(
                  Icons.icecream_outlined,
                  size: 140,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
    );
  }
}

class _ProductInfo extends StatelessWidget {
  const _ProductInfo({
    required this.item,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  final RuntimeMenuItem item;
  final int quantity;
  final VoidCallback? onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final layout = KioskLayoutSpec.of(context);

    return KioskSectionCard(
      padding: EdgeInsets.all(layout.isCompact ? 22 : 30),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.displayName,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 16),
            Text(
              item.description?.isNotEmpty == true
                  ? item.description!
                  : 'Kem tươi tự động IceBot.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            Text(
              KioskFormatters.money(item.finalPrice, currency: item.currency),
              style: Theme.of(
                context,
              ).textTheme.displayMedium?.copyWith(color: colorScheme.primary),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _InfoChip(
                  icon: Icons.timer_outlined,
                  label: KioskFormatters.durationSeconds(
                    item.preparationTimeSeconds,
                  ),
                ),
                if (item.sizeCode != null && item.sizeCode!.isNotEmpty)
                  _InfoChip(
                    icon: Icons.local_drink_outlined,
                    label: 'Size ${item.sizeCode}',
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _CustomizationNotice(),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Số lượng',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                KioskInfoPill(
                  label:
                      'Tạm tính: ${KioskFormatters.money(item.finalPrice * quantity, currency: item.currency)}',
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.filledTonal(
                  iconSize: 34,
                  onPressed: onDecrease,
                  icon: const Icon(Icons.remove),
                ),
                Container(
                  width: 124,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$quantity',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                ),
                IconButton.filledTonal(
                  iconSize: 34,
                  onPressed: onIncrease,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colorScheme.onPrimaryContainer, size: 24),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomizationNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Text(
        'Món này hiện chưa có tuỳ chọn thêm. Khi backend cung cấp cấu hình hương vị, topping hoặc size, các lựa chọn sẽ hiển thị tại đây.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: const Color(0xFF92400E),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
