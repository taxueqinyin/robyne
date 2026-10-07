import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/errors/app_error.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/plugin/application/plugin_controller.dart';
import 'package:robyne/features/plugin/application/plugin_providers.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/domain/plugin_repository.dart';
import 'package:robyne/features/plugin/domain/plugin_sort.dart';

/// A drag on the plugin page is a stored arrangement, not a view preference:
/// the discover source row and the search result tabs both read it.
void main() {
  test('reordering persists and is what other surfaces read', () async {
    final repository = _FakePluginRepository(
      plugins: <PluginDefinition>[
        // Distinct install times so the manual order has a stable fallback for
        // rows the user has not dragged yet.
        _plugin(id: 'a', platform: 'A', installedAt: 100),
        _plugin(id: 'b', platform: 'B', installedAt: 200),
        _plugin(id: 'c', platform: 'C', installedAt: 300),
      ],
    );
    final container = ProviderContainer(
      overrides: [pluginRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(pluginControllerProvider.future);
    expect(
      container.read(orderedPluginsProvider).map((e) => e.id).toList(),
      <String>['a', 'b', 'c'],
    );

    await container
        .read(pluginControllerProvider.notifier)
        .reorderPlugins(<String>['c', 'a', 'b']);

    // The arrangement is what the sources inherit, and it is what the
    // repository stored — so it survives a restart rather than living only in
    // the widget tree.
    expect(
      container.read(orderedPluginsProvider).map((e) => e.id).toList(),
      <String>['c', 'a', 'b'],
    );
    expect(repository.idsInStoredOrder, <String>['c', 'a', 'b']);
    expect(
      container
          .read(orderedEnabledPluginsProvider)
          .map((e) => e.id)
          .toList(),
      <String>['c', 'a', 'b'],
    );
  });

  test('disabled plugins drop out of the source list but keep their rank', () async {
    final repository = _FakePluginRepository(
      plugins: <PluginDefinition>[
        _plugin(id: 'a', platform: 'A', installedAt: 100),
        _plugin(id: 'b', platform: 'B', enabled: false, installedAt: 200),
      ],
    );
    final container = ProviderContainer(
      overrides: [pluginRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(pluginControllerProvider.future);

    expect(
      container.read(orderedPluginsProvider).map((e) => e.id).toList(),
      <String>['a', 'b'],
    );
    // Search starts from every installed plugin, but the discover source row
    // only offers the ones that can actually serve content.
    expect(
      container.read(orderedEnabledPluginsProvider).map((e) => e.id).toList(),
      <String>['a'],
    );
  });

  test('a failed reorder restores the previous order', () async {
    final repository = _FakePluginRepository(
      plugins: <PluginDefinition>[
        _plugin(id: 'a', platform: 'A', installedAt: 100),
        _plugin(id: 'b', platform: 'B', installedAt: 200),
      ],
      reorderFails: true,
    );
    final container = ProviderContainer(
      overrides: [pluginRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(pluginControllerProvider.future);
    await container
        .read(pluginControllerProvider.notifier)
        .reorderPlugins(<String>['b', 'a']);

    expect(
      container.read(orderedPluginsProvider).map((e) => e.id).toList(),
      <String>['a', 'b'],
    );
  });
}

PluginDefinition _plugin({
  required String id,
  required String platform,
  bool enabled = true,
  int installedAt = 0,
}) {
  return PluginDefinition(
    id: id,
    platform: platform,
    sourcePath: '$id.js',
    enabled: enabled,
    installedAt: DateTime.fromMillisecondsSinceEpoch(installedAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(installedAt),
  );
}

class _FakePluginRepository implements PluginRepository {
  _FakePluginRepository({required this.plugins, this.reorderFails = false});

  final List<PluginDefinition> plugins;
  final bool reorderFails;

  /// The order the last successful reorder left in storage.
  List<String> get idsInStoredOrder =>
      plugins.map((plugin) => plugin.id).toList(growable: false);

  @override
  Future<Result<List<PluginDefinition>>> listPlugins() async {
    // Mirrors the real repository: rows are read back in manual order, so the
    // ranking is what storage remembers rather than what the caller passed.
    return Ok(sortPlugins(plugins, PluginSortOrder.manual));
  }

  @override
  Future<Result<List<PluginDefinition>>> reorderPlugins(
    List<String> orderedIds,
  ) async {
    if (reorderFails) {
      return const Failure(
        AppError(
          code: 'storage.write_failed',
          message: 'Failed to save the plugin order.',
        ),
      );
    }
    final reordered = applyPluginOrder(
      List<PluginDefinition>.of(plugins),
      orderedIds,
    );
    plugins
      ..clear()
      ..addAll(reordered);
    return Ok(sortPlugins(plugins, PluginSortOrder.manual));
  }

  @override
  Future<Result<PluginDefinition>> importPluginFromPath(String path) async =>
      const Failure(AppError(code: 'unused', message: 'unused'));

  @override
  Future<PluginImportBatchResult> importPluginsFromPaths(
    List<String> paths, {
    PluginImportProgressCallback? onProgress,
  }) async =>
      const PluginImportBatchResult(
        importedCount: 0,
        updatedCount: 0,
        skippedCount: 0,
        errors: <AppError>[],
      );

  @override
  Future<Result<PluginDefinition>> importPluginFromUrl(String url) async =>
      const Failure(AppError(code: 'unused', message: 'unused'));

  @override
  Future<PluginImportBatchResult> importPluginBatchFromUrl(
    String url, {
    PluginImportProgressCallback? onProgress,
  }) async =>
      const PluginImportBatchResult(
        importedCount: 0,
        updatedCount: 0,
        skippedCount: 0,
        errors: <AppError>[],
      );

  @override
  Future<Result<void>> deletePlugin(String id) async => const Ok(null);

  @override
  Future<Result<PluginDefinition>> setEnabled(String id, bool enabled) async =>
      Ok(plugins.first);

  @override
  Future<Result<PluginDefinition>> updateUserVariableValues(
    String id,
    Map<String, String> values,
  ) async =>
      Ok(plugins.first);
}
