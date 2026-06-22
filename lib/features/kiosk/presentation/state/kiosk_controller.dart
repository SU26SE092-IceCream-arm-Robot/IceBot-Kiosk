import 'package:flutter/foundation.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/payment_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/runtime_menu_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/menu_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/order_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/payment_repository.dart';

class KioskController extends ChangeNotifier {
  KioskController({
    required MenuRepository menuRepository,
    required OrderRepository orderRepository,
    required PaymentRepository paymentRepository,
  }) : _menuRepository = menuRepository,
       _orderRepository = orderRepository,
       _paymentRepository = paymentRepository;

  final MenuRepository _menuRepository;
  final OrderRepository _orderRepository;
  final PaymentRepository _paymentRepository;

  RuntimeMenuResult? _menu;
  ApiException? _menuError;
  bool _isLoadingMenu = false;

  final Map<String, CartLine> _cartLines = {};

  bool _isCheckingOut = false;
  ApiException? _checkoutError;
  OrderResult? _activeOrder;
  PaymentSessionResult? _activePaymentSession;
  PaymentStatusResult? _activePaymentStatus;
  ApiException? _trackingError;
  bool _isCancellingOrder = false;

  RuntimeMenuResult? get menu => _menu;
  ApiException? get menuError => _menuError;
  bool get isLoadingMenu => _isLoadingMenu;
  bool get hasMenu => _menu != null;

  List<RuntimeMenuItem> get menuItems => _menu?.items ?? const [];

  List<CartLine> get cartLines => List.unmodifiable(_cartLines.values);
  bool get isCartEmpty => _cartLines.isEmpty;
  int get cartItemCount =>
      _cartLines.values.fold(0, (total, line) => total + line.quantity);
  double get cartTotal =>
      _cartLines.values.fold(0, (total, line) => total + line.lineTotal);

  bool get isCheckingOut => _isCheckingOut;
  ApiException? get checkoutError => _checkoutError;
  OrderResult? get activeOrder => _activeOrder;
  PaymentSessionResult? get activePaymentSession => _activePaymentSession;
  PaymentStatusResult? get activePaymentStatus => _activePaymentStatus;
  ApiException? get trackingError => _trackingError;
  bool get isCancellingOrder => _isCancellingOrder;

  Future<void> loadMenu({bool force = false}) async {
    if (!AppConfig.hasKioskId) {
      return;
    }
    if (_isLoadingMenu) {
      return;
    }
    if (!force && _menu != null) {
      return;
    }

    _isLoadingMenu = true;
    _menuError = null;
    notifyListeners();

    try {
      _menu = await _menuRepository.getRuntimeMenu(AppConfig.effectiveKioskId);
      _menuError = null;
    } on ApiException catch (error) {
      _menu = null;
      _menuError = error;
    } on Object {
      _menu = null;
      _menuError = const ApiException(
        type: ApiErrorType.unknown,
        message: 'Không thể tải menu kiosk.',
      );
    } finally {
      _isLoadingMenu = false;
      notifyListeners();
    }
  }

  RuntimeMenuItem? findMenuItem(String menuItemId) {
    for (final item in menuItems) {
      if (item.menuItemId == menuItemId) {
        return item;
      }
    }

    return null;
  }

  void addToCart(RuntimeMenuItem item, {int quantity = 1}) {
    if (quantity <= 0) {
      return;
    }

    final current = _cartLines[item.menuItemId];
    _cartLines[item.menuItemId] = current == null
        ? CartLine(item: item, quantity: quantity)
        : current.copyWith(quantity: current.quantity + quantity);
    notifyListeners();
  }

  void increaseQuantity(String menuItemId) {
    final current = _cartLines[menuItemId];
    if (current == null) {
      return;
    }

    _cartLines[menuItemId] = current.copyWith(quantity: current.quantity + 1);
    notifyListeners();
  }

  void decreaseQuantity(String menuItemId) {
    final current = _cartLines[menuItemId];
    if (current == null) {
      return;
    }

    if (current.quantity <= 1) {
      _cartLines.remove(menuItemId);
    } else {
      _cartLines[menuItemId] = current.copyWith(quantity: current.quantity - 1);
    }
    notifyListeners();
  }

  void removeFromCart(String menuItemId) {
    if (_cartLines.remove(menuItemId) != null) {
      notifyListeners();
    }
  }

