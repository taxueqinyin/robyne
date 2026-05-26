import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:quickjs_engine/quickjs_engine.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/network/plugin_http_client.dart';
import '../../../core/result/result.dart';
import '../domain/plugin_runtime.dart';

class QuickJsPluginRuntimeFactory implements PluginRuntimeFactory {
  QuickJsPluginRuntimeFactory({
    required PluginHttpClient httpClient,
    String vendorAssetPath = 'assets/js/musicfree_vendor.js',
  }) : _httpClient = httpClient,
       _vendorAssetPath = vendorAssetPath;

  final PluginHttpClient _httpClient;
  final String _vendorAssetPath;

  @override
  Future<PluginRuntime> create() async {
    String? vendorSource;
    try {
      vendorSource = await rootBundle.loadString(_vendorAssetPath);
    } catch (_) {
      vendorSource = null;
    }
    return QuickJsPluginRuntime(
      httpClient: _httpClient,
      vendorSource: vendorSource,
    );
  }
}

class QuickJsPluginRuntime implements PluginRuntime {
  QuickJsPluginRuntime({
    required PluginHttpClient httpClient,
    String? vendorSource,
  }) : _httpClient = httpClient {
    _runtime = getJavascriptRuntime(xhr: false);
    _runtime.onMessage('robyneHttp', _handleHttpRequest);
    _runtime.evaluate(_bootstrapScript);
    if (vendorSource != null && vendorSource.trim().isNotEmpty) {
      _runtime.evaluate(vendorSource);
    }
  }

  final PluginHttpClient _httpClient;
  late final JavascriptRuntime _runtime;

  @override
  Future<Result<Map<String, Object?>>> loadPlugin(String source) async {
    try {
      final escapedSource = jsonEncode(source);
      final result = _runtime.evaluate('''
        (() => {
          const module = { exports: {} };
          const exports = module.exports;
          const require = globalThis.__robyneRequire;
          const pluginFactory = new Function('module', 'exports', 'require', $escapedSource);
          pluginFactory(module, exports, require);
          globalThis.__robynePlugin = module.exports;
          return JSON.stringify({
            platform: module.exports.platform,
            version: module.exports.version,
            author: module.exports.author,
            description: module.exports.description,
            supportedSearchType: module.exports.supportedSearchType || [],
            userVariables: module.exports.userVariables || []
          });
        })()
      ''');

      if (result.isError) {
        return Failure(
          AppError(
            code: 'plugin.load_failed',
            message: result.stringResult,
            cause: result.rawResult,
          ),
        );
      }

      final decoded = jsonDecode(result.stringResult);
      if (decoded is! Map) {
        return const Failure(
          AppError(
            code: 'plugin.invalid_exports',
            message: 'Plugin metadata was not an object.',
          ),
        );
      }

      return Ok(_objectMap(decoded));
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'plugin.load_failed',
          message: 'Failed to load JavaScript plugin.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<Object?>> callMethod(
    String method,
    List<Object?> arguments, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final encodedMethod = jsonEncode(method);
      final encodedArgs = jsonEncode(arguments);
      final result = _runtime.evaluate('''
        (async () => {
          const method = globalThis.__robynePlugin[$encodedMethod];
          if (typeof method !== 'function') {
            throw new Error('Plugin method not found: ' + $encodedMethod);
          }
          const value = await method(...$encodedArgs);
          return JSON.stringify(value === undefined ? null : value);
        })()
      ''');

      if (result.isError) {
        return Failure(
          AppError(
            code: 'plugin.runtime_error',
            message: result.stringResult,
            cause: result.rawResult,
          ),
        );
      }

      final resolved = await _runtime.handlePromise(result, timeout: timeout);
      if (resolved.isError) {
        return Failure(
          AppError(
            code: 'plugin.runtime_error',
            message: resolved.stringResult,
            cause: resolved.rawResult,
          ),
        );
      }
      return Ok(jsonDecode(resolved.stringResult) as Object?);
    } on TimeoutException catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'plugin.method_timeout',
          message: 'Plugin method $method timed out.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'plugin.runtime_error',
          message: 'Plugin method $method failed.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<void> dispose() async {
    _runtime.dispose();
  }

  Future<String> _handleHttpRequest(dynamic args) async {
    final payload = args is Map ? _objectMap(args) : <String, Object?>{};
    try {
      final response = await _httpClient.request(payload);
      return jsonEncode(<String, Object?>{'ok': true, 'response': response});
    } catch (error) {
      return jsonEncode(<String, Object?>{
        'ok': false,
        'error': error.toString(),
      });
    }
  }

  static Map<String, Object?> _objectMap(Map<dynamic, dynamic> value) {
    return value.map(
      (key, dynamic mapValue) => MapEntry(key.toString(), mapValue as Object?),
    );
  }
}

const _bootstrapScript = r'''
  globalThis.__robyneModules = {};
  globalThis.env = { getUserVariables: function() { return {}; } };

  async function __robyneHttp(config) {
    const payload = JSON.stringify(config || {});
    const raw = await sendMessage('robyneHttp', payload);
    const envelope = typeof raw === 'string' ? JSON.parse(raw) : raw;
    if (!envelope.ok) {
      throw new Error(envelope.error || 'Network request failed');
    }
    return envelope.response;
  }

  function createAxios() {
    const axios = function(config) {
      return __robyneHttp(config);
    };
    axios.get = function(url, config) {
      return axios(Object.assign({}, config || {}, { url: url, method: 'GET' }));
    };
    axios.post = function(url, data, config) {
      return axios(Object.assign({}, config || {}, { url: url, data: data, method: 'POST' }));
    };
    axios.default = axios;
    return axios;
  }

  globalThis.__robyneModules.axios = createAxios();
  globalThis.__robyneRequire = function(name) {
    if (Object.prototype.hasOwnProperty.call(globalThis.__robyneModules, name)) {
      return globalThis.__robyneModules[name];
    }
    throw new Error('Unsupported module: ' + name);
  };
''';
