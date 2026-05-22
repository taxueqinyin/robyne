/// Runtime 异常
class RuntimeException implements Exception {
  final String message;
  final String? pluginId;
  final String? method;
  final String? stackTrace;

  RuntimeException({
    required this.message,
    this.pluginId,
    this.method,
    this.stackTrace,
  });

  @override
  String toString() =>
      'RuntimeException: $message${pluginId != null ? ' (plugin=$pluginId)' : ''}${method != null ? ' method=$method' : ''}';
}

/// 不支持的模块异常
class UnsupportedModuleError extends RuntimeException {
  final String moduleName;

  UnsupportedModuleError(this.moduleName)
      : super(message: 'Unsupported module: $moduleName');
}

/// 插件执行异常
class PluginExecutionError extends RuntimeException {
  PluginExecutionError({
    required super.message,
    super.pluginId,
    super.method,
    super.stackTrace,
  });
}

/// 插件加载异常
class PluginLoadError extends RuntimeException {
  PluginLoadError({
    required super.message,
    super.pluginId,
  });
}

/// 超时异常
class RuntimeTimeoutError extends RuntimeException {
  final Duration timeout;

  RuntimeTimeoutError({
    required this.timeout,
    super.pluginId,
    super.method,
  }) : super(message: 'Execution timed out after ${timeout.inMilliseconds}ms');
}
