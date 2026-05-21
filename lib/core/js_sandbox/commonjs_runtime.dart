import 'package:flutter/services.dart';

class CommonJsRuntime {
  final Map<String, String> _modules = {};
  final Map<String, dynamic> _moduleCache = {};

  void registerModule(String name, String code) {
    _modules[name] = code;
  }

  String generateRequireJs() {
    final buffer = StringBuffer();
    buffer.writeln('const module = { exports: {} };');
    buffer.writeln('const exports = module.exports;');

    buffer.writeln('''
      const _moduleCache = {};
      function require(name) {
        if (_moduleCache[name]) {
          return _moduleCache[name].exports;
        }

        const module = { exports: {} };
        const exports = module.exports;

        const modules = ${_generateModulesMap()};
        if (modules[name]) {
          const fn = new Function('module', 'exports', modules[name]);
          fn(module, exports);
          _moduleCache[name] = module;
          return module.exports;
        }

        if (name === 'axios') {
          return axios;
        }

        throw new Error('Module not found: ' + name);
      }
    ''');

    return buffer.toString();
  }

  String _generateModulesMap() {
    final entries = _modules.entries
        .map((e) => "'${e.key}': ${_escapeJs(e.value)}")
        .join(', ');
    return '{ $entries }';
  }

  String _escapeJs(String code) {
    return code
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');
  }

  Future<String> loadAsset(String assetPath) async {
    return await rootBundle.loadString(assetPath);
  }

  void registerBuiltinModules() {
    // These will be loaded from assets at initialization
  }
}
