import 'package:flutter/services.dart';
import 'package:robyne/core/runtime/js_runtime.dart';
import 'package:robyne/core/runtime/commonjs_loader.dart';
import 'package:robyne/core/network/axios_bridge.dart';
import 'package:logging/logging.dart';

class RuntimeBridge {
  final JsRuntime _runtime;
  late final CommonJsLoader _loader;
  late final AxiosBridge _axiosBridge;
  bool _initialized = false;

  final _log = Logger('RuntimeBridge');

  RuntimeBridge(this._runtime);

  JsRuntime get runtime => _runtime;
  CommonJsLoader get loader => _loader;
  AxiosBridge get axiosBridge => _axiosBridge;

  Future<void> init() async {
    if (_initialized) return;
    _log.info('Initializing RuntimeBridge...');
    await _runtime.init();
    _loader = CommonJsLoader(_runtime);
    _axiosBridge = AxiosBridge(_runtime);
    await _axiosBridge.inject();

    // 注入内置 JS 库到全局命名空间
    await _injectBuiltinLibraries();

    // 注入 MusicFree 运行时环境 stub
    _injectMusicFreeEnv();

    _initialized = true;
    _log.info('RuntimeBridge initialized');
  }

  /// 注入内置 JS 库（crypto-js, cheerio, he, dayjs）
  /// 使用 browserify 打包的 bundle.js
  Future<void> _injectBuiltinLibraries() async {
    try {
      // 1. 加载 browserify bundle - 它会设置全局 require 函数
      final bundleSource = await rootBundle.loadString('assets/js/bundle.js');
      _runtime.evaluate(bundleSource, method: 'inject_bundle');
      _log.info('Loaded browserify bundle');

      // 2. 用 bundle 的 require 获取各模块并挂载到全局变量
      final setupScript = '''
(function() {
  // bundle.js 设置了全局 require
  if (typeof require === 'undefined') {
    throw new Error('bundle require not found');
  }
  globalThis.__cryptoJs = require('crypto-js');
  globalThis.__cheerio = require('cheerio');
  globalThis.__he = require('he');
  globalThis.__dayjs = require('dayjs');
})();
''';
      _runtime.evaluate(setupScript, method: 'inject_setup_libs');
      _log.info('Injected all library globals');
    } catch (e) {
      _log.severe('Failed to inject builtin libraries: $e');
      // 回退到 stub
      await _injectStubLibraries();
    }
  }

  /// 回退方案：注入 stub 库
  Future<void> _injectStubLibraries() async {
    final libraries = {
      'cheerio': 'assets/js/cheerio.js',
      'crypto-js': 'assets/js/crypto-js.js',
      'he': 'assets/js/he.js',
      'dayjs': 'assets/js/dayjs.js',
    };

    for (final entry in libraries.entries) {
      try {
        final source = await rootBundle.loadString(entry.value);
        _runtime.evaluate(source, method: 'inject_${entry.key}');
        _log.info('Injected stub library: ${entry.key}');
      } catch (e) {
        _log.warning('Failed to inject stub library ${entry.key}: $e');
      }
    }
  }

  /// 注入 MusicFree 运行时环境 stub
  /// 提供 env.getUserVariables() 等接口
  void _injectMusicFreeEnv() {
    const envScript = '''
(function() {
  globalThis.env = {
    getUserVariables: function() {
      return {};
    }
  };
})();
''';
    _runtime.evaluate(envScript, method: 'inject_env');
    _log.info('Injected MusicFree env stub');
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    _log.info('Disposing RuntimeBridge...');
    await _runtime.dispose();
    _initialized = false;
    _log.info('RuntimeBridge disposed');
  }
}
