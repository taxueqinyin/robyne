import 'dart:convert';

import 'package:robyne/core/runtime/js_runtime.dart';
import 'package:robyne/core/plugin/plugin_models.dart';
import 'package:robyne/core/plugin/plugin_protocol.dart';
import 'package:robyne/core/plugin/plugin_registry.dart';
import 'package:robyne/core/plugin/adapters/musicfree_adapter.dart';
import 'package:robyne/core/runtime/commonjs_loader.dart';
import 'package:robyne/core/runtime/runtime_exceptions.dart';
import 'package:logging/logging.dart';

final _log = Logger('PluginExecutor');

/// 插件执行器 - 负责加载和卸载 MusicFree 插件
///
/// 加载流程：
/// 1. 将 JS 源码包装为 CommonJS 模块并执行
/// 2. 从 module.exports 提取元信息（platform 作为 id）
/// 3. 创建 MusicFreeAdapter 包装已加载模块
/// 4. 注册到 PluginRegistry
class PluginExecutor {
  final JsRuntime _runtime;
  final PluginRegistry _registry;

  PluginExecutor({
    required JsRuntime runtime,
    required PluginRegistry registry,
  })  : _runtime = runtime,
        _registry = registry;

  /// 从 JS 源码加载插件
  ///
  /// [sourceCode] MusicFree 插件 JS 源码
  /// [sourcePath] 插件来源路径（用于标识和调试）
  Future<MusicSourcePlugin> loadPlugin(
    String sourceCode,
    String sourcePath,
  ) async {
    _log.info('Loading plugin from: $sourcePath');

    try {
      // 1. 包装为自执行函数，将 module.exports 挂到全局临时变量
      // MusicFree 插件格式：module.exports = { platform: "xxx", search: fn, ... }
      // 没有 meta 子对象，元信息直接在 exports 上
      // 优先使用 bundle 的 require（如果存在），否则回退到白名单映射
      final requireBranches = CommonJsLoader.moduleGlobalMap.entries.map((e) {
        return "    case '${e.key}': return typeof ${e.value} !== 'undefined' ? ${e.value} : undefined;";
      }).join('\n');

      final wrapperScript = '''
(function() {
  var module = { exports: {} };
  var exports = module.exports;
  // 优先使用 bundle 的 require，否则回退到白名单映射
  var __bundleRequire = typeof require !== 'undefined' ? require : null;
  var require = function(name) {
    // 先尝试 bundle require
    if (__bundleRequire) {
      try {
        var mod = __bundleRequire(name);
        if (mod !== undefined) return mod;
      } catch(e) {}
    }
    // 回退到白名单映射
    switch (name) {
$requireBranches
      default:
        throw new Error("Unsupported module: " + name);
    }
  };
  $sourceCode
  globalThis.__plugin_loading = module.exports;
  // 提取元信息：platform 作为 id，name 用 platform，version 用 version 字段
  var meta = {
    id: module.exports.platform || '',
    name: module.exports.platform || '',
    version: module.exports.version || '0.0.0',
    apiVersion: 1
  };
  return JSON.stringify(meta);
})();
''';

      final metaResult = _runtime.evaluate(
        wrapperScript,
        pluginId: '<loading>',
        method: 'loadPlugin',
      );

      // 2. 解析 meta 信息
      final metaJson = _parseMetaResult(metaResult);
      final meta = PluginMeta.fromJson(metaJson);

      if (meta.id.isEmpty) {
        throw PluginLoadError(
          message: 'Plugin platform (id) is empty, source: $sourcePath',
        );
      }

      _log.info('Plugin meta parsed: ${meta.name} (${meta.id}) v${meta.version}');

      // 3. 将完整模块挂载到全局命名空间，供后续方法调用
      final safeId = _safeIdentifier(meta.id);
      final mountScript = '''
(function() {
  var module = { exports: {} };
  var exports = module.exports;
  var __bundleRequire = typeof require !== 'undefined' ? require : null;
  var require = function(name) {
    if (__bundleRequire) {
      try {
        var mod = __bundleRequire(name);
        if (mod !== undefined) return mod;
      } catch(e) {}
    }
    switch (name) {
$requireBranches
      default:
        throw new Error("Unsupported module: " + name);
    }
  };
  $sourceCode
  globalThis.__plugin_$safeId = module.exports;
  delete globalThis.__plugin_loading;
})();
''';
      _runtime.evaluate(
        mountScript,
        pluginId: meta.id,
        method: 'mountPlugin',
      );

      // 4. 创建适配器并注册
      final adapter = MusicFreeAdapter(
        meta: meta,
        runtime: _runtime,
        sourcePath: sourcePath,
      );

      _registry.register(adapter);
      _log.info('Plugin loaded and registered: ${meta.name} (${meta.id})');

      return adapter;
    } on PluginLoadError {
      rethrow;
    } on PluginExecutionError {
      rethrow;
    } catch (e) {
      _log.severe('Failed to load plugin from $sourcePath: $e');
      throw PluginLoadError(
        message: 'Failed to load plugin: $e',
        pluginId: null,
      );
    }
  }

  /// 卸载插件
  Future<void> unloadPlugin(String pluginId) async {
    _log.info('Unloading plugin: $pluginId');

    final safeId = _safeIdentifier(pluginId);

    // 清理全局命名空间
    try {
      _runtime.evaluate(
        'delete globalThis.__plugin_$safeId;',
        pluginId: pluginId,
        method: 'unloadPlugin',
      );
    } catch (e) {
      _log.warning('Failed to cleanup global namespace for plugin $pluginId: $e');
    }

    _registry.unregister(pluginId);
    _log.info('Plugin unloaded: $pluginId');
  }

  /// 解析 meta 结果为 Map
  Map<String, dynamic> _parseMetaResult(dynamic result) {
    if (result == null) {
      return {};
    }

    String rawString;
    if (result is String) {
      rawString = result;
    } else {
      try {
        rawString = result.stringResult ?? result.toString();
      } catch (_) {
        rawString = result.toString();
      }
    }

    if (rawString.isEmpty || rawString == 'undefined') {
      return {};
    }

    try {
      return jsonDecode(rawString) as Map<String, dynamic>;
    } catch (e) {
      _log.warning('Failed to parse plugin meta JSON: $e, raw: $rawString');
      return {};
    }
  }

  /// 将 pluginId 转为合法的 JS 标识符
  String _safeIdentifier(String pluginId) {
    return pluginId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }
}
