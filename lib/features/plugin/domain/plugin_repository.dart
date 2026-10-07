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

  int get successCount => importedCount + updatedCount;
}

abstract interface class PluginRepository {
  Future<Result<List<PluginDefinition>>> listPlugins();

  Future<Result<PluginDefinition>> importPluginFromPath(String path);

  Future<PluginImportBatchResult> importPluginsFromPaths(
    List<String> paths, {
    PluginImportProgressCallback? onProgress,
  });

  Future<Result<PluginDefinition>> importPluginFromUrl(String url);

  /// Imports every plugin reachable from [url].
  ///
  /// A single-plugin URL yields a one-item batch. A plugin-list URL fans out
  /// to its entries. Unlike [importPluginFromUrl], a partial failure still
  /// reports how many plugins landed, so the caller can refresh its list
  /// instead of discarding the successes.
  Future<PluginImportBatchResult> importPluginBatchFromUrl(
    String url, {
    PluginImportProgressCallback? onProgress,
  });

  Future<Result<PluginDefinition>> updateUserVariableValues(
    String id,
    Map<String, String> values,
  );

  Future<Result<PluginDefinition>> setEnabled(String id, bool enabled);

  /// Persists the user's manual row order.
  ///
  /// Ids absent from [orderedIds] keep the rank they already hold, so moving
  /// one row cannot flatten an arrangement built up over several drags. The
  /// returned list is the new plugin list in the app's default order.
  Future<Result<List<PluginDefinition>>> reorderPlugins(List<String> orderedIds);

  Future<Result<void>> deletePlugin(String id);
}
