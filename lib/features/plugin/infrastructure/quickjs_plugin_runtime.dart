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
import '../domain/plugin_discovery_executor.dart';
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
  Future<String?>? _vendorSourceFuture;

  @override
  Future<PluginRuntime> create() async {
    final vendorSource = await _loadVendorSource();
    return QuickJsPluginRuntime(
      httpClient: _httpClient,
      vendorSource: vendorSource,
    );
  }

  @override
  Future<Result<Map<String, Object?>>> loadPluginMetadata(
    String source, {
    Map<String, String> userVariables = const <String, String>{},
  }) async {
    try {
      final vendorSource = await _loadVendorSource();
      final response = await QuickJsIsolatePluginSearchExecutor._runGuarded(
        debugName: 'robyne-plugin-load',
        body: () => _runQuickJsLoadInIsolate(<String, Object?>{
          'source': source,
          'userVariables': userVariables,
          'vendorSource': vendorSource,
        }),
      );
      if (response == null) {
        return Failure(
          AppError(
            code: 'plugin.load_failed',
            message: 'Failed to load JavaScript plugin.',
          ),
        );
      }
      if (response['ok'] == true) {
        return Ok(_objectMapValue(response['value']));
      }
      return Failure(
        AppError(
          code: response['code']?.toString() ?? 'plugin.load_failed',
          message:
              response['message']?.toString() ??
              'Failed to load JavaScript plugin.',
        ),
      );
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

  Future<String?> _loadVendorSource() {
    return _vendorSourceFuture ??= _loadVendorSourceUncached();
  }

  Future<String?> _loadVendorSourceUncached() async {
    try {
      return await rootBundle.loadString(_vendorAssetPath);
    } catch (_) {
      return null;
    }
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
      final response = await _runGuarded(
        debugName: 'robyne-plugin-search-${plugin.platform}',
        body: () => _runQuickJsSearchInIsolate(<String, Object?>{
          'source': source,
          'userVariables': plugin.userVariableValues,
          'keyword': keyword,
          'page': page,
          'searchType': searchType,
          'timeoutMs': pluginMethodTimeout.inMilliseconds,
          'vendorSource': vendorSource,
        }),
      );
      if (response == null) {
        return Failure(
          AppError(
            code: 'plugin.search_isolate_failed',
            message: 'Plugin ${plugin.platform} search did not finish in time.',
          ),
        );
      }
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

  /// Runs [body] on a worker isolate with a hard wall-clock ceiling.
  ///
  /// `Isolate.run` waits forever on the worker. A plugin that hangs — a
  /// request that never settles, a loop that never yields — therefore holds a
  /// Dart isolate open indefinitely, and the app appears frozen while those
  /// pile up. Bounding the wait means a wedged plugin costs one failed search
  /// instead of the session.
  ///
  /// Returns `null` when the ceiling is hit, since the isolate itself cannot
  /// be cancelled once started.
  static Future<Map<String, Object?>?> _runGuarded({
    required String debugName,
    required Future<Map<String, Object?>> Function() body,
  }) {
    return Isolate.run<Map<String, Object?>>(
      body,
      debugName: debugName,
    ).timeout(
      _isolateBudget,
      onTimeout: () => _runFailedResponse,
    ).then<Map<String, Object?>?>(
      (response) => identical(response, _runFailedResponse) ? null : response,
    );
  }

  /// Sentinel for "the isolate never answered", distinct from a real result.
  static const Map<String, Object?> _runFailedResponse = <String, Object?>{
    '_robyneRunFailed': true,
  };

  /// Generous but finite ceiling for one plugin call.
  ///
  /// Longer than [pluginMethodTimeout] because the isolate also has to boot
  /// QuickJS and evaluate the vendor bundle; if a plugin has not answered by
  /// now, it is not going to.
  static const Duration _isolateBudget = Duration(seconds: 100);

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

class QuickJsIsolatePluginDiscoveryExecutor implements PluginDiscoveryExecutor {
  QuickJsIsolatePluginDiscoveryExecutor({
    String vendorAssetPath = 'assets/js/musicfree_vendor.js',
    Future<String?> Function()? vendorSourceLoader,
  }) : _vendorAssetPath = vendorAssetPath,
       _vendorSourceLoader = vendorSourceLoader;

  final String _vendorAssetPath;
  final Future<String?> Function()? _vendorSourceLoader;
  Future<String?>? _vendorSourceFuture;

  @override
  Future<Result<Object?>> getTopLists({
    required PluginDefinition plugin,
    required String source,
  }) {
    return _invoke(
      plugin: plugin,
      source: source,
      method: 'getTopLists',
      arguments: const <Object?>[],
    );
  }

  @override
  Future<Result<Object?>> getTopListDetail({
    required PluginDefinition plugin,
    required String source,
    required Map<String, Object?> topList,
  }) {
    return _invoke(
      plugin: plugin,
      source: source,
      method: 'getTopListDetail',
      arguments: <Object?>[topList],
    );
  }

  @override
  Future<Result<Object?>> getRecommendSheetTags({
    required PluginDefinition plugin,
    required String source,
  }) {
    return _invoke(
      plugin: plugin,
      source: source,
      method: 'getRecommendSheetTags',
      arguments: const <Object?>[],
    );
  }

  @override
  Future<Result<Object?>> getRecommendSheetsByTag({
    required PluginDefinition plugin,
    required String source,
    required Map<String, Object?> tag,
    required int page,
  }) {
    return _invoke(
      plugin: plugin,
      source: source,
      method: 'getRecommendSheetsByTag',
      arguments: <Object?>[tag, page],
    );
  }

  @override
  Future<Result<Object?>> getMusicSheetInfo({
    required PluginDefinition plugin,
    required String source,
    required Map<String, Object?> sheetItem,
    required int page,
  }) {
    return _invoke(
      plugin: plugin,
      source: source,
      method: 'getMusicSheetInfo',
      arguments: <Object?>[sheetItem, page],
    );
  }

  Future<Result<Object?>> _invoke({
    required PluginDefinition plugin,
    required String source,
    required String method,
    required List<Object?> arguments,
  }) async {
    try {
      final vendorSource = await _loadVendorSource();
      final response = await QuickJsIsolatePluginSearchExecutor._runGuarded(
        debugName: 'robyne-plugin-discovery-$method-${plugin.platform}',
        body: () => _runQuickJsMethodInIsolate(<String, Object?>{
          'source': source,
          'userVariables': plugin.userVariableValues,
          'method': method,
          'arguments': arguments,
          'timeoutMs': pluginMethodTimeout.inMilliseconds,
          'vendorSource': vendorSource,
        }),
      );
      if (response == null) {
        return Failure(
          AppError(
            code: 'plugin.discovery_isolate_failed',
            message:
                'Plugin ${plugin.platform} $method did not finish in time.',
          ),
        );
      }
      if (response['ok'] == true) {
        return Ok(response['value']);
      }
      return Failure(
        AppError(
          code: response['code']?.toString() ?? 'plugin.discovery_failed',
          message:
              response['message']?.toString() ??
              'Plugin ${plugin.platform} $method failed.',
        ),
      );
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'plugin.discovery_isolate_failed',
          message:
              'Plugin ${plugin.platform} $method failed off the UI thread.',
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

/// Runs one plugin method on a worker isolate, for callers that need a method
/// the discovery executor does not name.
///
/// Playback (`getMediaSource`), lyrics and downloads each used to build a
/// `QuickJsPluginRuntime` directly, which put a native JS engine on the *main*
/// isolate: a plugin that blows the stack or the heap takes the whole process
/// down with no Dart error, because a native abort is not a Dart exception.
/// Search and discovery already ran off-thread; this is the same guarantee
/// for any other method, so every plugin call shares one boundary.
/// The contract playback, lyrics and downloads depend on.
///
/// An interface rather than a concrete class so tests can inject a fake: the
/// real one spawns isolates, which a unit test must not have to do.
abstract interface class PluginMethodRunner {
  Future<Result<Object?>> call({
    required PluginDefinition plugin,
    required String source,
    required String method,
    required List<Object?> arguments,
  });
}

class QuickJsIsolateMethodRunner implements PluginMethodRunner {
  QuickJsIsolateMethodRunner({
    String vendorAssetPath = 'assets/js/musicfree_vendor.js',
    Future<String?> Function()? vendorSourceLoader,
  }) : _vendorAssetPath = vendorAssetPath,
       _vendorSourceLoader = vendorSourceLoader;

  final String _vendorAssetPath;
  final Future<String?> Function()? _vendorSourceLoader;
  Future<String?>? _vendorSourceFuture;

  @override
  Future<Result<Object?>> call({
    required PluginDefinition plugin,
    required String source,
    required String method,
    required List<Object?> arguments,
  }) async {
    try {
      final vendorSource = await _loadVendorSource();
      final response = await QuickJsIsolatePluginSearchExecutor._runGuarded(
        debugName: 'robyne-plugin-$method-${plugin.platform}',
        body: () => _runQuickJsMethodInIsolate(<String, Object?>{
          'source': source,
          'userVariables': plugin.userVariableValues,
          'method': method,
          'arguments': arguments,
          'timeoutMs': pluginMethodTimeout.inMilliseconds,
          'vendorSource': vendorSource,
        }),
      );
      if (response == null) {
        return Failure(
          AppError(
            code: 'plugin.method_isolate_failed',
            message:
                'Plugin ${plugin.platform} $method did not finish in time.',
          ),
        );
      }
      if (response['ok'] == true) {
        return Ok(response['value']);
      }
      return Failure(
        AppError(
          code: response['code']?.toString() ?? 'plugin.method_failed',
          message:
              response['message']?.toString() ??
              'Plugin ${plugin.platform} $method failed.',
        ),
      );
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'plugin.method_isolate_failed',
          message: 'Plugin ${plugin.platform} $method failed off the UI thread.',
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

Future<Map<String, Object?>> _runQuickJsLoadInIsolate(
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
    return switch (loaded) {
      Ok<Map<String, Object?>>(:final value) => <String, Object?>{
        'ok': true,
        'value': value,
      },
      Failure<Map<String, Object?>>(:final error) => _isolateFailure(error),
    };
  } catch (error) {
    return <String, Object?>{
      'ok': false,
      'code': 'plugin.load_failed',
      'message': error.toString(),
    };
  } finally {
    await runtime.dispose();
  }
}

Future<Map<String, Object?>> _runQuickJsMethodInIsolate(
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
      request['method']?.toString() ?? '',
      _listValue(request['arguments']),
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
      'code': 'plugin.runtime_error',
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

Map<String, Object?> _objectMapValue(Object? value) {
  if (value is! Map) {
    return const <String, Object?>{};
  }
  return value.map(
    (key, dynamic mapValue) => MapEntry(key.toString(), mapValue as Object?),
  );
}

List<Object?> _listValue(Object? value) {
  if (value is List) {
    return value.cast<Object?>();
  }
  return const <Object?>[];
}

class QuickJsPluginRuntime implements PluginRuntime {
  QuickJsPluginRuntime({
    required PluginHttpClient httpClient,
    String? vendorSource,
  }) : _httpClient = httpClient {
    // A wider QuickJS recursion guard than the 1MB default: deep-but-legitimate
    // plugin recursion needs headroom, while a runaway should trip this (a
    // catchable JS RangeError) before it reaches the real thread stack and
    // aborts the process.
    //
    // `memoryLimit` is deliberately NOT set: this build's native bridge does
    // not export `jsSetMemoryLimit`, and asking for it throws a symbol
    // lookup failure inside the isolate. Setting it here would break every
    // plugin call, so the heap stays bounded only by the isolate's own death.
    _runtime = getJavascriptRuntime(
      xhr: false,
      extraArgs: <String, Object?>{'stackSize': _stackLimitBytes},
    );
    _runtime.onMessage('robyneHttp', _trackHttpRequest);
    _runtime.onMessage('robyneSetTimeout', _scheduleTimeout);
    _runtime.onMessage('robyneClearTimeout', _clearTimeout);
    _runtime.evaluate(_bootstrapScript);
    if (vendorSource != null && vendorSource.trim().isNotEmpty) {
      _runtime.evaluate(vendorSource);
    }
  }

  /// QuickJS's own recursion guard: 768KB, deliberately under the host
  /// thread's real stack.
  ///
  /// This guard is only meaningful if it trips *first*. Windows gives a
  /// thread a 1MB stack by default, and the Dart VM's worker-isolate threads
  /// are of the same order, so a guard at or above 1MB never fires — runaway
  /// plugin recursion walks straight past QuickJS's check and smashes the
  /// real thread stack. That is exactly the "Run-Time Check Failure #2 -
  /// Stack around the variable was corrupted" abort from
  /// quickjs_c_bridge_plugin.dll, and why an earlier 4MB value made the
  /// crash worse.
  ///
  /// The value is a compromise, measured against the bundled fixtures rather
  /// than guessed: 256KB and 512KB were both too tight — real plugins
  /// (快手's request serialisation, 网易云's MiniSearch index build) tripped
  /// the guard during ordinary work. At 768KB every fixture searches
  /// successfully, while unbounded recursion is still caught as a JS
  /// RangeError instead of a dead process. The margin to 1MB is what keeps
  /// the guard ahead of the OS stack.
  static const int _stackLimitBytes = 768 * 1024;

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
            userVariables: exported.userVariables || [],
            exportedMethods: Object.keys(exported).filter(
              (key) => typeof exported[key] === 'function'
            )
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
      // The wrapper resolves to a *result envelope* instead of throwing.
      //
      // An `async` function that throws hands back a rejected Promise, which
      // this bridge can only unwrap by rethrowing the JS error into Dart —
      // and an unhandled rejection there aborts the whole isolate, which is
      // how one plugin missing `getTopLists` took the app down. Catching
      // inside JS and returning a discriminated envelope means every failure
      // path comes back as a normal rejected *Dart* value instead.
      final result = _runtime.evaluate('''
        (async () => {
          try {
            const method = globalThis.__robynePlugin[$encodedMethod];
            if (typeof method !== 'function') {
              return JSON.stringify({
                __robyneError: true,
                code: 'plugin.method_not_found',
                message: 'Plugin method not found: ' + $encodedMethod
              });
            }
            const value = await method(...$encodedArgs);
            return JSON.stringify({
              __robyneOk: true,
              value: value === undefined ? null : value
            });
          } catch (error) {
            return JSON.stringify({
              __robyneError: true,
              code: 'plugin.runtime_error',
              message: (error && error.message)
                ? String(error.message)
                : String(error)
            });
          }
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
      final envelope = _decodeEnvelope(resolved.stringResult);
      if (envelope case Failure<Object?>(:final error)) {
        return Failure(error);
      }
      return Ok((envelope as Ok<Object?>).value);
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

  /// Reads the envelope [callMethod]'s wrapper produces.
  ///
  /// A plugin may legitimately return bare JSON that is not an envelope —
  /// only the marker fields are trusted, so an object that happens to carry
  /// `__robyneError` is the sole signal of failure.
  Result<Object?> _decodeEnvelope(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      // A plugin that returns a bare string (not JSON-encoded) still has a
      // usable value; treat it as-is rather than failing the whole call.
      return Ok(raw as Object?);
    }
    if (decoded is Map && decoded['__robyneError'] == true) {
      return Failure(
        AppError(
          code: decoded['code']?.toString() ?? 'plugin.runtime_error',
          message:
              decoded['message']?.toString() ??
              'Plugin method call failed without a message.',
        ),
      );
    }
    if (decoded is Map && decoded['__robyneOk'] == true) {
      return Ok(decoded['value'] as Object?);
    }
    return Ok(decoded);
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
