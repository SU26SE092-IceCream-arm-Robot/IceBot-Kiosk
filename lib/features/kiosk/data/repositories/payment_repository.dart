import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/payment_models.dart';

class PaymentRepository {
  PaymentRepository(this._client);

  final DioClient _client;

  Future<PaymentSessionResult> createPaymentSession(
    String orderId, {
    String? idempotencyKey,
    String? description,
  }) async {
    final result = await _client.postResult<PaymentSessionResult>(
      '/api/v1/orders/$orderId/payment-sessions',
      data: {
        if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty)
          'idempotencyKey': idempotencyKey.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
      fromJson: PaymentSessionResult.fromJson,
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
