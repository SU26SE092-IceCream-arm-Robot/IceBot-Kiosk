import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/payment_repository.dart';

void main() {
  test('creates payment session with the backend request contract', () async {
    final adapter = _PaymentSessionAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final repository = PaymentRepository(
      DioClient(baseUrl: 'https://api.icebot.test', dio: dio),
    );

    final session = await repository.createPaymentSession(
      '019eff41-0000-7000-8000-000000000001',
      idempotencyKey: 'payment-intent-001',
      description: 'IceBot ORD-001',
    );

    expect(
      adapter.lastRequest?.uri.path,
      '/api/v1/orders/019eff41-0000-7000-8000-000000000001/payment-sessions',
    );
    expect(adapter.lastRequest?.method, 'POST');
    expect(adapter.lastRequest?.data, {
      'idempotencyKey': 'payment-intent-001',
      'description': 'IceBot ORD-001',
    });
    expect(session.orderId, '019eff41-0000-7000-8000-000000000001');
    expect(session.qrCodePayload, 'PAYLOAD-001');
    expect(session.hasPaymentAccess, isTrue);
  });
}

class _PaymentSessionAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode({
        'succeeded': true,
        'statusCode': 200,
        'data': {
          'paymentTransactionId': '019eff41-0000-7000-9000-000000000001',
          'orderId': '019eff41-0000-7000-8000-000000000001',
          'transactionNumber': 'PAY-001',
          'provider': 'PayOS',
          'checkoutUrl': 'https://pay.icebot.test/session/001',
          'qrCodePayload': 'PAYLOAD-001',
          'amount': 35000,
          'currency': 'VND',
          'status': 'Pending',
          'expiresAt': '2026-07-01T12:15:00Z',
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
