import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:robyne/core/js_sandbox/axios_bridge.dart';
import 'package:robyne/core/js_sandbox/commonjs_runtime.dart';
import 'package:robyne/core/js_sandbox/security.dart';

part 'sandbox_manager.g.dart';

@Riverpod(keepAlive: true)
class SandboxManager extends _$SandboxManager {
  JavascriptRuntime? _runtime;
  final AxiosBridge _axiosBridge = AxiosBridge();
  final CommonJsRuntime _commonJs = CommonJsRuntime();
  final SandboxSecurityConfig _config = const SandboxSecurityConfig();
  final Map<String, Completer<String>> _pendingRequests = {};
  bool _initialized = false;

  @override
  SandboxState build() {
    ref.onDispose(() {
      _runtime = null;
    });

    return SandboxState.initial();
  }

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      state = state.copyWith(isLoading: true);

      _runtime = getJavascriptRuntime();

      await _injectBuiltinModules();
      _injectCommonJs();
      _injectAxios();
      _setupMessageHandler();

      _initialized = true;
      state = state.copyWith(isLoading: false, isReady: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to initialize sandbox: $e',
      );
    }
  }

  Future<void> _injectBuiltinModules() async {
    final cheerioCode = await rootBundle.loadString('assets/js/cheerio.min.js');
    final heCode = await rootBundle.loadString('assets/js/he.min.js');
    final cryptoJsCode = await rootBundle.loadString('assets/js/crypto-js.min.js');

    _commonJs.registerModule('cheerio', cheerioCode);
    _commonJs.registerModule('he', heCode);
    _commonJs.registerModule('crypto-js', cryptoJsCode);
  }

  void _injectCommonJs() {
    final requireJs = _commonJs.generateRequireJs();
    _runtime!.evaluate(requireJs);
  }

  void _injectAxios() {
    final axiosJs = _axiosBridge.generateAxiosJs();
    _runtime!.evaluate(axiosJs);
    // Initialize plugins object
    _runtime!.evaluate('var plugins = {};');
  }

  void _setupMessageHandler() {
    // Setup message channel for axios bridge
    _runtime!.onMessage('flutter_js_bridge', (message) async {
      try {
        final request = AxiosRequest.fromJson(
          jsonDecode(message as String) as Map<String, dynamic>,
        );
        final response = await _axiosBridge.request(request);
        return jsonEncode(response.toJson());
      } catch (e) {
        return jsonEncode({'error': e.toString()});
      }
    });
  }

  Future<dynamic> executeJs(String code, {String? pluginName}) async {
    if (!_initialized || _runtime == null) {
      throw SandboxException('Sandbox not initialized');
    }

    try {
      final result = await _runtime!.evaluate(
        code,
      );

      if (result.isError) {
        throw SandboxException(
          result.stringResult,
          pluginName: pluginName,
        );
      }

      return result.stringResult;
    } catch (e) {
      if (e is SandboxException) rethrow;
      throw SandboxException(e.toString(), pluginName: pluginName);
    }
  }

  Future<dynamic> callFunction(
    String functionName,
    List<dynamic> args, {
    String? pluginName,
  }) async {
    final argsJson = jsonEncode(args);
    final code = '$functionName(...$argsJson)';
    return executeJs(code, pluginName: pluginName);
  }

  Future<void> loadPlugin(String pluginCode, String pluginName) async {
    final wrappedCode = '''
      (function() {
        const pluginModule = { exports: {} };
        const pluginExports = pluginModule.exports;
        (function(module, exports) {
          $pluginCode
        })(pluginModule, pluginExports);
        return pluginModule.exports;
      })()
    ''';

    final result = await executeJs(wrappedCode, pluginName: pluginName);

    await executeJs('''
      var plugins = plugins || {};
      plugins['$pluginName'] = $result;
    ''', pluginName: pluginName);

    state = state.copyWith(
      loadedPlugins: [...state.loadedPlugins, pluginName],
    );
  }

  Future<dynamic> callPluginMethod(
    String pluginName,
    String method,
    List<dynamic> args,
  ) async {
    final argsJson = jsonEncode(args);
    final code = "plugins['$pluginName'].$method(...$argsJson)";
    return executeJs(code, pluginName: pluginName);
  }

  void unloadPlugin(String pluginName) {
    executeJs("delete plugins['$pluginName'];");
    state = state.copyWith(
      loadedPlugins:
          state.loadedPlugins.where((p) => p != pluginName).toList(),
    );
  }

  Future<void> dispose() async {
    _runtime?.dispose();
    _runtime = null;
    _initialized = false;
  }
}

class SandboxState {
  final bool isLoading;
  final bool isReady;
  final String? error;
  final List<String> loadedPlugins;

  const SandboxState({
    this.isLoading = false,
    this.isReady = false,
    this.error,
    this.loadedPlugins = const [],
  });

  SandboxState copyWith({
    bool? isLoading,
    bool? isReady,
    String? error,
    List<String>? loadedPlugins,
  }) {
    return SandboxState(
      isLoading: isLoading ?? this.isLoading,
      isReady: isReady ?? this.isReady,
      error: error,
      loadedPlugins: loadedPlugins ?? this.loadedPlugins,
    );
  }

  factory SandboxState.initial() => const SandboxState();
}