  void clearCart() {
    if (_cartLines.isEmpty) {
      return;
    }

    _cartLines.clear();
    notifyListeners();
  }

  Future<CheckoutResult?> checkout() async {
    if (_cartLines.isEmpty || _menu == null || !AppConfig.hasKioskId) {
      return null;
    }
    if (_isCheckingOut) {
      return null;
    }

    _isCheckingOut = true;
    _checkoutError = null;
    notifyListeners();

    final nonce = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
    final orderRequest = CreateOrderRequest(
      kioskId: AppConfig.effectiveKioskId,
      idempotencyKey: 'tablet-order-$nonce',
      clientOrderId: 'tablet-$nonce',
      runtimeSnapshotId: _menu!.snapshotId,
      runtimeSnapshotGeneratedAt: _menu!.generatedAt,
      clientTotalAmount: cartTotal,
      items: cartLines
          .map(
            (line) => CreateOrderItemRequest(
              menuItemId: line.item.menuItemId,
              clientLineId: 'line-${line.item.menuItemId}',
              quantity: line.quantity,
            ),
          )
          .toList(growable: false),
    );

    try {
      final order = await _orderRepository.createOrder(orderRequest);
      final paymentSession = await _paymentRepository.createPaymentSession(
        order.id,
        idempotencyKey: 'tablet-payment-$nonce',
        description: 'IceBot ${order.orderNumber}',
      );

      _activeOrder = order;
      _activePaymentSession = paymentSession;
      _activePaymentStatus = null;
      _trackingError = null;
      _cartLines.clear();
      return CheckoutResult(order: order, paymentSession: paymentSession);
    } on ApiException catch (error) {
      _checkoutError = error;
      return null;
    } on Object {
      _checkoutError = const ApiException(
        type: ApiErrorType.unknown,
        message: 'Không thể tạo đơn hàng hoặc phiên thanh toán.',
      );
      return null;
    } finally {
      _isCheckingOut = false;
      notifyListeners();
    }
  }

  Future<PaymentStatusResult?> refreshPaymentStatus(String orderId) async {
    try {
      final status = await _orderRepository.getPaymentStatus(orderId);
      _activePaymentStatus = status;
      _trackingError = null;
      notifyListeners();
      return status;
    } on ApiException catch (error) {
      _trackingError = error;
      notifyListeners();
      return null;
    } on Object {
      _trackingError = const ApiException(
        type: ApiErrorType.unknown,
        message: 'Không thể cập nhật trạng thái thanh toán.',
      );
      notifyListeners();
      return null;
    }
  }

  Future<OrderResult?> refreshOrder(String orderId) async {
    try {
      final order = await _orderRepository.getOrder(orderId);
      _activeOrder = order;
      _trackingError = null;
      notifyListeners();
      return order;
    } on ApiException catch (error) {
      _trackingError = error;
      notifyListeners();
      return null;
    } on Object {
      _trackingError = const ApiException(
        type: ApiErrorType.unknown,
        message: 'Không thể cập nhật trạng thái đơn hàng.',
      );
      notifyListeners();
      return null;
    }
  }

  Future<OrderResult?> cancelActiveOrder({String? reason}) async {
    final order = _activeOrder;
    if (order == null || _isCancellingOrder) {
      return null;
    }

    _isCancellingOrder = true;
    _trackingError = null;
    notifyListeners();

    try {
      final cancelled = await _orderRepository.cancelOrder(
        order.id,
        reason: reason ?? 'Customer cancelled before payment.',
      );
      _activeOrder = cancelled;
      return cancelled;
    } on ApiException catch (error) {
      _trackingError = error;
      return null;
    } on Object {
      _trackingError = const ApiException(
        type: ApiErrorType.unknown,
        message: 'Không thể hủy đơn hàng.',
      );
      return null;
    } finally {
      _isCancellingOrder = false;
      notifyListeners();
    }
  }
}

class CartLine {
  const CartLine({required this.item, required this.quantity});

  final RuntimeMenuItem item;
  final int quantity;

  double get lineTotal => item.finalPrice * quantity;

  CartLine copyWith({int? quantity}) {
    return CartLine(item: item, quantity: quantity ?? this.quantity);
  }
}

class CheckoutResult {
  const CheckoutResult({required this.order, required this.paymentSession});

  final OrderResult order;
  final PaymentSessionResult paymentSession;
}
