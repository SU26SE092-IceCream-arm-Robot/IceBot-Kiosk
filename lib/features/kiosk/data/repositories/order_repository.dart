import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/payment_models.dart';

class OrderRepository {
  OrderRepository(this._client);

  final DioClient _client;

  Future<OrderResult> createOrder(CreateOrderRequest request) async {
    final result = await _client.postResult<OrderResult>(
      '/api/v1/orders',
      data: request.toJson(),
      fromJson: OrderResult.fromJson,
    );

    return _readOrder(result.data);
  }

  Future<OrderResult> getOrder(String orderId) async {
    final result = await _client.getResult<OrderResult>(
      '/api/v1/orders/$orderId',
      fromJson: OrderResult.fromJson,
    );

    return _readOrder(result.data);
  }

  Future<PaymentStatusResult> getPaymentStatus(String orderId) async {
    final result = await _client.getResult<PaymentStatusResult>(
      '/api/v1/orders/$orderId/payment-status',
      fromJson: PaymentStatusResult.fromJson,
    );

    final status = result.data;
    if (status == null) {
      throw const ApiException(
        type: ApiErrorType.unknown,
        message: 'Máy chủ không trả về trạng thái thanh toán.',
      );
    }

    return status;
  }

  Future<OrderResult> cancelOrder(String orderId, {String? reason}) async {
    final result = await _client.postResult<OrderResult>(
      '/api/v1/orders/$orderId/cancel',
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
      fromJson: OrderResult.fromJson,
    );

    return _readOrder(result.data);
  }

  OrderResult _readOrder(OrderResult? order) {
    if (order == null) {
      throw const ApiException(
        type: ApiErrorType.unknown,
        message: 'Máy chủ không trả về đơn hàng.',
      );
    }

    return order;
  }
}
