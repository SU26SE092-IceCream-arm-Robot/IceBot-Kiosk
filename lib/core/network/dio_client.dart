import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/core/network/api_result.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

/// A custom Dio client wrapper to manage API configurations and request life cycle.
class DioClient {
  final Dio _dio;

  DioClient({
    required String baseUrl,
    Dio? dio,
    List<Interceptor>? interceptors,
  }) : _dio = dio ?? Dio() {
    _dio
      ..options.baseUrl = _normalizeBaseUrl(baseUrl)
      ..options.connectTimeout = const Duration(seconds: 15)
      ..options.receiveTimeout = const Duration(seconds: 15)
      ..options.sendTimeout = const Duration(seconds: 15)
      ..options.headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

    if (kDebugMode) {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: false,
          requestBody: false,
          responseBody: false,
          responseHeader: false,
          error: false,
          compact: true,
          maxWidth: 90,
        ),
      );
    }

    if (interceptors != null && interceptors.isNotEmpty) {
      _dio.interceptors.addAll(interceptors);
    }
  }

  Dio get dio => _dio;

  Future<ApiResult<T>> getResult<T>(
    String path, {
    required JsonDecoder<T> fromJson,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final response = await get(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );

    return _readResult(response, fromJson);
  }

  Future<ApiResult<T>> postResult<T>(
    String path, {
    required JsonDecoder<T> fromJson,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final response = await post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );

    return _readResult(response, fromJson);
  }

  // GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Exception _handleDioError(DioException dioException) {
    return ApiException.fromDio(dioException);
  }

  ApiResult<T> _readResult<T>(
    Response<dynamic> response,
    JsonDecoder<T> fromJson,
  ) {
    final data = response.data;
    if (data is! Map) {
      throw const ApiException(
        type: ApiErrorType.unknown,
        message: 'Định dạng phản hồi máy chủ không hợp lệ.',
      );
    }

    final result = ApiResult<T>.fromJson(
      Map<String, dynamic>.from(data),
      fromJson,
    );

    if (!result.succeeded) {
      throw ApiException.fromApiResult(
        ApiResult<Object?>(
          succeeded: result.succeeded,
          statusCode: result.statusCode,
          message: result.message,
          data: result.data,
          details: result.details,
          validationErrors: result.validationErrors,
          businessError: result.businessError,
          systemError: result.systemError,
        ),
      );
    }

    return result;
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    return trimmed.replaceFirst(RegExp(r'/+$'), '');
  }
}
