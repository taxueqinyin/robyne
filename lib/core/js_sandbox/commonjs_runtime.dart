import 'package:flutter/services.dart';

class CommonJsRuntime {
  final Map<String, String> _modules = {};

  void registerModule(String name, String code) {
    _modules[name] = code;
  }

  String generateRequireJs() {
    // Build modules object as JSON-like string
    final moduleEntries = _modules.entries.map((e) {
      // Store module code as a function string to avoid escaping issues
      return "'${_escapeJs(e.key)}': ${_wrapModuleCode(e.value)}";
    }).join(',\n');

    return '''
      // CommonJS Module System
      var _moduleCache = {};
      var _modules = {
        $moduleEntries
      };

      function require(name) {
        if (_moduleCache[name]) {
          return _moduleCache[name].exports;
        }

        var module = { exports: {} };
        var exports = module.exports;

        if (name === 'axios') {
          return axios;
        }

        if (_modules[name]) {
          var fn = _modules[name];
          fn(module, exports);
          _moduleCache[name] = module;
          return module.exports;
        }

        throw new Error('Module not found: ' + name);
      }

      // Make require global
      if (typeof globalThis !== 'undefined') {
        globalThis.require = require;
      }
      if (typeof window !== 'undefined') {
        window.require = require;
      }
    ''';
  }

  String _wrapModuleCode(String code) {
    // Wrap module code in a function to avoid variable conflicts
    // and handle escaping properly
    final escapedCode = code
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');

    return "function(module, exports) { eval('$escapedCode'); }";
  }

  String _escapeJs(String str) {
    return str
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');
  }

  Future<String> loadAsset(String assetPath) async {
    return await rootBundle.loadString(assetPath);
  }
}
