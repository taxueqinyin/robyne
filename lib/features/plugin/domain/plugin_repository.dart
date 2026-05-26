import '../../../core/result/result.dart';
import 'plugin_definition.dart';

abstract interface class PluginRepository {
  Future<Result<List<PluginDefinition>>> listPlugins();

  Future<Result<PluginDefinition>> importPluginFromPath(String path);

  Future<Result<PluginDefinition>> setEnabled(String id, bool enabled);

  Future<Result<void>> deletePlugin(String id);
}
