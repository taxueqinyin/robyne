import '../../../core/result/result.dart';

abstract interface class PluginRuntime {
  Future<Result<Map<String, Object?>>> loadPlugin(
    String source, {
    Map<String, String> userVariables,
  });

  Future<Result<Object?>> callMethod(
    String method,
    List<Object?> arguments, {
    Duration timeout,
  });

  Future<void> dispose();
}

abstract class PluginRuntimeFactory {
  Future<PluginRuntime> create();

  Future<Result<Map<String, Object?>>> loadPluginMetadata(
    String source, {
    Map<String, String> userVariables = const <String, String>{},
  }) async {
    final runtime = await create();
    try {
      return await runtime.loadPlugin(source, userVariables: userVariables);
    } finally {
      await runtime.dispose();
    }
  }
}
