import 'package:flutter/foundation.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/runtime_menu_models.dart';

class MenuRepository {
  MenuRepository(this._client);

  final DioClient _client;

  Future<RuntimeMenuResult> getRuntimeMenu() async {
    final result = await _client.getResult<RuntimeMenuResult>(
      '/api/v1/runtime/menu',
      fromJson: _parseRuntimeMenu,
    );

    final menu = result.data;
    if (menu == null) {
      throw const ApiException(
        type: ApiErrorType.unknown,
        message: 'Máy chủ không trả về menu kiosk.',
      );
    }

    return menu;
  }

  RuntimeMenuResult _parseRuntimeMenu(Object? json) {
    final rawMap = json is Map ? Map<String, dynamic>.from(json) : null;
    final rawItems = rawMap?['items'];
    final backendItemCount = rawItems is Iterable ? rawItems.length : -1;
    final menu = RuntimeMenuResult.fromJson(json);

    if (kDebugMode) {
      final orderableItems = menu.items
          .where((item) => item.isOrderable)
          .toList(growable: false);
      final blockerCodes =
          menu.admission?.blockers
              .map((blocker) => blocker.code)
              .where((code) => code.trim().isNotEmpty)
              .join(',') ??
          '';
      debugPrint(
        '[RuntimeMenu] backendItems=$backendItemCount '
        'parsedItems=${menu.items.length} '
        'orderableItems=${orderableItems.length} '
        'kioskId=${menu.kioskId} '
        'canPlaceOrder=${menu.admission?.canPlaceOrder} '
        'blockers=${blockerCodes.isEmpty ? 'none' : blockerCodes}',
      );

      for (final item in menu.items.where((item) => !item.isOrderable)) {
        final invalidFields = <String>[
          if (item.menuId.trim().isEmpty) 'menuId',
          if (item.menuItemId.trim().isEmpty) 'menuItemId',
          if (item.productId.trim().isEmpty) 'productId',
          if (item.productVariantId.trim().isEmpty) 'productVariantId',
          if (item.displayName.trim().isEmpty) 'displayName',
          if (item.currency.trim().isEmpty) 'currency',
          if (item.finalPrice <= 0) 'finalPrice',
        ];
        debugPrint(
          '[RuntimeMenu] filteredItem=${item.menuItemCode} '
          'invalidFields=${invalidFields.join(',')}',
        );
      }
    }

    return menu;
  }
}
