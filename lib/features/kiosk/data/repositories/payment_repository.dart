import 'package:dio/dio.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/payment_models.dart';

class PaymentRepository {
  PaymentRepository(this._client);

  final DioClient _client;

  Future<PaymentSessionResult> createPaymentSession(
    String orderId, {
    required String orderAccessToken,
    required String idempotencyKey,
    required String paymentMethodCode,
    required double expectedAmount,
    required String expectedCurrency,
  }) async {
    final token = orderAccessToken.trim();
    final key = idempotencyKey.trim();
    if (token.isEmpty || key.isEmpty) {
      throw const ApiException(
        type: ApiErrorType.unauthorized,
        message: 'Phiên truy cập thanh toán không còn hợp lệ.',
      );
    }
    final result = await _client.postResult<PaymentSessionResult>(
      '/api/v1/orders/$orderId/payment-sessions',
      data: {
        'paymentMethodCode': paymentMethodCode.trim(),
        'expectedAmount': expectedAmount,
        'expectedCurrency': expectedCurrency.trim().toUpperCase(),
      },
      fromJson: PaymentSessionResult.fromJson,
      options: Options(
        headers: {'Idempotency-Key': key, 'Order-Access-Token': token},
      ),
    );

    final session = result.data;
    if (session == null) {
      throw const ApiException(
        type: ApiErrorType.unknown,
        message: 'Máy chủ không trả về phiên thanh toán.',
      );
    }

    return session;
  }
}
