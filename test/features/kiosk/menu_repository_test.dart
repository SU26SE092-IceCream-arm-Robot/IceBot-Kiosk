import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/menu_repository.dart';

void main() {
  test(
    'real repository calls runtime-menu route and parses backend item',
    () async {
      final adapter = _RuntimeMenuAdapter(statusCode: 200, body: _successBody);
      final dio = Dio()..httpClientAdapter = adapter;
      final repository = MenuRepository(
        DioClient(baseUrl: 'https://api.icebot.test', dio: dio),
      );

      final menu = await repository.getRuntimeMenu(
        'aec68c48-207d-433d-b2fd-e7ddf7d5346a',
      );

      expect(
        adapter.lastRequest?.uri.path,
        '/api/v1/kiosks/aec68c48-207d-433d-b2fd-e7ddf7d5346a/runtime-menu',
      );
      expect(menu.availabilitySource, 'CloudSalesCatalog');
      expect(menu.containsMachineRuntimeState, isFalse);
      expect(menu.items.single.displayName, 'Kem Vanilla');
      expect(menu.items.single.finalPrice, 35000);
    },
  );

  test('real repository maps backend 404 for invalid kiosk', () async {
    final adapter = _RuntimeMenuAdapter(
      statusCode: 404,
      body: {
        'succeeded': false,
        'statusCode': 404,
        'message': 'Kiosk not found.',
      },
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final repository = MenuRepository(
      DioClient(baseUrl: 'https://api.icebot.test', dio: dio),
    );

    await expectLater(
      repository.getRuntimeMenu('00000000-0000-0000-0000-000000000000'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.type,
          'type',
          ApiErrorType.notFound,
        ),
      ),
    );
  });
}

class _RuntimeMenuAdapter implements HttpClientAdapter {
  _RuntimeMenuAdapter({required this.statusCode, required this.body});

  final int statusCode;
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
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final Map<String, Object?> _successBody = {
  'succeeded': true,
  'statusCode': 200,
  'data': {
    'snapshotId': '019eff41-0000-7000-8000-000000000001',
    'kioskId': 'aec68c48-207d-433d-b2fd-e7ddf7d5346a',
    'generatedAt': '2026-07-01T00:00:00Z',
    'expiresAt': '2026-07-01T00:00:15Z',
    'availabilitySource': 'CloudSalesCatalog',
    'containsMachineRuntimeState': false,
    'items': [
      {
        'menuId': '019eff41-9f82-7793-9349-bc56cef8baa8',
        'menuItemId': '019eff44-818a-706d-ad7c-a0bef8f63ea3',
        'productId': '019eff41-0845-721c-8052-7c417f680684',
        'productVariantId': '019eff41-0846-7790-be2e-d4c7c5b76715',
        'recipeId': null,
        'menuItemCode': 'VANILLA-PACKAGED',
        'productCode': 'VANILLA',
        'productVariantCode': 'VANILLA-PACKAGED',
        'displayName': 'Kem Vanilla',
        'description': 'Kem vanilla đóng gói',
        'price': 35000,
        'discountAmount': 0,
        'finalPrice': 35000,
        'currency': 'VND',
        'preparationTimeSeconds': 30,
      },
    ],
  },
};
