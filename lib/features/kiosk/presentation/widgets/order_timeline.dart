import 'package:flutter/material.dart';
import 'package:icebot_kiosk/config/themes/icebot_colors.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';

class OrderTimeline extends StatelessWidget {
  const OrderTimeline({required this.order, super.key});

  final OrderResult order;

  @override
  Widget build(BuildContext context) {
    final currentStep = _stepFor(order);
    final isFailed = _isProblemState(order);
    final labels = [
      'Đã tạo đơn',
      'Đã thanh toán',
      switch (order.status) {
        OrderStatus.readyForFulfillment => 'Sẵn sàng hoàn tất',
        OrderStatus.accepted => 'Đã nhận đơn',
        _ => 'Robot đang chuẩn bị',
      },
      order.status == OrderStatus.ready ? 'Sẵn sàng nhận món' : 'Hoàn tất',
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useVerticalSteps = constraints.maxWidth < 620;
        final nodes = [
          for (var index = 0; index < labels.length; index++)
            _TimelineNode(
              label: labels[index],
              isCompleted: !isFailed && index < currentStep,
              isActive: !isFailed && index == currentStep,
              isFailed: isFailed && index == currentStep,
              isLast: index == labels.length - 1,
              isVertical: useVerticalSteps,
            ),
        ];

        if (useVerticalSteps) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: nodes,
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < nodes.length; index++) ...[
              Expanded(child: nodes[index]),
              if (index != nodes.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }

  int _stepFor(OrderResult order) {
    return switch (order.status) {
      OrderStatus.draft || OrderStatus.pendingPayment => 0,
      OrderStatus.paid => 1,
      OrderStatus.readyForFulfillment ||
      OrderStatus.accepted ||
      OrderStatus.preparing => 2,
      OrderStatus.ready => 3,
      OrderStatus.completed ||
      OrderStatus.refunded ||
      OrderStatus.compensated => 3,
      OrderStatus.cancelled ||
      OrderStatus.failed ||
      OrderStatus.executionRejected ||
      OrderStatus.fulfillmentIssue ||
      OrderStatus.refundRequired ||
      OrderStatus.unknown => 0,
    };
  }

  bool _isProblemState(OrderResult order) {
    return order.requiresStaffSupport ||
        order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.failed ||
        order.status == OrderStatus.executionRejected ||
        order.status == OrderStatus.fulfillmentIssue ||
        order.status == OrderStatus.refundRequired ||
        order.status == OrderStatus.unknown;
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.label,
    required this.isCompleted,
    required this.isActive,
    required this.isFailed,
    required this.isLast,
    required this.isVertical,
  });

  final String label;
  final bool isCompleted;
  final bool isActive;
  final bool isFailed;
  final bool isLast;
  final bool isVertical;

  @override
  Widget build(BuildContext context) {
    final primary = IceBotColors.icePrimary;
    final success = IceBotColors.mintSuccess;
    final error = IceBotColors.dangerRed;
    final inactive = const Color(0xFFCBD5E1);

    final color = isFailed
        ? error
        : isCompleted
        ? success
        : isActive
        ? primary
        : inactive;

    final bgColor = isFailed
        ? IceBotColors.dangerContainer
        : isCompleted
        ? IceBotColors.mintSuccessContainer
        : isActive
        ? IceBotColors.icePrimaryContainer
        : Colors.white;

    Widget nodeContent = Container(
      constraints: const BoxConstraints(minHeight: 72),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: isActive || isFailed ? 2 : 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isCompleted)
            Icon(Icons.check_circle_rounded, color: color, size: 24)
          else if (isFailed)
            Icon(Icons.error_outline_rounded, color: color, size: 24)
          else if (isActive)
            Icon(Icons.sync_rounded, color: color, size: 24),
          if (isCompleted || isFailed || isActive) const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: (isActive || isFailed || isCompleted)
                    ? color
                    : const Color(0xFF64748B),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (isVertical) {
      return Column(
        children: [
          SizedBox(width: double.infinity, child: nodeContent),
          if (!isLast)
            Container(
              width: 2,
              height: 24,
              color: isCompleted ? success : inactive,
            ),
        ],
      );
    }

    return nodeContent;
  }
}
