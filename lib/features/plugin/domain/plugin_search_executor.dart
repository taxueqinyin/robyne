import '../../../core/result/result.dart';
import 'plugin_definition.dart';

abstract interface class PluginSearchExecutor {
  Future<Result<Object?>> search({
    required PluginDefinition plugin,
    required String source,
    required String keyword,
    required int page,
    required String searchType,
  });
}
