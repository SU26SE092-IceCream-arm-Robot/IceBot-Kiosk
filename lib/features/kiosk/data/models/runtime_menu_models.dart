class RuntimeMenuResult {
  const RuntimeMenuResult({
    required this.snapshotId,
    required this.kioskId,
    required this.generatedAt,
    required this.expiresAt,
    required this.availabilitySource,
    required this.containsMachineRuntimeState,
    required this.items,
  });

  final String snapshotId;
  final String kioskId;
  final DateTime generatedAt;
  final DateTime expiresAt;
  final String availabilitySource;
  final bool containsMachineRuntimeState;
  final List<RuntimeMenuItem> items;

  factory RuntimeMenuResult.fromJson(Object? json) {
    final map = _asMap(json);
    return RuntimeMenuResult(
      snapshotId: map['snapshotId'] as String? ?? '',
      kioskId: map['kioskId'] as String? ?? '',
      generatedAt: _readDateTime(map['generatedAt']),
      expiresAt: _readDateTime(map['expiresAt']),
      availabilitySource:
          map['availabilitySource'] as String? ?? 'CloudSalesCatalog',
      containsMachineRuntimeState: map['containsMachineRuntimeState'] == true,
      items: _readList(map['items'], RuntimeMenuItem.fromJson),
    );
  }
}

class RuntimeMenuItem {
  const RuntimeMenuItem({
    required this.menuId,
    required this.menuItemId,
    required this.productId,
    required this.productVariantId,
    this.recipeId,
    required this.menuItemCode,
    required this.productCode,
    required this.productVariantCode,
    required this.displayName,
    this.description,
    this.sizeCode,
    required this.price,
    required this.discountAmount,
    required this.finalPrice,
    required this.currency,
    this.preparationTimeSeconds,
    this.imageUrl,
    this.recipeVersion,
  });

  final String menuId;
  final String menuItemId;
  final String productId;
  final String productVariantId;
  final String? recipeId;
  final String menuItemCode;
  final String productCode;
  final String productVariantCode;
  final String displayName;
  final String? description;
  final String? sizeCode;
  final double price;
  final double discountAmount;
  final double finalPrice;
  final String currency;
  final int? preparationTimeSeconds;
  final String? imageUrl;
  final int? recipeVersion;

  bool get isOrderable =>
      menuId.trim().isNotEmpty &&
      menuItemId.trim().isNotEmpty &&
      productId.trim().isNotEmpty &&
      productVariantId.trim().isNotEmpty &&
      displayName.trim().isNotEmpty &&
      currency.trim().isNotEmpty &&
      finalPrice > 0;

  factory RuntimeMenuItem.fromJson(Object? json) {
    final map = _asMap(json);
    return RuntimeMenuItem(
      menuId: map['menuId'] as String? ?? '',
      menuItemId: map['menuItemId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productVariantId: map['productVariantId'] as String? ?? '',
      recipeId: map['recipeId'] as String?,
      menuItemCode: map['menuItemCode'] as String? ?? '',
      productCode: map['productCode'] as String? ?? '',
      productVariantCode: map['productVariantCode'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      description: map['description'] as String?,
      sizeCode: map['sizeCode'] as String?,
      price: _readDouble(map['price']),
      discountAmount: _readDouble(map['discountAmount']),
      finalPrice: _readDouble(map['finalPrice']),
      currency: map['currency'] as String? ?? 'VND',
      preparationTimeSeconds: _readInt(map['preparationTimeSeconds']),
      imageUrl: map['imageUrl'] as String?,
      recipeVersion: _readInt(map['recipeVersion']),
    );
  }
}

Map<String, dynamic> _asMap(Object? json) {
  if (json is Map<String, dynamic>) {
    return json;
  }
  if (json is Map) {
    return Map<String, dynamic>.from(json);
  }
  throw const FormatException('Expected a JSON object.');
}

List<T> _readList<T>(Object? value, T Function(Object? json) decode) {
  if (value is! List) {
    return const [];
  }

  return value.map(decode).toList(growable: false);
}

DateTime _readDateTime(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  return DateTime.fromMillisecondsSinceEpoch(0);
}

double _readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}

int? _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
