import 'package:dio/dio.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/payment_models.dart';

class OrderRepository {
  OrderRepository(this._client);

  final DioClient _client;

  Future<OrderResult> createOrder(CreateOrderRequest request) async {
    final idempotencyKey = request.idempotencyKey?.trim();
    if (idempotencyKey == null || idempotencyKey.isEmpty) {
      throw const ApiException(
        type: ApiErrorType.validation,
        message: 'Thiếu mã chống tạo trùng đơn hàng.',
      );
    }
    final result = await _client.postResult<OrderResult>(
      '/api/v1/runtime/orders',
      data: request.toJson(),
      fromJson: OrderResult.fromJson,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );

    return _readOrder(result.data);
  }

  Future<OrderResult> getOrder(
    String orderId, {
    required String orderAccessToken,
  }) async {
    final result = await _client.getResult<OrderResult>(
      '/api/v1/runtime/orders/$orderId',
      fromJson: OrderResult.fromJson,
      options: _orderAccessOptions(orderAccessToken),
    );

    return _readOrder(result.data);
  }

  Future<PaymentStatusResult> getPaymentStatus(
    String orderId, {
    required String orderAccessToken,
  }) async {
    final result = await _client.getResult<PaymentStatusResult>(
      '/api/v1/runtime/orders/$orderId/payment-status',
      fromJson: PaymentStatusResult.fromJson,
      options: _orderAccessOptions(orderAccessToken),
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

  Future<OrderResult> cancelOrder(
    String orderId, {
    required String orderAccessToken,
    String? reason,
  }) async {
    final result = await _client.postResult<OrderResult>(
      '/api/v1/runtime/orders/$orderId/cancel',
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
      fromJson: OrderResult.fromJson,
      options: _orderAccessOptions(orderAccessToken),
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

  Options _orderAccessOptions(String token) {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      throw const ApiException(
        type: ApiErrorType.unauthorized,
        message: 'Phiên truy cập đơn hàng không còn hợp lệ.',
      );
    }
    return Options(headers: {'Order-Access-Token': normalized});
  }
}
