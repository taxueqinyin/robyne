import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/result/result.dart';
import '../domain/plugin_definition.dart';
import '../domain/plugin_repository.dart';
import 'plugin_providers.dart';

final pluginControllerProvider =
    AsyncNotifierProvider<PluginController, List<PluginDefinition>>(
      PluginController.new,
    );

final pluginImportProgressProvider =
    NotifierProvider<PluginImportProgressNotifier, PluginImportProgress?>(
      PluginImportProgressNotifier.new,
    );

class PluginImportProgressNotifier extends Notifier<PluginImportProgress?> {
  @override
  PluginImportProgress? build() => null;

  void setProgress(PluginImportProgress? progress) {
    state = progress;
  }
}

class PluginImportProgress {
  const PluginImportProgress({
    required this.total,
    required this.completed,
    required this.importedCount,
    required this.failedCount,
    this.currentLabel,
  });

  final int total;
  final int completed;
  final int importedCount;
  final int failedCount;
  final String? currentLabel;

  double? get fraction => total <= 0 ? null : completed / total;
}

class PluginImportBatchResult {
  const PluginImportBatchResult({
    required this.importedCount,
    required this.errors,
  });

  final int importedCount;
  final List<AppError> errors;

  bool get hasErrors => errors.isNotEmpty;
}

class PluginController extends AsyncNotifier<List<PluginDefinition>> {
  @override
  Future<List<PluginDefinition>> build() async {
    final result = await ref.watch(pluginRepositoryProvider).listPlugins();
    return result.fold((plugins) => plugins, (error) => throw error);
  }

  Future<AppError?> importFromPath(String path) async {
    final repository = ref.read(pluginRepositoryProvider);
    final result = await repository.importPluginFromPath(path);
    return _refreshAfterImport(result, repository);
  }

  Future<PluginImportBatchResult> importFromPaths(List<String> paths) async {
    final repository = ref.read(pluginRepositoryProvider);
    final progress = ref.read(pluginImportProgressProvider.notifier);
    var importedCount = 0;
    final errors = <AppError>[];
    final total = paths.length;
    progress.setProgress(
      PluginImportProgress(
        total: total,
        completed: 0,
        importedCount: 0,
        failedCount: 0,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    try {
      for (var index = 0; index < paths.length; index += 1) {
        final path = paths[index];
        progress.setProgress(
          PluginImportProgress(
            total: total,
            completed: index,
            importedCount: importedCount,
            failedCount: errors.length,
            currentLabel: path,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        final result = await repository.importPluginFromPath(path);
        result.fold((_) {
          importedCount += 1;
        }, errors.add);
        progress.setProgress(
          PluginImportProgress(
            total: total,
            completed: index + 1,
            importedCount: importedCount,
            failedCount: errors.length,
            currentLabel: path,
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }

      if (importedCount > 0) {
        final refreshError = await _refreshPlugins(repository);
        if (refreshError == null) {
          ref.invalidate(installedPluginsProvider);
        } else {
          errors.add(refreshError);
        }
      } else {
        _restorePreviousPlugins();
      }

      return PluginImportBatchResult(
        importedCount: importedCount,
        errors: List<AppError>.unmodifiable(errors),
      );
    } finally {
      progress.setProgress(null);
    }
  }

  Future<AppError?> importFromUrl(String url) async {
    final repository = ref.read(pluginRepositoryProvider);
    final result = await repository.importPluginFromUrl(url);
    return _refreshAfterImport(result, repository);
  }

  Future<AppError?> _refreshAfterImport(
    Result<PluginDefinition> result,
    PluginRepository repository,
  ) async {
    return result.fold(
      (_) async {
        final error = await _refreshPlugins(repository);
        if (error == null) {
          ref.invalidate(installedPluginsProvider);
        }
        return error;
      },
      (error) {
        _restorePreviousPlugins();
        return error;
      },
    );
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final repository = ref.read(pluginRepositoryProvider);
    final result = await repository.setEnabled(id, enabled);
    await _refreshAfterPluginUpdate(result, repository);
  }

  Future<void> updateUserVariableValues(
    String id,
    Map<String, String> values,
  ) async {
    final repository = ref.read(pluginRepositoryProvider);
    final result = await repository.updateUserVariableValues(id, values);
    await _refreshAfterPluginUpdate(result, repository);
  }

  Future<void> _refreshAfterPluginUpdate(
    Result<PluginDefinition> result,
    PluginRepository repository,
  ) async {
    await result.fold(
      (_) async {
        final error = await _refreshPlugins(repository);
        if (error == null) {
          ref.invalidate(installedPluginsProvider);
        }
      },
      (error) async {
        _restorePreviousPlugins();
      },
    );
  }

  Future<void> delete(String id) async {
    final repository = ref.read(pluginRepositoryProvider);
    final result = await repository.deletePlugin(id);
    await result.fold(
      (_) async {
        final error = await _refreshPlugins(repository);
        if (error == null) {
          ref.invalidate(installedPluginsProvider);
        }
      },
      (error) async {
        _restorePreviousPlugins();
      },
    );
  }

  void _restorePreviousPlugins() {
    final plugins = state.value ?? const <PluginDefinition>[];
    state = AsyncData(plugins);
  }

  Future<AppError?> _refreshPlugins(PluginRepository repository) async {
    final refreshed = await repository.listPlugins();
    return refreshed.fold(
      (plugins) {
        state = AsyncData(plugins);
        return null;
      },
      (error) {
        _restorePreviousPlugins();
        return error;
      },
    );
  }
}
