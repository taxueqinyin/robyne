import 'package:robyne/core/runtime/js_runtime.dart';
import 'package:robyne/core/runtime/runtime_exceptions.dart';

/// CommonJS 加载器
///
/// 将插件 JS 代码包装在 CommonJS shim 中执行，
/// 仅支持 module.exports / exports / require()，
/// require 白名单：axios、cheerio、crypto-js、he。
class CommonJsLoader {
  final JsRuntime _runtime;

  /// 允许的 require 模块白名单
  static const _allowedModules = {'axios', 'cheerio', 'crypto-js', 'he', 'dayjs'};

  /// 白名单模块名 → 全局注入对象名的映射
  static const moduleGlobalMap = {
    'axios': '__axios',
    'cheerio': '__cheerio',
    'crypto-js': '__cryptoJs',
    'he': '__he',
    'dayjs': '__dayjs',
  };

  /// 匹配 require('xxx') 或 require("xxx") 的正则
  static final _requirePattern = RegExp(r'''require\s*\(\s*['"]([^'"]+)['"]\s*\)''');

  CommonJsLoader(this._runtime);

  /// 将插件代码包装在 CommonJS shim 中并执行
  ///
  /// [sourceCode] 插件原始 JS 源码
  /// [pluginId] 插件标识，用于隔离模块存储
  Future<dynamic> loadModule(String sourceCode, {String? pluginId}) async {
    // 1. 校验源码中的 require 调用
    _validateRequires(sourceCode);

    // 2. 构造安全的模块存储变量名
    final safeId = _safeIdentifier(pluginId);

    // 3. 构造 require 分支逻辑
    final requireBranches = moduleGlobalMap.entries.map((e) {
      return "    case '${e.key}': return typeof ${e.value} !== 'undefined' ? ${e.value} : undefined;";
    }).join('\n');

    // 4. 包装 CommonJS shim，将 module.exports 存入全局变量以便后续读取
    final wrappedCode = '''
(function() {
  var module = { exports: {} };
  var exports = module.exports;
  var require = function(name) {
    switch (name) {
$requireBranches
      default:
        throw new Error("Unsupported module: " + name);
    }
  };
  // --- plugin source ---
  $sourceCode
  // --- end plugin source ---
  globalThis.__modules_$safeId = module.exports;
  return module.exports;
})();
''';

    // 5. 通过 JsRuntime 执行
    return _runtime.evaluateAsync(
      wrappedCode,
      pluginId: pluginId,
      method: 'loadModule',
    );
  }

  /// 校验源码中所有 require() 调用是否都在白名单内
  void _validateRequires(String sourceCode) {
    final matches = _requirePattern.allMatches(sourceCode);
    for (final match in matches) {
      final moduleName = match.group(1);
      if (moduleName != null && !_allowedModules.contains(moduleName)) {
        throw UnsupportedModuleError(moduleName);
      }
    }
  }

  /// 执行后获取 module.exports 的 JSON 表示
  dynamic getModuleExports(String pluginId) {
    final safeId = _safeIdentifier(pluginId);
    return _runtime.evaluate(
      'JSON.stringify(__modules_$safeId !== undefined ? __modules_$safeId : null)',
      pluginId: pluginId,
      method: 'getModuleExports',
    );
  }

  /// 将 pluginId 转为合法的 JS 标识符
  String _safeIdentifier(String? pluginId) {
    if (pluginId == null || pluginId.isEmpty) return 'default';
    return pluginId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }
}
