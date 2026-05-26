import '../../../core/result/result.dart';

abstract interface class PluginRuntime {
  Future<Result<Map<String, Object?>>> loadPlugin(String source);

  Future<Result<Object?>> callMethod(
    String method,
    List<Object?> arguments, {
    Duration timeout,
  });

  Future<void> dispose();
}

abstract interface class PluginRuntimeFactory {
  Future<PluginRuntime> create();
}
