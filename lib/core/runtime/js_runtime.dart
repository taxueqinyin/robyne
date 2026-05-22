import 'dart:async';

import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_js/extensions/xhr.dart';
import 'package:flutter_js/extensions/fetch.dart';
import 'package:logging/logging.dart';
import 'package:robyne/core/runtime/runtime_exceptions.dart';

final _log = Logger('Runtime');

/// 插件运行时抽象接口，便于未来替换实现
abstract class PluginRuntime {
  Future<void> init();

  dynamic evaluate(String script, {String? pluginId, String? method});

  Future<dynamic> evaluateAsync(
    String script, {
    String? pluginId,
    String? method,
    Duration? timeout,
  });

  /// 执行 QuickJS 待处理的 Promise/async 回调
  /// 必须在每次 evaluate 后调用，否则 Promise.then 不会执行
  int executePendingJob();

  Future<void> dispose();
}

/// 基于 flutter_js 的 JS 运行时实现
///
/// 关键发现：flutter_js 的 QuickJS 运行时中，
/// `evaluateAsync` 只是 `Future.value(evaluate(code))` 的包装，
/// 不会真正等待 JS Promise。
///
/// Promise 的回调需要通过 `executePendingJob()` 来驱动。
/// XHR 的回调通过 `sendMessage` → Dart `evaluate()` 触发，
/// 但 Promise.then 的执行需要额外调用 `executePendingJob()`。
class JsRuntime implements PluginRuntime {
  JavascriptRuntime? _runtime;
  bool _initialized = false;

  /// 定时器：定期执行 QuickJS pending jobs
  Timer? _pendingJobTimer;

  @override
  Future<void> init() async {
    if (_initialized) return;
    _runtime = getJavascriptRuntime();

    // 启用 flutter_js 内置的 XHR 和 Fetch 支持
    _runtime!.enableXhr();
    await _runtime!.enableFetch();

    // 启动定时器，定期执行 QuickJS pending jobs
    // 这是 Promise 回调能执行的关键！
    _pendingJobTimer = Timer.periodic(
      const Duration(milliseconds: 10),
      (_) => _drainPendingJobs(),
    );

    _initialized = true;
    _log.info('JS Runtime initialized with XHR + Fetch + pendingJob timer');
  }

  /// 排空所有待处理的 QuickJS jobs
  void _drainPendingJobs() {
    if (_runtime == null) return;
    var count = 0;
    while (_runtime!.executePendingJob() != 0) {
      count++;
      if (count > 100) break; // 防止无限循环
    }
    if (count > 0 && count > 5) {
      _log.fine('Drained $count pending jobs');
    }
  }

  void _ensureInitialized() {
    if (!_initialized || _runtime == null) {
      throw StateError('JsRuntime has not been initialized. Call init() first.');
    }
  }

  @override
  dynamic evaluate(String script, {String? pluginId, String? method}) {
    _ensureInitialized();
    final stopwatch = Stopwatch()..start();
    try {
      final result = _runtime!.evaluate(script);
      // 每次 evaluate 后立即执行 pending jobs
      _drainPendingJobs();
      stopwatch.stop();
      _log.info(
        '[Runtime] plugin=${pluginId ?? "unknown"} '
        'method=${method ?? "unknown"} '
        'duration=${stopwatch.elapsedMilliseconds}ms',
      );
      return result;
    } catch (e, st) {
      stopwatch.stop();
      _log.warning(
        '[Runtime] plugin=${pluginId ?? "unknown"} '
        'method=${method ?? "unknown"} '
        'duration=${stopwatch.elapsedMilliseconds}ms '
        'error=$e',
      );
      throw PluginExecutionError(
        message: e.toString(),
        pluginId: pluginId,
        method: method,
        stackTrace: st.toString(),
      );
    }
  }

  @override
  Future<dynamic> evaluateAsync(
    String script, {
    String? pluginId,
    String? method,
    Duration? timeout,
  }) async {
    _ensureInitialized();
    final stopwatch = Stopwatch()..start();

    try {
      // flutter_js 的 evaluateAsync 只是同步 evaluate 的包装
      // 我们需要手动执行 pending jobs 并轮询等待 Promise 完成
      final result = _runtime!.evaluate(script);
      _drainPendingJobs();
      stopwatch.stop();
      _log.info(
        '[Runtime] plugin=${pluginId ?? "unknown"} '
        'method=${method ?? "unknown"} '
        'duration=${stopwatch.elapsedMilliseconds}ms',
      );
      return result;
    } on PluginExecutionError {
      rethrow;
    } catch (e, st) {
      stopwatch.stop();
      _log.warning(
        '[Runtime] plugin=${pluginId ?? "unknown"} '
        'method=${method ?? "unknown"} '
        'duration=${stopwatch.elapsedMilliseconds}ms '
        'error=$e',
      );
      throw PluginExecutionError(
        message: e.toString(),
        pluginId: pluginId,
        method: method,
        stackTrace: st.toString(),
      );
    }
  }

  @override
  int executePendingJob() {
    if (_runtime == null) return 0;
    return _runtime!.executePendingJob();
  }

  /// 获取底层 JavascriptRuntime 实例
  JavascriptRuntime get innerRuntime {
    _ensureInitialized();
    return _runtime!;
  }

  @override
  Future<void> dispose() async {
    _pendingJobTimer?.cancel();
    _pendingJobTimer = null;
    _runtime = null;
    _initialized = false;
    _log.info('JS Runtime disposed');
  }
}
