import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/order_fulfillment_items.dart';

void main() {
  testWidgets('keeps completed and failed items visibly distinct', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderFulfillmentItems(
            items: [
              _item(name: 'Kem vani', status: 'Completed'),
              _item(name: 'Kem dâu', status: 'Failed'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Kem vani'), findsOneWidget);
    expect(find.text('Đã hoàn thành'), findsOneWidget);
    expect(find.text('Kem dâu'), findsOneWidget);
    expect(find.text('Cần hỗ trợ'), findsOneWidget);
  });

  testWidgets('shows variant, quantity and selected options', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderFulfillmentItems(
            items: [
              _item(
                name: 'Kem vani',
                status: 'Preparing',
                selectedOptions: const [
                  OrderItemOptionResult(
                    productOptionId: 'option-1',
                    optionGroupCode: 'TOPPING',
                    code: 'CHOCOLATE',
                    name: 'Sốt sô-cô-la',
                    priceDelta: 5000,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Mặc định · Số lượng: 2'), findsOneWidget);
    expect(find.text('Sốt sô-cô-la'), findsOneWidget);
    expect(find.text('Đang chuẩn bị'), findsOneWidget);
  });
}

OrderItemResult _item({
  required String name,
  required String status,
  List<OrderItemOptionResult> selectedOptions = const [],
}) {
  return OrderItemResult(
    id: 'item-$name',
    menuItemId: 'menu-item-$name',
    productId: 'product-$name',
    productVariantId: 'variant-$name',
    menuItemCodeSnapshot: 'ITEM',
    menuItemNameSnapshot: name,
    productCodeSnapshot: 'PRODUCT',
    productNameSnapshot: name,
    productVariantCodeSnapshot: 'DEFAULT',
    productVariantNameSnapshot: 'Mặc định',
    quantity: 2,
    unitPrice: 35000,
    discountAmount: 0,
    totalAmount: 70000,
    status: status,
    selectedOptions: selectedOptions,
  );
}
