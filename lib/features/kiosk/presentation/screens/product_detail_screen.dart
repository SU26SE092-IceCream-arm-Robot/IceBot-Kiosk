import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icebot_kiosk/config/routes/app_router.dart';
import 'package:icebot_kiosk/config/themes/icebot_colors.dart';
import 'package:icebot_kiosk/config/themes/icebot_spacing.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/runtime_menu_models.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/bot_step_rail.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/floating_cart_badge.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_formatters.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_panels.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/quantity_stepper_large.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({required this.menuItemId, super.key});

  final String menuItemId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  String? _configuredMenuItemId;
  final Set<String> _selectedOptionIds = {};

  void _initializeOptions(RuntimeMenuItem item) {
    if (_configuredMenuItemId == item.menuItemId) {
      return;
    }
    _configuredMenuItemId = item.menuItemId;
    _selectedOptionIds.clear();
    for (final group in item.optionGroups) {
      final defaults = group.options.where((option) => option.isDefault);
      _selectedOptionIds.addAll(
        defaults.map((option) => option.productOptionId),
      );
      final minimum = group.isRequired && group.minSelections < 1
          ? 1
          : group.minSelections;
      final selectedInGroup = group.options
          .where(
            (option) => _selectedOptionIds.contains(option.productOptionId),
          )
          .length;
      if (selectedInGroup < minimum) {
        _selectedOptionIds.addAll(
          group.options
              .where(
                (option) =>
                    !_selectedOptionIds.contains(option.productOptionId),
              )
              .take(minimum - selectedInGroup)
              .map((option) => option.productOptionId),
        );
      }
    }
  }

  void _toggleOption(
    RuntimeMenuOptionGroup group,
    RuntimeMenuProductOption option,
  ) {
    final groupIds = group.options.map((item) => item.productOptionId).toSet();
    final selectedInGroup = _selectedOptionIds.intersection(groupIds);
    final isSelected = selectedInGroup.contains(option.productOptionId);
    final minimum = group.isRequired && group.minSelections < 1
        ? 1
        : group.minSelections;
    final maximum = group.selectionType == RuntimeOptionSelectionType.single
        ? 1
        : group.maxSelections;

    if (isSelected && selectedInGroup.length <= minimum) {
      _showOptionMessage('Nhóm ${group.name} cần ít nhất $minimum lựa chọn.');
      return;
    }
    if (!isSelected &&
        group.selectionType == RuntimeOptionSelectionType.multiple &&
        selectedInGroup.length >= maximum) {
      _showOptionMessage(
        'Nhóm ${group.name} chỉ cho phép tối đa $maximum lựa chọn.',
      );
      return;
    }

    setState(() {
      if (group.selectionType == RuntimeOptionSelectionType.single) {
        _selectedOptionIds.removeAll(groupIds);
      }
      if (isSelected) {
        _selectedOptionIds.remove(option.productOptionId);
      } else {
        _selectedOptionIds.add(option.productOptionId);
      }
    });
  }

  String? _selectionError(RuntimeMenuItem item) {
    for (final group in item.optionGroups) {
      final groupIds = group.options
          .map((option) => option.productOptionId)
          .toSet();
      final count = _selectedOptionIds.intersection(groupIds).length;
      final minimum = group.isRequired && group.minSelections < 1
          ? 1
          : group.minSelections;
      final maximum = group.selectionType == RuntimeOptionSelectionType.single
          ? 1
          : group.maxSelections;
      if (group.selectionType == RuntimeOptionSelectionType.unknown) {
        return 'Nhóm ${group.name} có kiểu lựa chọn chưa được hỗ trợ.';
      }
      if (count < minimum || count > maximum) {
        return 'Vui lòng chọn từ $minimum đến $maximum mục trong ${group.name}.';
      }
    }
    return null;
  }

  void _showOptionMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = KioskScope.of(context);
    final item = controller.findMenuItem(widget.menuItemId);

    if (item == null) {
      return Scaffold(
        body: SafeArea(
          child: KioskEmptyState(
            title: 'Món này không còn trong menu',
            message:
                'Menu có thể vừa được cập nhật. Vui lòng quay lại menu để chọn món khác.',
            icon: Icons.search_off_outlined,
            actionLabel: 'Về menu',
            onAction: () => context.go(AppRouter.menu),
          ),
        ),
      );
    }
    _initializeOptions(item);

    return Scaffold(
      body: SafeArea(
        child: KioskBackdrop(
          child: Stack(
            children: [
              Column(
                children: [
                  // Header section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 28, 12),
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: BotStepRail(currentStep: 0),
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
                            Expanded(
                              child: Text(
                                'Chi tiết món',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  context,
                                ).textTheme.displayMedium,
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
                            !layout.useSingleColumn &&
                            constraints.maxWidth >= 900;
                        final info = _ProductInfo(
                          item: item,
                          containsMachineRuntimeState:
                              controller.menu?.containsMachineRuntimeState ==
                              true,
                          quantity: _quantity,
                          onDecrease: _quantity <= 1
                              ? null
                              : () => setState(() => _quantity -= 1),
                          onIncrease: () => setState(() => _quantity += 1),
                          selectedOptionIds: _selectedOptionIds,
                          onToggleOption: _toggleOption,
                        );

                        return Padding(
                          padding: EdgeInsets.all(layout.screenPadding),
                          child: useWideLayout
                              ? Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: _ProductImage(item: item),
                                    ),
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
                                    SizedBox(
                                      height: layout.bottomOverlayPadding,
                                    ),
                                  ],
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              // Floating Cart Badge
              Positioned(
                right: 28,
                bottom:
                    32 +
                    IceBotSpacing.primaryCTAHeight +
                    40, // Above the bottom bar
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
      bottomNavigationBar: KioskBottomActionBar(
        primaryLabel: 'Thêm vào giỏ hàng',
        primaryIcon: Icons.add_shopping_cart,
        onPrimary: () {
          final selectionError = _selectionError(item);
          if (selectionError != null) {
            _showOptionMessage(selectionError);
            return;
          }
          final added = controller.addToCart(
            item,
            quantity: _quantity,
            selectedOptionIds: _selectedOptionIds,
          );
          if (added) {
            context.go(AppRouter.cart);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Món này vừa không còn trong menu.'),
              ),
            );
            context.go(AppRouter.menu);
          }
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
    if (layout.isCompact) return 210;
    if (layout.isTallKiosk) return 560; // 55-60% size
    return 360;
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.item});

  final RuntimeMenuItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(IceBotSpacing.cardRadius),
      child: item.imageUrl == null || item.imageUrl!.isEmpty
          ? Container(
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                border: Border.all(color: IceBotColors.frostBorder),
                borderRadius: BorderRadius.circular(IceBotSpacing.cardRadius),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) => Center(
                  child: Icon(
                    Icons.icecream_outlined,
                    size: constraints.maxHeight < 260 ? 96 : 150,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            )
          : CachedNetworkImage(
              imageUrl: item.imageUrl!,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => LayoutBuilder(
                builder: (context, constraints) => Container(
                  color: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.icecream_outlined,
                    size: constraints.maxHeight < 260 ? 96 : 140,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
    );
  }
}

class _ProductInfo extends StatelessWidget {
  const _ProductInfo({
    required this.item,
    required this.containsMachineRuntimeState,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
    required this.selectedOptionIds,
    required this.onToggleOption,
  });

  final RuntimeMenuItem item;
  final bool containsMachineRuntimeState;
  final int quantity;
  final VoidCallback? onDecrease;
  final VoidCallback onIncrease;
  final Set<String> selectedOptionIds;
  final void Function(
    RuntimeMenuOptionGroup group,
    RuntimeMenuProductOption option,
  )
  onToggleOption;

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
              KioskFormatters.money(
                item.priceForOptions(selectedOptionIds),
                currency: item.currency,
              ),
              style: Theme.of(
                context,
              ).textTheme.displayMedium?.copyWith(color: colorScheme.primary),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (item.preparationTimeSeconds != null &&
                    item.preparationTimeSeconds! > 0)
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
            const SizedBox(height: 20),
            if (!containsMachineRuntimeState) ...[
              const _RuntimeAvailabilityNotice(),
              const SizedBox(height: 16),
            ],
            if (item.optionGroups.isNotEmpty) ...[
              for (final group in item.optionGroups) ...[
                _OptionGroupSelector(
                  group: group,
                  selectedOptionIds: selectedOptionIds,
                  onToggle: (option) => onToggleOption(group, option),
                ),
                const SizedBox(height: 20),
              ],
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Số lượng',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            QuantityStepperLarge(
              quantity: quantity,
              onIncrease: onIncrease,
              onDecrease: onDecrease,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionGroupSelector extends StatelessWidget {
  const _OptionGroupSelector({
    required this.group,
    required this.selectedOptionIds,
    required this.onToggle,
  });

  final RuntimeMenuOptionGroup group;
  final Set<String> selectedOptionIds;
  final ValueChanged<RuntimeMenuProductOption> onToggle;

  @override
  Widget build(BuildContext context) {
    final minimum = group.isRequired && group.minSelections < 1
        ? 1
        : group.minSelections;
    final maximum = group.selectionType == RuntimeOptionSelectionType.single
        ? 1
        : group.maxSelections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(group.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          minimum > 0
              ? 'Chọn từ $minimum đến $maximum'
              : 'Có thể chọn tối đa $maximum',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: group.options
              .map((option) {
                final selected = selectedOptionIds.contains(
                  option.productOptionId,
                );
                final priceLabel = option.priceDelta == 0
                    ? ''
                    : ' · +${KioskFormatters.money(option.priceDelta, currency: option.currency)}';
                return FilterChip(
                  selected: selected,
                  onSelected: (_) => onToggle(option),
                  label: Text('${option.name}$priceLabel'),
                  showCheckmark: true,
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _RuntimeAvailabilityNotice extends StatelessWidget {
  const _RuntimeAvailabilityNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(IceBotSpacing.cardRadius),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tình trạng món sẽ được xác nhận khi tạo đơn.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
