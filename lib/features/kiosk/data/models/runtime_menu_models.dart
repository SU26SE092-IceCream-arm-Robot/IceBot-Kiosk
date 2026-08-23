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
    this.image,
    this.recipeVersion,
    this.optionGroups = const [],
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
  final RuntimeMenuImage? image;
  final int? recipeVersion;
  final List<RuntimeMenuOptionGroup> optionGroups;

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
      image: map['image'] == null ? null : RuntimeMenuImage.fromJson(map['image']),
      recipeVersion: _readInt(map['recipeVersion']),
      optionGroups: _readList(
        map['optionGroups'],
        RuntimeMenuOptionGroup.fromJson,
      ),
    );
  }

  double priceForOptions(Iterable<String> selectedOptionIds) {
    final selected = selectedOptionIds.toSet();
    final optionTotal = optionGroups
        .expand((group) => group.options)
        .where((option) => selected.contains(option.productOptionId))
        .fold<double>(0, (total, option) => total + option.priceDelta);
    return finalPrice + optionTotal;
  }
}

class RuntimeMenuImage {
  const RuntimeMenuImage({required this.cardUrl, required this.detailUrl, this.altText});

  final String cardUrl;
  final String detailUrl;
  final String? altText;

  factory RuntimeMenuImage.fromJson(Object? json) {
    final map = _asMap(json);
    return RuntimeMenuImage(
      cardUrl: map['cardUrl'] as String? ?? '',
      detailUrl: map['detailUrl'] as String? ?? '',
      altText: map['altText'] as String?,
    );
  }
}

enum RuntimeOptionSelectionType { single, multiple, unknown }

class RuntimeMenuOptionGroup {
  const RuntimeMenuOptionGroup({
    required this.optionGroupId,
    required this.code,
    required this.name,
    required this.selectionType,
    required this.minSelections,
    required this.maxSelections,
    required this.isRequired,
    required this.options,
  });

  final int optionGroupId;
  final String code;
  final String name;
  final RuntimeOptionSelectionType selectionType;
  final int minSelections;
  final int maxSelections;
  final bool isRequired;
  final List<RuntimeMenuProductOption> options;

  int get effectiveMinimum =>
      isRequired && minSelections < 1 ? 1 : minSelections;

  factory RuntimeMenuOptionGroup.fromJson(Object? json) {
    final map = _asMap(json);
    final selectionType = switch (map['selectionType']?.toString()) {
      'Single' => RuntimeOptionSelectionType.single,
      'Multiple' => RuntimeOptionSelectionType.multiple,
      _ => RuntimeOptionSelectionType.unknown,
    };
    return RuntimeMenuOptionGroup(
      optionGroupId: _readInt(map['optionGroupId']) ?? 0,
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? '',
      selectionType: selectionType,
      minSelections: _readInt(map['minSelections']) ?? 0,
      maxSelections: _readInt(map['maxSelections']) ?? 0,
      isRequired: map['isRequired'] == true,
      options: _readList(map['options'], RuntimeMenuProductOption.fromJson),
    );
  }
}

class RuntimeMenuProductOption {
  const RuntimeMenuProductOption({
    required this.productOptionId,
    required this.code,
    required this.name,
    this.description,
    required this.priceDelta,
    required this.currency,
    required this.isDefault,
  });

  final String productOptionId;
  final String code;
  final String name;
  final String? description;
  final double priceDelta;
  final String currency;
  final bool isDefault;

  factory RuntimeMenuProductOption.fromJson(Object? json) {
    final map = _asMap(json);
    return RuntimeMenuProductOption(
      productOptionId: map['productOptionId'] as String? ?? '',
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      priceDelta: _readDouble(map['priceDelta']),
      currency: map['currency'] as String? ?? 'VND',
      isDefault: map['isDefault'] == true,
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
