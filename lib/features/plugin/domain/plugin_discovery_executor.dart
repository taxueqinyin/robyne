import '../../../core/result/result.dart';
import 'plugin_definition.dart';

abstract interface class PluginDiscoveryExecutor {
  Future<Result<Object?>> getTopLists({
    required PluginDefinition plugin,
    required String source,
  });

  Future<Result<Object?>> getTopListDetail({
    required PluginDefinition plugin,
    required String source,
    required Map<String, Object?> topList,
  });

  Future<Result<Object?>> getRecommendSheetTags({
    required PluginDefinition plugin,
    required String source,
  });

  Future<Result<Object?>> getRecommendSheetsByTag({
    required PluginDefinition plugin,
    required String source,
    required Map<String, Object?> tag,
    required int page,
  });

  Future<Result<Object?>> getMusicSheetInfo({
    required PluginDefinition plugin,
    required String source,
    required Map<String, Object?> sheetItem,
    required int page,
  });
}
