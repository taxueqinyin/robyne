import 'package:logging/logging.dart';
import 'package:robyne/core/runtime/js_runtime.dart';

final _log = Logger('Axios');

/// Axios Bridge
///
/// 向 JS runtime 注入基于 XMLHttpRequest 的 axios shim。
///
/// 由于 flutter_js 内置了 XHR 支持（enableXhr），
/// 我们只需要注入一个 axios 兼容层，
/// 将 axios.get/post 等调用转为 XMLHttpRequest 调用。
///
/// 这比 sendMessage 方式更可靠，因为：
/// 1. XHR 回调由 flutter_js 的 Timer.periodic 轮询处理
/// 2. 不会和 evaluateAsync 产生死锁
/// 3. 完全兼容 MusicFree 插件的 axios 用法
class AxiosBridge {
  final JsRuntime _runtime;

  AxiosBridge(this._runtime);

  /// 注入 axios shim（基于 XMLHttpRequest）
  Future<void> inject() async {
    const shim = '''
(function() {
  // 基于 XMLHttpRequest 的 axios 兼容实现
  // 支持所有 MusicFree 插件的 axios 用法：
  // - axios.get(url, config)
  // - axios.post(url, data, config)
  // - axios(config) 直接调用
  // - axios.create() 返回自身
  // - axios.default 指向自身（兼容 ES module default export）

  var __axiosRequest = function(method, url, config) {
    config = config || {};
    return new Promise(function(resolve, reject) {
      try {
        var xhr = new XMLHttpRequest();
        var data = config.data;
        // 如果 data 是对象且不是字符串，序列化为 JSON
        if (data && typeof data !== 'string') {
          data = JSON.stringify(data);
        }
        xhr.open(method, url);

        // 设置请求头
        if (config.headers) {
          var headers = config.headers;
          if (headers.common) {
            for (var key in headers.common) {
              if (headers.common.hasOwnProperty(key)) {
                xhr.setRequestHeader(key, headers.common[key]);
              }
            }
          }
          for (var key in headers) {
            if (key !== 'common' && headers.hasOwnProperty(key)) {
              var val = headers[key];
              if (typeof val === 'object') continue;
              xhr.setRequestHeader(key, val);
            }
          }
        }
        // 默认 Content-Type
        if (data && !config.headers) {
          xhr.setRequestHeader('Content-Type', 'application/json');
        }

        xhr.onload = function() {
          var responseData = xhr.responseText;
          // 尝试解析 JSON
          try {
            responseData = JSON.parse(xhr.responseText);
          } catch(e) {}
          resolve({
            data: responseData,
            status: xhr.status,
            statusText: xhr.statusText,
            headers: {},
            config: config
          });
        };

        xhr.onerror = function() {
          reject(new Error('Network Error: ' + method + ' ' + url));
        };

        xhr.ontimeout = function() {
          reject(new Error('Timeout: ' + method + ' ' + url));
        };

        xhr.send(data || null);
      } catch(e) {
        reject(e);
      }
    });
  };

  // axios 函数对象 - 同时支持函数调用和对象属性访问
  var __axiosFn = function(configOrUrl, config) {
    if (typeof configOrUrl === 'string') {
      return __axiosRequest(
        (config && config.method ? config.method.toUpperCase() : 'GET'),
        configOrUrl,
        config
      );
    }
    return __axiosRequest(
      (configOrUrl && configOrUrl.method ? configOrUrl.method.toUpperCase() : 'GET'),
      configOrUrl && configOrUrl.url,
      configOrUrl
    );
  };

  // 挂载方法
  __axiosFn.request = function(config) {
    return __axiosRequest(
      (config && config.method ? config.method.toUpperCase() : 'GET'),
      config && config.url,
      config
    );
  };
  __axiosFn.get = function(url, config) {
    return __axiosRequest('GET', url, config);
  };
  __axiosFn.post = function(url, data, config) {
    var mergedConfig = Object.assign({}, config || {});
    mergedConfig.data = data;
    return __axiosRequest('POST', url, mergedConfig);
  };
  __axiosFn.put = function(url, data, config) {
    var mergedConfig = Object.assign({}, config || {});
    mergedConfig.data = data;
    return __axiosRequest('PUT', url, mergedConfig);
  };
  __axiosFn.delete = function(url, config) {
    return __axiosRequest('DELETE', url, config);
  };
  __axiosFn.head = function(url, config) {
    return __axiosRequest('HEAD', url, config);
  };
  __axiosFn.options = function(url, config) {
    return __axiosRequest('OPTIONS', url, config);
  };
  __axiosFn.patch = function(url, data, config) {
    var mergedConfig = Object.assign({}, config || {});
    mergedConfig.data = data;
    return __axiosRequest('PATCH', url, mergedConfig);
  };
  __axiosFn.create = function() {
    return __axiosFn;
  };
  __axiosFn.defaults = { headers: { common: {} } };
  __axiosFn.interceptors = { request: { use: function() {} }, response: { use: function() {} } };

  globalThis.__axios = __axiosFn;
  globalThis.__axios.default = __axiosFn;
  globalThis.axios = __axiosFn;
})();
''';

    _runtime.evaluate(shim);
    _log.info('Axios bridge (XHR-based) injected');
  }
}
