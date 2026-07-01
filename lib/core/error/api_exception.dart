import 'package:dio/dio.dart';
import 'package:icebot_kiosk/core/network/api_result.dart';

enum ApiErrorType {
  validation,
  notFound,
  conflict,
  upstream,
  timeout,
  network,
  unknown,
}

class ApiException implements Exception {
  const ApiException({
    required this.type,
    required this.message,
    this.statusCode,
    this.validationErrors,
    this.details,
    this.businessError,
  });

  final ApiErrorType type;
  final String message;
  final int? statusCode;
  final Map<String, List<String>>? validationErrors;
  final Map<String, Object?>? details;
  final String? businessError;

  factory ApiException.fromApiResult(ApiResult<Object?> result) {
    return ApiException(
      type: _typeForStatusCode(result.statusCode),
      statusCode: result.statusCode,
      message: result.message ?? 'Yêu cầu không thành công.',
      validationErrors: result.validationErrors,
      details: result.details,
      businessError: result.businessError,
    );
  }

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    final result = _tryReadApiResult(response?.data);
    if (result != null) {
      return ApiException(
        type: _typeForStatusCode(result.statusCode),
        statusCode: result.statusCode,
        message: result.message ?? _messageForStatusCode(result.statusCode),
        validationErrors: result.validationErrors,
        details: result.details,
        businessError: result.businessError,
      );
    }

    final statusCode = response?.statusCode;
    if (statusCode != null) {
      return ApiException(
        type: _typeForStatusCode(statusCode),
        statusCode: statusCode,
        message: _messageForStatusCode(statusCode),
      );
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const ApiException(
        type: ApiErrorType.timeout,
        message: 'Kết nối quá thời gian chờ.',
      );
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.unknown) {
      return const ApiException(
        type: ApiErrorType.network,
        message: 'Không thể kết nối đến máy chủ.',
      );
    }

    return ApiException(
      type: ApiErrorType.unknown,
      message: error.message ?? 'Đã xảy ra lỗi không xác định.',
    );
  }

  static ApiResult<Object?>? _tryReadApiResult(Object? data) {
    if (data is! Map) {
      return null;
    }

    try {
      return ApiResult<Object?>.fromJson(
        Map<String, dynamic>.from(data),
        (json) => json,
      );
    } on Object {
      return null;
    }
  }

  static ApiErrorType _typeForStatusCode(int statusCode) {
    return switch (statusCode) {
      400 => ApiErrorType.validation,
      404 => ApiErrorType.notFound,
      409 => ApiErrorType.conflict,
      502 => ApiErrorType.upstream,
      _ => ApiErrorType.unknown,
    };
  }

  static String _messageForStatusCode(int statusCode) {
    return switch (statusCode) {
      400 => 'Dữ liệu gửi lên không hợp lệ.',
      404 => 'Không tìm thấy dữ liệu.',
      409 => 'Kiosk hoặc sản phẩm đang không sẵn sàng.',
      502 => 'Không thể kết nối nhà cung cấp thanh toán.',
      _ => 'Đã xảy ra lỗi khi gọi máy chủ.',
    };
  }

  @override
  String toString() => 'ApiException($statusCode, $type, $message)';
}
