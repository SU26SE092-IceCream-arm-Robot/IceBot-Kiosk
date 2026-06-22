import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/runtime_menu_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/menu_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/order_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/payment_repository.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_controller.dart';

void main() {
  test('cart supports add, quantity changes, remove, and clear', () {
    final controller = KioskController(
      menuRepository: _FakeMenuRepository(),
      orderRepository: _FakeOrderRepository(),
      paymentRepository: _FakePaymentRepository(),
    );

    controller.addToCart(_menuItem(), quantity: 2);
    expect(controller.cartItemCount, 2);
    expect(controller.cartTotal, 70000);

    controller.increaseQuantity('menu-item-id');
    expect(controller.cartItemCount, 3);
    expect(controller.cartTotal, 105000);

    controller.decreaseQuantity('menu-item-id');
    expect(controller.cartItemCount, 2);

    controller.removeFromCart('menu-item-id');
    expect(controller.isCartEmpty, isTrue);

    controller.addToCart(_menuItem());
    controller.clearCart();
    expect(controller.isCartEmpty, isTrue);
  });
}

RuntimeMenuItem _menuItem() {
  return const RuntimeMenuItem(
    menuId: 'menu-id',
    menuItemId: 'menu-item-id',
    productId: 'product-id',
    productVariantId: 'variant-id',
    menuItemCode: 'MI-001',
    productCode: 'P-001',
    productVariantCode: 'V-001',
    displayName: 'Kem vani',
    price: 35000,
    discountAmount: 0,
    finalPrice: 35000,
    currency: 'VND',
  );
}

class _FakeMenuRepository extends MenuRepository {
  _FakeMenuRepository() : super(DioClient(baseUrl: 'http://localhost'));
}

class _FakeOrderRepository extends OrderRepository {
  _FakeOrderRepository() : super(DioClient(baseUrl: 'http://localhost'));
}

class _FakePaymentRepository extends PaymentRepository {
  _FakePaymentRepository() : super(DioClient(baseUrl: 'http://localhost'));
}
