typedef JsonDecoder<T> = T Function(Object? json);

/// Standard response wrapper returned by the IceBot backend.
class ApiResult<T> {
  const ApiResult({
    required this.succeeded,
    required this.statusCode,
    this.message,
    this.data,
    this.details,
    this.validationErrors,
    this.businessError,
    this.systemError,
  });

  final bool succeeded;
  final int statusCode;
  final String? message;
  final T? data;
  final Map<String, Object?>? details;
  final Map<String, List<String>>? validationErrors;
  final String? businessError;
  final String? systemError;

  factory ApiResult.fromJson(
    Map<String, dynamic> json,
    JsonDecoder<T> decodeData,
  ) {
    return ApiResult<T>(
      succeeded: json['succeeded'] == true,
      statusCode: _readInt(json['statusCode']) ?? 0,
      message: json['message'] as String?,
      data: json['data'] == null ? null : decodeData(json['data']),
      details: _readObjectMap(json['details']),
      validationErrors: _readValidationErrors(json['validationErrors']),
      businessError: json['businessError'] as String?,
      systemError: json['systemError'] as String?,
    );
  }

  static int? _readInt(Object? value) {
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

  static Map<String, Object?>? _readObjectMap(Object? value) {
    if (value is! Map) {
      return null;
    }

    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }

  static Map<String, List<String>>? _readValidationErrors(Object? value) {
    if (value is! Map) {
      return null;
    }

    final errors = <String, List<String>>{};
    for (final entry in value.entries) {
      final rawValue = entry.value;
      if (rawValue is Iterable) {
        errors[entry.key.toString()] = rawValue
            .map((item) => item.toString())
            .toList(growable: false);
      } else if (rawValue != null) {
        errors[entry.key.toString()] = [rawValue.toString()];
      }
    }

    return errors.isEmpty ? null : errors;
  }
}
