import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:quickjs_engine/quickjs_engine.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/network/plugin_http_client.dart';
import '../../../core/result/result.dart';
import '../application/plugin_runtime_config.dart';
import '../domain/plugin_definition.dart';
import '../domain/plugin_runtime.dart';
import '../domain/plugin_search_executor.dart';

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

class QuickJsIsolatePluginSearchExecutor implements PluginSearchExecutor {
  QuickJsIsolatePluginSearchExecutor({
    String vendorAssetPath = 'assets/js/musicfree_vendor.js',
    Future<String?> Function()? vendorSourceLoader,
  }) : _vendorAssetPath = vendorAssetPath,
       _vendorSourceLoader = vendorSourceLoader;

  final String _vendorAssetPath;
  final Future<String?> Function()? _vendorSourceLoader;
  Future<String?>? _vendorSourceFuture;

  @override
  Future<Result<Object?>> search({
    required PluginDefinition plugin,
    required String source,
    required String keyword,
    required int page,
    required String searchType,
  }) async {
    try {
      final vendorSource = await _loadVendorSource();
      final response = await Isolate.run<Map<String, Object?>>(
        () => _runQuickJsSearchInIsolate(<String, Object?>{
          'source': source,
          'userVariables': plugin.userVariableValues,
          'keyword': keyword,
          'page': page,
          'searchType': searchType,
          'timeoutMs': pluginMethodTimeout.inMilliseconds,
          'vendorSource': vendorSource,
        }),
        debugName: 'robyne-plugin-search-${plugin.platform}',
      );
      if (response['ok'] == true) {
        return Ok(response['value']);
      }
      return Failure(
        AppError(
          code: response['code']?.toString() ?? 'plugin.search_failed',
          message:
              response['message']?.toString() ??
              'Plugin ${plugin.platform} search failed.',
        ),
      );
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'plugin.search_isolate_failed',
          message: 'Plugin ${plugin.platform} search failed off the UI thread.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<String?> _loadVendorSource() {
    return _vendorSourceFuture ??= _loadVendorSourceUncached();
  }

  Future<String?> _loadVendorSourceUncached() async {
    final loader = _vendorSourceLoader;
    if (loader != null) {
      return loader();
    }
    try {
      return await rootBundle.loadString(_vendorAssetPath);
    } catch (_) {
      return null;
    }
  }
}

Future<Map<String, Object?>> _runQuickJsSearchInIsolate(
  Map<String, Object?> request,
) async {
  final runtime = QuickJsPluginRuntime(
    httpClient: PluginHttpClient(),
    vendorSource: request['vendorSource'] as String?,
  );
  try {
    final loaded = await runtime.loadPlugin(
      request['source']?.toString() ?? '',
      userVariables: _stringMapValue(request['userVariables']),
    );
    if (loaded case Failure<Map<String, Object?>>(:final error)) {
      return _isolateFailure(error);
    }

    final result = await runtime.callMethod(
      'search',
      <Object?>[
        request['keyword']?.toString() ?? '',
        (request['page'] as int?) ?? 1,
        request['searchType']?.toString() ?? 'music',
      ],
      timeout: Duration(milliseconds: (request['timeoutMs'] as int?) ?? 15000),
    );
    return switch (result) {
      Ok<Object?>(:final value) => <String, Object?>{
        'ok': true,
        'value': value,
      },
      Failure<Object?>(:final error) => _isolateFailure(error),
    };
  } catch (error) {
    return <String, Object?>{
      'ok': false,
      'code': 'plugin.search_failed',
      'message': error.toString(),
    };
  } finally {
    await runtime.dispose();
  }
}

Map<String, Object?> _isolateFailure(AppError error) {
  return <String, Object?>{
    'ok': false,
    'code': error.code,
    'message': error.message,
  };
}

Map<String, String> _stringMapValue(Object? value) {
  if (value is! Map) {
    return const <String, String>{};
  }
  return value.map(
    (key, dynamic mapValue) => MapEntry(key.toString(), mapValue.toString()),
  );
}

class QuickJsPluginRuntime implements PluginRuntime {
  QuickJsPluginRuntime({
    required PluginHttpClient httpClient,
    String? vendorSource,
  }) : _httpClient = httpClient {
    _runtime = getJavascriptRuntime(xhr: false);
    _runtime.onMessage('robyneHttp', _trackHttpRequest);
    _runtime.onMessage('robyneSetTimeout', _scheduleTimeout);
    _runtime.onMessage('robyneClearTimeout', _clearTimeout);
    _runtime.evaluate(_bootstrapScript);
    if (vendorSource != null && vendorSource.trim().isNotEmpty) {
      _runtime.evaluate(vendorSource);
    }
  }

  final PluginHttpClient _httpClient;
  late final JavascriptRuntime _runtime;
  final Set<Future<void>> _pendingBridgeCalls = <Future<void>>{};
  final Set<Future<void>> _pendingMethodCalls = <Future<void>>{};
  final Set<Future<void>> _pendingTimerCallbacks = <Future<void>>{};
  final Map<int, Timer> _scheduledTimers = <int, Timer>{};
  bool _disposing = false;
  bool _disposed = false;

