import 'package:flutter/material.dart';
import 'package:icebot_kiosk/config/themes/icebot_colors.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';

class OrderFulfillmentItems extends StatelessWidget {
  const OrderFulfillmentItems({required this.items, super.key});

  final List<OrderItemResult> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tiến độ từng món', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: IceBotColors.frostBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _OrderItemRow(item: items[index]),
                if (index != items.length - 1)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item});

  final OrderItemResult item;

  @override
  Widget build(BuildContext context) {
    final status = _itemStatus(item.status);
    final name = item.menuItemNameSnapshot.isNotEmpty
        ? item.menuItemNameSnapshot
        : item.productNameSnapshot.isNotEmpty
        ? item.productNameSnapshot
        : 'Món chưa xác định';
    final variant = item.productVariantNameSnapshot;
    final options = item.selectedOptions
        .map((option) => option.name)
        .where((name) => name.isNotEmpty)
        .join(', ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(status.icon, color: status.color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  [
                    if (variant.isNotEmpty) variant,
                    'Số lượng: ${item.quantity}',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: IceBotColors.botNavyMuted,
                  ),
                ),
                if (options.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    options,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: IceBotColors.botNavyMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: status.color.withValues(alpha: 0.3)),
            ),
            child: Text(
              status.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: status.color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

_ItemStatusViewData _itemStatus(String value) {
  return switch (value.toLowerCase()) {
    'pending' => const _ItemStatusViewData(
      label: 'Chờ xử lý',
      icon: Icons.schedule_outlined,
      color: IceBotColors.warningAmber,
    ),
    'accepted' => const _ItemStatusViewData(
      label: 'Đã tiếp nhận',
      icon: Icons.inventory_2_outlined,
      color: IceBotColors.icePrimary,
    ),
    'preparing' => const _ItemStatusViewData(
      label: 'Đang chuẩn bị',
      icon: Icons.blender_outlined,
      color: IceBotColors.icePrimary,
    ),
    'completed' => const _ItemStatusViewData(
      label: 'Đã hoàn thành',
      icon: Icons.check_circle_outline,
      color: IceBotColors.mintSuccess,
    ),
    'cancelled' => const _ItemStatusViewData(
      label: 'Đã hủy',
      icon: Icons.cancel_outlined,
      color: IceBotColors.warningAmber,
    ),
    'failed' => const _ItemStatusViewData(
      label: 'Cần hỗ trợ',
      icon: Icons.support_agent_outlined,
      color: IceBotColors.dangerRed,
    ),
    _ => const _ItemStatusViewData(
      label: 'Chưa xác định',
      icon: Icons.help_outline,
      color: IceBotColors.botNavyMuted,
    ),
  };
}

class _ItemStatusViewData {
  const _ItemStatusViewData({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}
