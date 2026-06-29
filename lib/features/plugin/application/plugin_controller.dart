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

  double? get fraction => total <= 0 ? null : completed / total;
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
    DateTime? lastProgressAt;

    try {
      final result = await repository.importPluginsFromPaths(
        paths,
        onProgress: (snapshot) {
          final now = DateTime.now();
          final shouldEmit =
              snapshot.completed == 0 ||
              snapshot.completed >= snapshot.total ||
              lastProgressAt == null ||
              now.difference(lastProgressAt!) >=
                  const Duration(milliseconds: 100);
          if (!shouldEmit) {
            return;
          }
          lastProgressAt = now;
          progress.setProgress(
            PluginImportProgress(
              total: snapshot.total,
              completed: snapshot.completed,
              importedCount: snapshot.importedCount,
              updatedCount: snapshot.updatedCount,
              skippedCount: snapshot.skippedCount,
              failedCount: snapshot.failedCount,
              currentLabel: snapshot.currentLabel,
            ),
          );
        },
      );

      if (result.changedPlugins) {
        final refreshError = await _refreshPlugins(repository);
        if (refreshError == null) {
          ref.invalidate(installedPluginsProvider);
        } else {
          return PluginImportBatchResult(
            importedCount: result.importedCount,
            updatedCount: result.updatedCount,
            skippedCount: result.skippedCount,
            errors: List<AppError>.unmodifiable(<AppError>[
              ...result.errors,
              refreshError,
            ]),
          );
        }
      } else {
        _restorePreviousPlugins();
      }

      return result;
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
