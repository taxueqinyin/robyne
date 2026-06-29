import '../../../core/errors/app_error.dart';
import '../../../core/result/result.dart';
import 'plugin_definition.dart';

typedef PluginImportProgressCallback =
    void Function(PluginImportProgressSnapshot progress);

class PluginImportProgressSnapshot {
  const PluginImportProgressSnapshot({
    required this.total,
    required this.completed,
    required this.importedCount,
    required this.updatedCount,
    required this.skippedCount,
    required this.failedCount,
    this.currentLabel,
  });

  final int total;
  final int completed;
  final int importedCount;
  final int updatedCount;
  final int skippedCount;
  final int failedCount;
  final String? currentLabel;
}

class PluginImportBatchResult {
  const PluginImportBatchResult({
    required this.importedCount,
    required this.updatedCount,
    required this.skippedCount,
    required this.errors,
  });

  final int importedCount;
  final int updatedCount;
  final int skippedCount;
  final List<AppError> errors;

  bool get hasErrors => errors.isNotEmpty;

  bool get changedPlugins => importedCount > 0 || updatedCount > 0;
}

abstract interface class PluginRepository {
  Future<Result<List<PluginDefinition>>> listPlugins();

  Future<Result<PluginDefinition>> importPluginFromPath(String path);

  Future<PluginImportBatchResult> importPluginsFromPaths(
    List<String> paths, {
    PluginImportProgressCallback? onProgress,
  });

  Future<Result<PluginDefinition>> importPluginFromUrl(String url);

  Future<Result<PluginDefinition>> updateUserVariableValues(
    String id,
    Map<String, String> values,
  );

  Future<Result<PluginDefinition>> setEnabled(String id, bool enabled);

  Future<Result<void>> deletePlugin(String id);
}
