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
