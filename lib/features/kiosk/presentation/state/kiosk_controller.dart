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
    String? kioskId,
  }) : _menuRepository = menuRepository,
       _orderRepository = orderRepository,
       _paymentRepository = paymentRepository,
       _kioskId = kioskId?.trim().isNotEmpty == true
           ? kioskId!.trim()
           : AppConfig.effectiveKioskId,
       _hasKioskId = kioskId?.trim().isNotEmpty == true || AppConfig.hasKioskId;

  final MenuRepository _menuRepository;
  final OrderRepository _orderRepository;
  final PaymentRepository _paymentRepository;
  final String _kioskId;
  final bool _hasKioskId;

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
  bool _isRefreshingPaymentStatus = false;
  bool _isCancellingOrder = false;
  _CheckoutIntent? _checkoutIntent;
  OrderResult? _recoverableOrder;
  String? _paymentAttemptIdempotencyKey;
  int _nonceSequence = 0;

  RuntimeMenuResult? get menu => _menu;
  ApiException? get menuError => _menuError;
  bool get isLoadingMenu => _isLoadingMenu;
  bool get hasMenu => _menu != null;

  List<RuntimeMenuItem> get menuItems =>
      _menu?.items.where((item) => item.isOrderable).toList(growable: false) ??
      const [];

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
  bool get isRefreshingPaymentStatus => _isRefreshingPaymentStatus;
  bool get isCancellingOrder => _isCancellingOrder;
  bool get canRetryPayment {
    final order = _recoverableOrder ?? _activeOrder;
    if (order == null) {
      return false;
    }

    return _activePaymentStatus?.canRetryPayment ?? order.canRetryPayment;
  }

  Future<void> loadMenu({bool force = false}) async {
    if (!_hasKioskId) {
      _menuError = const ApiException(
        type: ApiErrorType.validation,
        message: 'Kiosk chưa được cấu hình. Vui lòng thiết lập Kiosk ID.',
      );
      notifyListeners();
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
      final menu = await _menuRepository.getRuntimeMenu(_kioskId);
      _menu = menu;
      _reconcileCartWith(menu);
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

  bool addToCart(RuntimeMenuItem item, {int quantity = 1}) {
    if (quantity <= 0) {
      return false;
    }

    final currentMenuItem = findMenuItem(item.menuItemId);
    if (_menu != null && currentMenuItem == null) {
      return false;
    }

    final orderableItem = currentMenuItem ?? item;
    final current = _cartLines[orderableItem.menuItemId];
    _cartLines[orderableItem.menuItemId] = current == null
        ? CartLine(item: orderableItem, quantity: quantity)
        : current.copyWith(quantity: current.quantity + quantity);
    notifyListeners();
    return true;
  }

  void _reconcileCartWith(RuntimeMenuResult menu) {
    if (_recoverableOrder != null) {
      return;
    }

    final currentItems = {
      for (final item in menu.items.where((item) => item.isOrderable))
        item.menuItemId: item,
    };

    _cartLines.removeWhere(
      (menuItemId, line) => !currentItems.containsKey(menuItemId),
    );
    for (final entry in _cartLines.entries.toList(growable: false)) {
      final refreshedItem = currentItems[entry.key];
      if (refreshedItem != null) {
        _cartLines[entry.key] = CartLine(
          item: refreshedItem,
          quantity: entry.value.quantity,
        );
      }
    }

    _checkoutIntent = null;
    _paymentAttemptIdempotencyKey = null;
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
    if (_isCheckingOut) {
      return null;
    }
    if (!_hasKioskId) {
      return _rejectCheckout(
        const ApiException(
          type: ApiErrorType.validation,
          message: 'Kiosk chưa được cấu hình nên chưa thể tạo đơn.',
        ),
      );
    }
    if (_menu == null) {
      return _rejectCheckout(
        const ApiException(
          type: ApiErrorType.validation,
          message: 'Vui lòng tải menu trước khi tạo đơn hàng.',
        ),
      );
    }
    if (_cartLines.isEmpty) {
      return _rejectCheckout(
        const ApiException(
          type: ApiErrorType.validation,
          message: 'Giỏ hàng đang trống. Vui lòng chọn ít nhất một món.',
        ),
      );
    }

    _isCheckingOut = true;
    _checkoutError = null;
    notifyListeners();

    try {
      final fingerprint = _cartFingerprint;
      var intent = _checkoutIntent;
      if (intent == null || intent.cartFingerprint != fingerprint) {
        if (intent != null && intent.cartFingerprint != fingerprint) {
          _recoverableOrder = null;
        }
        await loadMenu(force: true);
        if (_menuError != null || _menu == null) {
          _checkoutError = _menuLoadCheckoutError(_menuError);
          return null;
        }

        final cartError = _validateCartAgainstMenu();
        if (cartError != null) {
          _checkoutError = cartError;
          return null;
        }

        intent = _createCheckoutIntent(_cartFingerprint);
        _checkoutIntent = intent;
        _recoverableOrder = null;
        _paymentAttemptIdempotencyKey = null;
        _activePaymentSession = null;
        _activePaymentStatus = null;
      }

      final cartError = _validateCartAgainstMenu();
      if (cartError != null) {
        _checkoutError = cartError;
        return null;
      }

      OrderResult order;
      try {
        order =
            _recoverableOrder ??
            await _orderRepository.createOrder(intent.orderRequest);
      } on ApiException catch (error) {
        await _handleCreateOrderError(error);
        return null;
      }

      _activeOrder = order;
      _recoverableOrder = order;
      notifyListeners();

      return await _createPaymentSessionFor(order);
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

  CheckoutResult? _rejectCheckout(ApiException error) {
    _checkoutError = error;
    notifyListeners();
    return null;
  }

  ApiException? _validateCartAgainstMenu() {
    if (_cartLines.isEmpty) {
      return const ApiException(
        type: ApiErrorType.validation,
        message: 'Giỏ hàng không còn món hợp lệ. Vui lòng chọn lại món.',
      );
    }

    final menuById = {for (final item in menuItems) item.menuItemId: item};
    for (final line in _cartLines.values) {
      if (line.quantity <= 0) {
        return const ApiException(
          type: ApiErrorType.validation,
          message: 'Số lượng món phải lớn hơn 0.',
        );
      }

      final currentItem = menuById[line.item.menuItemId];
      if (currentItem == null) {
        return const ApiException(
          type: ApiErrorType.conflict,
          statusCode: 409,
          message: 'Một món trong giỏ không còn thuộc menu hiện tại.',
        );
      }
    }

    final currencies = _cartLines.values
        .map((line) => line.item.currency.toUpperCase())
        .toSet();
    if (currencies.length > 1) {
      return const ApiException(
        type: ApiErrorType.validation,
        message: 'Các món trong đơn phải sử dụng cùng một loại tiền tệ.',
      );
    }

    return null;
  }

  Future<void> _handleCreateOrderError(ApiException error) async {
    if (_requiresMenuRefresh(error)) {
      _checkoutIntent = null;
      _paymentAttemptIdempotencyKey = null;
      await loadMenu(force: true);

      if (_menuError != null || _menu == null) {
        _checkoutError = _menuLoadCheckoutError(_menuError);
        return;
      }

      _checkoutError = ApiException(
        type: ApiErrorType.conflict,
        statusCode: error.statusCode,
        message: _cartLines.isEmpty
            ? 'Menu vừa thay đổi và món trong giỏ không còn khả dụng. Vui lòng chọn lại món.'
            : 'Menu hoặc giá món vừa thay đổi. Giỏ hàng đã được cập nhật, vui lòng kiểm tra lại.',
        details: error.details,
        businessError: error.businessError,
      );
      return;
    }

    _checkoutError = _friendlyCreateOrderError(error);
  }

  bool _requiresMenuRefresh(ApiException error) {
    if (error.type == ApiErrorType.notFound) {
      return true;
    }
    if (error.type != ApiErrorType.conflict) {
      return false;
    }
    if (error.details?.containsKey('calculatedTotalAmount') == true) {
      return true;
    }

    final message = error.message.toLowerCase();
    return message.contains('client total') ||
        message.contains('menu item') ||
        message.contains('menu ') ||
        message.contains('product') ||
        message.contains('variant') ||
        message.contains('recipe') ||
        message.contains('production route');
  }

  ApiException _friendlyCreateOrderError(ApiException error) {
    final message = switch (error.type) {
      ApiErrorType.validation =>
        'Thông tin đơn hàng chưa hợp lệ. Vui lòng kiểm tra lại giỏ hàng.',
      ApiErrorType.notFound =>
        'Kiosk hoặc món trong giỏ không còn tồn tại. Vui lòng tải lại menu.',
      ApiErrorType.conflict =>
        'Kiosk hiện không thể nhận đơn. Vui lòng thử lại sau hoặc liên hệ nhân viên.',
      ApiErrorType.timeout ||
      ApiErrorType.network => 'Không thể kết nối để tạo đơn. Vui lòng thử lại.',
      _ => 'Backend chưa thể tạo đơn hàng. Vui lòng thử lại sau.',
    };

    return ApiException(
      type: error.type,
      statusCode: error.statusCode,
      message: message,
      validationErrors: error.validationErrors,
      details: error.details,
      businessError: error.businessError,
    );
  }

  ApiException _menuLoadCheckoutError(ApiException? error) {
    if (error == null) {
      return const ApiException(
        type: ApiErrorType.unknown,
        message: 'Không thể cập nhật menu trước khi tạo đơn.',
      );
    }

    final message = switch (error.type) {
      ApiErrorType.notFound =>
        'Không tìm thấy kiosk hoặc menu. Vui lòng liên hệ nhân viên.',
      ApiErrorType.conflict =>
        'Kiosk hiện không sẵn sàng nhận đơn. Vui lòng thử lại sau.',
      ApiErrorType.timeout || ApiErrorType.network =>
        'Không thể cập nhật menu trước khi tạo đơn. Vui lòng kiểm tra kết nối.',
      _ => 'Không thể cập nhật menu trước khi tạo đơn.',
    };

    return ApiException(
      type: error.type,
      statusCode: error.statusCode,
      message: message,
      validationErrors: error.validationErrors,
      details: error.details,
      businessError: error.businessError,
    );
  }

  Future<CheckoutResult?> retryPaymentSession() async {
    final order = _recoverableOrder ?? _activeOrder;
    if (order == null || _isCheckingOut || !canRetryPayment) {
      return null;
    }

    _isCheckingOut = true;
    _checkoutError = null;
    _trackingError = null;

    // A completed failed/expired session is a new payment attempt. For an
    // uncertain network failure before a session was returned, the existing
    // key is retained so the backend can deduplicate the retry.
    if (_activePaymentSession != null) {
      _paymentAttemptIdempotencyKey = null;
    }
    notifyListeners();

    try {
      return await _createPaymentSessionFor(order);
    } on ApiException catch (error) {
      _checkoutError = error;
      return null;
    } on Object {
      _checkoutError = const ApiException(
        type: ApiErrorType.unknown,
        message: 'Không thể tạo lại phiên thanh toán.',
      );
      return null;
    } finally {
      _isCheckingOut = false;
      notifyListeners();
    }
  }

  Future<CheckoutResult> _createPaymentSessionFor(OrderResult order) async {
    final paymentKey = _paymentAttemptIdempotencyKey ??=
        'tablet-payment-${_newNonce()}';

    try {
      final paymentSession = await _paymentRepository.createPaymentSession(
        order.id,
        idempotencyKey: paymentKey,
        description: 'IceBot ${order.orderNumber}',
      );
      _validatePaymentSession(paymentSession, order);

      _activeOrder = order;
      _activePaymentSession = paymentSession;
      _activePaymentStatus = null;
      _trackingError = null;
      _checkoutError = null;
      _recoverableOrder = null;
      _checkoutIntent = null;
      _paymentAttemptIdempotencyKey = null;
      _cartLines.clear();
      return CheckoutResult(order: order, paymentSession: paymentSession);
    } on ApiException catch (error) {
      if (error.type != ApiErrorType.network &&
          error.type != ApiErrorType.timeout) {
        _paymentAttemptIdempotencyKey = null;
      }
      rethrow;
    }
  }

  _CheckoutIntent _createCheckoutIntent(String cartFingerprint) {
    final nonce = _newNonce();
    return _CheckoutIntent(
      cartFingerprint: cartFingerprint,
      orderRequest: CreateOrderRequest(
        kioskId: _kioskId,
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
      ),
    );
  }

  String get _cartFingerprint {
    final parts =
        cartLines
            .map(
              (line) =>
                  '${line.item.menuItemId}:${line.quantity}:${line.item.finalPrice}',
            )
            .toList(growable: false)
          ..sort();
    return parts.join('|');
  }

  String _newNonce() {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    return '$timestamp-${_nonceSequence++}';
  }

  Future<PaymentStatusResult?> refreshPaymentStatus(String orderId) async {
    if (_isRefreshingPaymentStatus) {
      return null;
    }

    _isRefreshingPaymentStatus = true;
    try {
      final status = await _orderRepository.getPaymentStatus(orderId);
      _validatePaymentStatus(status, orderId);
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
    } finally {
      _isRefreshingPaymentStatus = false;
    }
  }

  void _validatePaymentSession(
    PaymentSessionResult session,
    OrderResult order,
  ) {
    if (session.orderId.isEmpty || session.orderId != order.id) {
      throw const ApiException(
        type: ApiErrorType.unknown,
        message: 'Phiên thanh toán không khớp với đơn hàng.',
      );
    }
    if (session.paymentTransactionId.isEmpty ||
        session.transactionNumber.isEmpty ||
        session.provider.isEmpty) {
      throw const ApiException(
        type: ApiErrorType.unknown,
        message: 'Thông tin phiên thanh toán chưa đầy đủ.',
      );
    }
    if (session.amount <= 0 ||
        (session.amount - order.totalAmount).abs() > 0.01 ||
        session.currency.trim().toUpperCase() !=
            order.currency.trim().toUpperCase()) {
      throw const ApiException(
        type: ApiErrorType.conflict,
        message: 'Số tiền thanh toán không khớp với đơn hàng.',
      );
    }
    if (!session.hasPaymentAccess) {
      throw const ApiException(
        type: ApiErrorType.upstream,
        message:
            'Chưa nhận được mã QR hoặc trang thanh toán. Vui lòng thử lại.',
      );
    }
    if (session.isExpiredAt(DateTime.now())) {
      throw const ApiException(
        type: ApiErrorType.conflict,
        message: 'Phiên thanh toán đã hết hạn. Vui lòng tạo lại mã.',
      );
    }
    if (session.status == PaymentTransactionStatus.failed ||
        session.status == PaymentTransactionStatus.cancelled ||
        session.status == PaymentTransactionStatus.refunded ||
        session.status == PaymentTransactionStatus.expired ||
        session.status == PaymentTransactionStatus.unknown) {
      throw const ApiException(
        type: ApiErrorType.conflict,
        message: 'Phiên thanh toán không còn khả dụng.',
      );
    }
  }

  void _validatePaymentStatus(PaymentStatusResult status, String orderId) {
    if (status.orderId.isEmpty || status.orderId != orderId) {
      throw const ApiException(
        type: ApiErrorType.unknown,
        message: 'Trạng thái thanh toán không khớp với đơn hàng.',
      );
    }
    if (status.paymentTransactionId.isEmpty ||
        status.paymentTransactionStatus == PaymentTransactionStatus.unknown) {
      throw const ApiException(
        type: ApiErrorType.unknown,
        message: 'Trạng thái thanh toán từ máy chủ không hợp lệ.',
      );
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

class _CheckoutIntent {
  const _CheckoutIntent({
    required this.cartFingerprint,
    required this.orderRequest,
  });

  final String cartFingerprint;
  final CreateOrderRequest orderRequest;
}
