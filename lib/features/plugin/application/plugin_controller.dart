import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/plugin_definition.dart';
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

  Future<void> importFromPath(String path) async {
    state = const AsyncLoading();
    final repository = ref.read(pluginRepositoryProvider);
    final result = await repository.importPluginFromPath(path);
    state = await AsyncValue.guard(() async {
      return result.fold((_) async {
        final refreshed = await repository.listPlugins();
        return refreshed.fold((plugins) => plugins, (error) => throw error);
      }, (error) => throw error);
    });
    ref.invalidate(installedPluginsProvider);
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final repository = ref.read(pluginRepositoryProvider);
    final result = await repository.setEnabled(id, enabled);
    state = await AsyncValue.guard(() async {
      return result.fold((_) async {
        final refreshed = await repository.listPlugins();
        return refreshed.fold((plugins) => plugins, (error) => throw error);
      }, (error) => throw error);
    });
    ref.invalidate(installedPluginsProvider);
  }

  Future<void> delete(String id) async {
    final repository = ref.read(pluginRepositoryProvider);
    final result = await repository.deletePlugin(id);
    state = await AsyncValue.guard(() async {
      return result.fold((_) async {
        final refreshed = await repository.listPlugins();
        return refreshed.fold((plugins) => plugins, (error) => throw error);
      }, (error) => throw error);
    });
    ref.invalidate(installedPluginsProvider);
  }
}
