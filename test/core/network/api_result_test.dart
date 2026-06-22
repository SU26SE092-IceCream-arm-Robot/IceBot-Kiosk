import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/core/network/api_result.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/runtime_menu_models.dart';

void main() {
  test('parses successful runtime menu wrapper', () {
    final result = ApiResult<RuntimeMenuResult>.fromJson({
      'succeeded': true,
      'statusCode': 200,
      'message': 'Operation successful.',
      'data': {
        'snapshotId': 'snapshot-id',
        'kioskId': 'kiosk-id',
        'generatedAt': '2026-06-18T00:00:00Z',
        'expiresAt': '2026-06-18T00:00:15Z',
        'availabilitySource': 'CloudSalesCatalog',
        'containsMachineRuntimeState': false,
        'items': [
          {
            'menuId': 'menu-id',
            'menuItemId': 'menu-item-id',
            'productId': 'product-id',
            'productVariantId': 'variant-id',
            'recipeId': 'recipe-id',
            'menuItemCode': 'MI-001',
            'productCode': 'P-001',
            'productVariantCode': 'V-001',
            'displayName': 'Kem vani',
            'description': 'Ly kem vani',
            'sizeCode': 'M',
            'price': 35000,
            'discountAmount': 0,
            'finalPrice': 35000,
            'currency': 'VND',
            'preparationTimeSeconds': 90,
            'imageUrl': 'https://example.test/ice-cream.png',
            'recipeVersion': 1,
          },
        ],
      },
    }, RuntimeMenuResult.fromJson);

    expect(result.succeeded, isTrue);
    expect(result.data?.kioskId, 'kiosk-id');
    expect(result.data?.items.single.displayName, 'Kem vani');
    expect(result.data?.items.single.finalPrice, 35000);
  });

  test('parses validation errors from failed wrapper', () {
    final result = ApiResult<Object?>.fromJson({
      'succeeded': false,
      'statusCode': 400,
      'message': 'Validation failed',
      'validationErrors': {
        'items': ['Order must contain at least one item.'],
      },
    }, (json) => json);

    expect(result.succeeded, isFalse);
    expect(result.validationErrors?['items'], hasLength(1));
  });
}
