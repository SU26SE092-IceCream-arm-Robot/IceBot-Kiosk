import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/order_models.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/order_repository.dart';

void main() {
  test(
    'places order using idempotency header and current request body',
    () async {
      final adapter = _OrderAdapter(body: _waitingForPaymentOrder);
      final dio = Dio()..httpClientAdapter = adapter;
      final repository = OrderRepository(
        DioClient(baseUrl: 'https://api.icebot.test', dio: dio),
      );

      final order = await repository.createOrder(
        const CreateOrderRequest(
          kioskId: 'kiosk-id',
          idempotencyKey: 'order-intent-001',
          clientOrderId: 'tablet-order-001',
          runtimeSnapshotId: 'legacy-snapshot-not-sent',
          channel: 'Tablet',
          clientTotalAmount: 45000,
          items: [
            CreateOrderItemRequest(
              menuItemId: 'menu-item-id',
              clientLineId: 'line-1',
              quantity: 1,
              selectedOptions: [
                SelectedProductOptionRequest(productOptionId: 'option-large'),
              ],
            ),
          ],
        ),
      );

      expect(adapter.lastRequest?.method, 'POST');
      expect(adapter.lastRequest?.uri.path, '/api/v1/orders');
      expect(
        adapter.lastRequest?.headers['Idempotency-Key'],
        'order-intent-001',
      );
      expect(adapter.lastRequest?.data, {
        'kioskId': 'kiosk-id',
        'clientOrderId': 'tablet-order-001',
        'clientTotalAmount': 45000.0,
        'items': [
          {
            'menuItemId': 'menu-item-id',
            'clientLineId': 'line-1',
            'quantity': 1,
            'selectedOptions': [
              {'productOptionId': 'option-large'},
            ],
          },
        ],
      });
      expect(order.orderAccessToken, 'order-access-token-001');
      expect(order.status, OrderStatus.pendingPayment);
      expect(order.paymentStatus, PaymentStatus.unpaid);
      expect(order.items.single.selectedOptions.single.name, 'Lớn');
    },
  );

  test('reads order with access token and derives hidden statuses', () async {
    final adapter = _OrderAdapter(body: _preparingOrder);
    final dio = Dio()..httpClientAdapter = adapter;
    final repository = OrderRepository(
      DioClient(baseUrl: 'https://api.icebot.test', dio: dio),
    );

    final order = await repository.getOrder(
      'order-id',
      orderAccessToken: 'order-access-token-001',
    );

    expect(adapter.lastRequest?.method, 'GET');
    expect(adapter.lastRequest?.uri.path, '/api/v1/orders/order-id');
    expect(
      adapter.lastRequest?.headers['Order-Access-Token'],
      'order-access-token-001',
    );
    expect(order.status, OrderStatus.preparing);
    expect(order.paymentStatus, PaymentStatus.paid);
  });

  test('rejects protected order read when access token is empty', () async {
    final repository = OrderRepository(
      DioClient(baseUrl: 'https://api.icebot.test'),
    );

    await expectLater(
      repository.getOrder('order-id', orderAccessToken: '  '),
      throwsA(
        isA<ApiException>().having(
          (error) => error.type,
          'type',
          ApiErrorType.unauthorized,
        ),
      ),
    );
  });
}

class _OrderAdapter implements HttpClientAdapter {
  _OrderAdapter({required this.body});

  final Map<String, Object?> body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode({'succeeded': true, 'statusCode': 200, 'data': body}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final Map<String, Object?> _waitingForPaymentOrder = {
  'id': 'order-id',
  'kioskId': 'kiosk-id',
  'orderAccessToken': 'order-access-token-001',
  'orderNumber': 'ORD-001',
  'clientOrderId': 'tablet-order-001',
  'currency': 'VND',
  'subtotalAmount': 45000,
  'discountAmount': 0,
  'taxAmount': 0,
  'totalAmount': 45000,
  'paidAmount': 0,
  'placedAt': '2026-07-29T09:00:00Z',
  'paymentDeadlineAt': '2026-07-29T09:15:00Z',
  'customerStatus': 'WaitingForPayment',
  'customerStatusMessage': 'Waiting for payment.',
  'canRetryPayment': true,
  'requiresStaffSupport': false,
  'items': [
    {
      'id': 'order-item-id',
      'menuItemId': 'menu-item-id',
      'productId': 'product-id',
      'productVariantId': 'variant-id',
      'clientLineId': 'line-1',
      'menuItemCode': 'MENU-001',
      'menuItemName': 'Kem Vanilla',
      'productCode': 'PRODUCT-001',
      'productName': 'Kem Vanilla',
      'productVariantCode': 'VARIANT-001',
      'productVariantName': 'Ly lớn',
      'quantity': 1,
      'unitPrice': 45000,
      'discountAmount': 0,
      'totalAmount': 45000,
      'status': 'Pending',
      'selectedOptions': [
        {
          'productOptionId': 'option-large',
          'optionGroupCode': 'SIZE',
          'code': 'LARGE',
          'name': 'Lớn',
          'priceDelta': 10000,
        },
      ],
    },
  ],
};

final Map<String, Object?> _preparingOrder = {
  ..._waitingForPaymentOrder,
  'orderAccessToken': null,
  'paidAmount': 45000,
  'paidAt': '2026-07-29T09:02:00Z',
  'customerStatus': 'Preparing',
  'customerStatusMessage': 'Payment successful. Preparing your order.',
  'canRetryPayment': false,
};
