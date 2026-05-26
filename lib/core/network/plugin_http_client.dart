import 'dart:convert';

import 'package:dio/dio.dart';

class PluginHttpClient {
  PluginHttpClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 60),
              sendTimeout: const Duration(seconds: 30),
            ),
          );

  final Dio _dio;

  Future<Map<String, Object?>> request(Map<String, Object?> config) async {
    final url = _normalizeUrl((config['url'] ?? '').toString());
    final method = (config['method'] ?? 'GET').toString().toUpperCase();
    late final Response<Object?> response;
    try {
      response = await _requestWithRetry(url, method, config);
    } on DioException catch (error) {
      throw DioException(
        requestOptions: error.requestOptions,
        response: error.response,
        type: error.type,
        error: error.error,
        stackTrace: error.stackTrace,
        message: '$method $url failed: ${error.message}',
      );
    }
    final data = _decodeResponseData(response.data, config['responseType']);

    return <String, Object?>{
      'data': data,
      'status': response.statusCode,
      'statusText': response.statusMessage,
      'headers': response.headers.map,
      'requestOptions': <String, Object?>{
        'uri': response.requestOptions.uri.toString(),
      },
    };
  }

  Future<Response<Object?>> _requestWithRetry(
    String url,
    String method,
    Map<String, Object?> config,
  ) async {
    DioException? lastError;
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        return await _dio.request<Object?>(
          url,
          data: config['data'],
          queryParameters: _mapValue(config['params']),
          options: Options(
            method: method,
            headers: _headers(config),
            responseType: ResponseType.plain,
            followRedirects: config['followRedirects'] as bool? ?? true,
            validateStatus: (_) => true,
          ),
        );
      } on DioException catch (error) {
        lastError = error;
        if (!_shouldRetry(error) || attempt == 2) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
    throw lastError!;
  }

  static bool _shouldRetry(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.connectionError => true,
      _ => false,
    };
  }

  static String _normalizeUrl(String url) {
    return url.replaceAll(RegExp(r'\?%s$'), '').replaceAll(RegExp(r'%s$'), '');
  }

  static Object? _decodeResponseData(Object? data, Object? responseType) {
    if (responseType == 'text' || data is! String) {
      return data;
    }
    try {
      return jsonDecode(data) as Object?;
    } catch (_) {
      return data;
    }
  }

  static Map<String, dynamic>? _mapValue(Object? value) {
    if (value is! Map) {
      return null;
    }
    return value.map(
      (key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
    );
  }

  static Map<String, String>? _stringMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    return value.map(
      (key, dynamic mapValue) => MapEntry(key.toString(), mapValue.toString()),
    );
  }

  static Map<String, String>? _headers(Map<String, Object?> config) {
    final headers = _stringMap(config['headers']) ?? <String, String>{};
    final method = (config['method'] ?? 'GET').toString().toUpperCase();
    if (method != 'GET' &&
        config['data'] is String &&
        !headers.keys.any((key) => key.toLowerCase() == 'content-type')) {
      headers['content-type'] = 'application/x-www-form-urlencoded';
    }
    return headers.isEmpty ? null : headers;
  }
}