  @override
  Future<Result<Map<String, Object?>>> loadPlugin(
    String source, {
    Map<String, String> userVariables = const <String, String>{},
  }) async {
    if (_disposing || _disposed) {
      return const Failure(
        AppError(
          code: 'plugin.runtime_disposed',
          message: 'Plugin runtime has already been disposed.',
        ),
      );
    }
    try {
      final escapedSource = jsonEncode(source);
      final encodedUserVariables = jsonEncode(userVariables);
      final result = _runtime.evaluate('''
        (() => {
          globalThis.__robyneUserVariables = $encodedUserVariables;
          const module = { exports: {} };
          const exports = module.exports;
          const require = globalThis.__robyneRequire;
          const pluginFactory = new Function('module', 'exports', 'require', $escapedSource);
          pluginFactory(module, exports, require);
          const exported = globalThis.__robyneNormalizePluginExport(module.exports);
          globalThis.__robynePlugin = exported;
          return JSON.stringify({
            platform: exported.platform,
            version: exported.version,
            author: exported.author,
            description: exported.description,
            supportedSearchType: exported.supportedSearchType || [],
            userVariables: exported.userVariables || []
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
    if (_disposing || _disposed) {
      return const Failure(
        AppError(
          code: 'plugin.runtime_disposed',
          message: 'Plugin runtime has already been disposed.',
        ),
      );
    }
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

      final resolved = await _trackMethodCall(
        _resolveEvaluation(result),
      ).timeout(timeout);
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
    if (_disposed) {
      return;
    }
    _disposing = true;
    _cancelScheduledTimers();
    _clearJavaScriptTimeoutCallbacks();
    await _waitForPendingWork();
    _disposed = true;
    _runtime.dispose();
  }

  String _trackHttpRequest(dynamic args) {
    if (_disposing || _disposed) {
      return 'false';
    }

    final payload = args is Map ? _objectMap(args) : <String, Object?>{};
    final id = _intValue(payload['id']);
    final config = payload['config'] is Map
        ? _objectMap(payload['config'] as Map<dynamic, dynamic>)
        : <String, Object?>{};
    if (id == null) {
      return 'false';
    }

    final request = _completeHttpRequest(id, config);
    final pending = request.then<void>((_) {}, onError: (_, _) {});
    _pendingBridgeCalls.add(pending);
    unawaited(
      pending.whenComplete(() {
        _pendingBridgeCalls.remove(pending);
      }),
    );
    return 'true';
  }

  Future<JsEvalResult> _trackMethodCall(Future<JsEvalResult> call) {
    final pending = call.then<void>((_) {}, onError: (_, _) {});
    _pendingMethodCalls.add(pending);
    unawaited(
      pending.whenComplete(() {
        _pendingMethodCalls.remove(pending);
      }),
    );
    return call;
  }

  Future<JsEvalResult> _resolveEvaluation(JsEvalResult result) async {
    final rawResult = result.rawResult;
    if (rawResult is Future) {
      return _pumpQuickJsFuture(rawResult);
    }
    return _runtime.handlePromise(result);
  }

  Future<JsEvalResult> _pumpQuickJsFuture(Future<dynamic> future) async {
    Object? value;
    Object? error;
    StackTrace? stackTrace;
    var completed = false;

    unawaited(
      future.then<void>(
        (resolved) {
          value = resolved;
          completed = true;
        },
        onError: (Object caughtError, StackTrace caughtStackTrace) {
          error = caughtError;
          stackTrace = caughtStackTrace;
          completed = true;
        },
      ),
    );

    while (!completed) {
      if (_disposing || _disposed) {
        throw StateError('Plugin runtime is being disposed.');
      }
      _runtime.executePendingJob();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    _runtime.executePendingJob();

    if (error != null) {
      Error.throwWithStackTrace(error!, stackTrace ?? StackTrace.current);
    }
    return JsEvalResult(value?.toString() ?? 'null', value);
  }

  String _scheduleTimeout(dynamic args) {
    if (_disposing || _disposed) {
      return 'false';
    }

    final payload = args is Map ? _objectMap(args) : <String, Object?>{};
    final id = _intValue(payload['id']);
    if (id == null) {
      return 'false';
    }

    final duration = Duration(
      milliseconds: (_intValue(payload['timeout']) ?? 0).clamp(0, 0x7fffffff),
    );
    _scheduledTimers[id]?.cancel();
    _scheduledTimers[id] = Timer(duration, () {
      _scheduledTimers.remove(id);
      if (_disposing || _disposed) {
        return;
      }

      final callback = Future<void>.sync(() {
        final result = _runtime.evaluate('globalThis.__robyneRunTimeout($id);');
        if (!result.isError) {
          _runtime.executePendingJob();
        }
      });
      _pendingTimerCallbacks.add(callback);
      unawaited(
        callback.whenComplete(() {
          _pendingTimerCallbacks.remove(callback);
        }),
      );
    });
    return 'true';
  }

  String _clearTimeout(dynamic args) {
    final payload = args is Map ? _objectMap(args) : <String, Object?>{};
    final id = _intValue(payload['id']);
    if (id != null) {
      _scheduledTimers.remove(id)?.cancel();
    }
    return 'true';
  }

  Future<void> _completeHttpRequest(int id, Map<String, Object?> config) async {
    late final Map<String, Object?> envelope;
    try {
      final response = await _httpClient.request(config);
      envelope = <String, Object?>{'ok': true, 'response': response};
    } catch (error) {
      envelope = <String, Object?>{'ok': false, 'error': error.toString()};
    }

    if (_disposing || _disposed) {
      return;
    }

    final encodedEnvelope = jsonEncode(envelope);
    final result = _runtime.evaluate(
      'globalThis.__robyneResolveHttp($id, $encodedEnvelope);',
    );
    if (!result.isError) {
      _runtime.executePendingJob();
    }
  }

  Future<void> _waitForPendingWork() async {
    final deadline = DateTime.now().add(pluginMethodTimeout);
    while (_pendingBridgeCalls.isNotEmpty ||
        _pendingMethodCalls.isNotEmpty ||
        _pendingTimerCallbacks.isNotEmpty) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        break;
      }

      var timedOut = false;
      await Future.wait<void>(<Future<void>>[
        ..._pendingBridgeCalls,
        ..._pendingMethodCalls,
        ..._pendingTimerCallbacks,
      ]).timeout(
        remaining,
        onTimeout: () {
          timedOut = true;
          return <void>[];
        },
      );
      _runtime.executePendingJob();
      if (timedOut) {
        break;
      }
    }
  }

  void _cancelScheduledTimers() {
    for (final timer in _scheduledTimers.values) {
      timer.cancel();
    }
    _scheduledTimers.clear();
  }

  void _clearJavaScriptTimeoutCallbacks() {
    if (_disposed) {
      return;
    }
    try {
      _runtime.evaluate('globalThis.__robyneClearAllTimeouts();');
    } catch (_) {
      // Best-effort cleanup before releasing the QuickJS runtime.
    }
  }

  static Map<String, Object?> _objectMap(Map<dynamic, dynamic> value) {
    return value.map(
      (key, dynamic mapValue) => MapEntry(key.toString(), mapValue as Object?),
    );
  }

  static int? _intValue(Object? value) {
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
}

const _bootstrapScript = r'''
  globalThis.__robyneModules = {};
  globalThis.__robyneUserVariables = {};
  globalThis.env = {
    getUserVariables: function() {
      return globalThis.__robyneUserVariables || {};
    }
  };
  globalThis.__robyneHttpSeq = 0;
  globalThis.__robyneHttpCallbacks = {};
  globalThis.__robyneTimeoutSeq = 0;
  globalThis.__robyneTimeoutCallbacks = {};

  globalThis.setTimeout = function(fnTimeout, timeout) {
    if (typeof fnTimeout !== 'function') {
      return undefined;
    }
    const timeoutId = ++globalThis.__robyneTimeoutSeq;
    globalThis.__robyneTimeoutCallbacks[timeoutId] = fnTimeout;
    sendMessage('robyneSetTimeout', JSON.stringify({
      id: timeoutId,
      timeout: Number(timeout) || 0
    }));
    return timeoutId;
  };

  globalThis.clearTimeout = function(timeoutId) {
    const id = Number(timeoutId) || 0;
    delete globalThis.__robyneTimeoutCallbacks[id];
    sendMessage('robyneClearTimeout', JSON.stringify({ id: id }));
  };

  globalThis.__robyneRunTimeout = function(timeoutId) {
    const callback = globalThis.__robyneTimeoutCallbacks[timeoutId];
    if (!callback) {
      return;
    }
    delete globalThis.__robyneTimeoutCallbacks[timeoutId];
    callback();
  };

  globalThis.__robyneClearAllTimeouts = function() {
    globalThis.__robyneTimeoutCallbacks = {};
  };

  function __robyneHttp(config) {
    return new Promise((resolve, reject) => {
      const id = ++globalThis.__robyneHttpSeq;
      globalThis.__robyneHttpCallbacks[id] = { resolve, reject };
      sendMessage('robyneHttp', JSON.stringify({
        id: id,
        config: config || {}
      }));
    });
  }

  globalThis.__robyneResolveHttp = function(id, envelope) {
    const callbacks = globalThis.__robyneHttpCallbacks[id];
    if (!callbacks) {
      return;
    }
    delete globalThis.__robyneHttpCallbacks[id];
    if (!envelope.ok) {
      callbacks.reject(new Error(envelope.error || 'Network request failed'));
      return;
    }
    callbacks.resolve(envelope.response);
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

  globalThis.__robyneNormalizePluginExport = function(exported) {
    if (exported && typeof exported === 'object' && !exported.platform && exported.default) {
      return exported.default;
    }
    return exported;
  };
''';
