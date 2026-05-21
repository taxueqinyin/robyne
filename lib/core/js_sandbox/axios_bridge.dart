import 'package:dio/dio.dart';

class AxiosRequest {
  final String method;
  final String url;
  final Map<String, dynamic>? data;
  final Map<String, String>? headers;
  final Map<String, dynamic>? params;
  final int? timeout;

  AxiosRequest({
    required this.method,
    required this.url,
    this.data,
    this.headers,
    this.params,
    this.timeout,
  });

  factory AxiosRequest.fromJson(Map<String, dynamic> json) {
    return AxiosRequest(
      method: json['method'] as String? ?? 'get',
      url: json['url'] as String,
      data: json['data'] as Map<String, dynamic>?,
      headers: (json['headers'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v.toString())),
      params: json['params'] as Map<String, dynamic>?,
      timeout: json['timeout'] as int?,
    );
  }
}

class AxiosResponse {
  final int status;
  final String statusText;
  final dynamic data;
  final Map<String, String> headers;

  AxiosResponse({
    required this.status,
    required this.statusText,
    required this.data,
    required this.headers,
  });

  Map<String, dynamic> toJson() => {
        'status': status,
        'statusText': statusText,
        'data': data,
        'headers': headers,
      };
}

class AxiosBridge {
  final Dio _dio;

  AxiosBridge({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            ));

  Future<AxiosResponse> request(AxiosRequest request) async {
    try {
      final response = await _dio.request(
        request.url,
        data: request.data,
        queryParameters: request.params,
        options: Options(
          method: request.method,
          headers: request.headers,
          receiveTimeout: request.timeout != null
              ? Duration(milliseconds: request.timeout!)
              : null,
        ),
      );

      return AxiosResponse(
        status: response.statusCode ?? 0,
        statusText: response.statusMessage ?? '',
        data: response.data,
        headers: response.headers.map
            .map((k, v) => MapEntry(k, v.join(', '))),
      );
    } on DioException catch (e) {
      return AxiosResponse(
        status: e.response?.statusCode ?? 0,
        statusText: e.message ?? 'Network Error',
        data: e.response?.data,
        headers: {},
      );
    }
  }

  String generateAxiosJs() {
    return '''
      const axios = {
        get: function(url, config) {
          return this.request(Object.assign({ method: 'get', url: url }, config || {}));
        },
        post: function(url, data, config) {
          return this.request(Object.assign({ method: 'post', url: url, data: data }, config || {}));
        },
        put: function(url, data, config) {
          return this.request(Object.assign({ method: 'put', url: url, data: data }, config || {}));
        },
        delete: function(url, config) {
          return this.request(Object.assign({ method: 'delete', url: url }, config || {}));
        },
        request: function(config) {
          return new Promise(function(resolve, reject) {
            var requestId = '__axios_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
            window[requestId] = { resolve: resolve, reject: reject };
            var message = JSON.stringify({
              id: requestId,
              method: config.method || 'get',
              url: config.url,
              data: config.data,
              headers: config.headers,
              params: config.params,
              timeout: config.timeout
            });
            if (typeof flutter_js_bridge !== 'undefined') {
              flutter_js_bridge.postMessage(message);
            }
          });
        }
      };
    ''';
  }
}
