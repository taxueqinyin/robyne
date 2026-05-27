import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/errors/app_error.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/plugin/application/plugin_controller.dart';
import 'package:robyne/features/plugin/application/plugin_providers.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/domain/plugin_repository.dart';

void main() {
  test('failed URL import keeps existing plugin list visible', () async {
    final existing = _plugin('existing', 'Existing');
    final repository = _FakePluginRepository(
      plugins: <PluginDefinition>[existing],
      importResult: const Failure(
        AppError(
          code: 'plugin.url_invalid',
          message: 'Enter a valid plugin URL.',
        ),
      ),
    );
    final container = ProviderContainer(
      overrides: [pluginRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final initial = await container.read(pluginControllerProvider.future);
    expect(initial, <PluginDefinition>[existing]);

    final error = await container
        .read(pluginControllerProvider.notifier)
        .importFromUrl('');

    expect(error?.code, 'plugin.url_invalid');
    final state = container.read(pluginControllerProvider);
    expect(state.hasError, isFalse);
    expect(state.value, <PluginDefinition>[existing]);
  });
}

PluginDefinition _plugin(String id, String platform) {
  return PluginDefinition(
    id: id,
    platform: platform,
    sourcePath: '$id.js',
    enabled: true,
    installedAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class _FakePluginRepository implements PluginRepository {
  _FakePluginRepository({required this.plugins, required this.importResult});

  final List<PluginDefinition> plugins;
  final Result<PluginDefinition> importResult;

  @override
  Future<Result<List<PluginDefinition>>> listPlugins() async {
    return Ok(plugins);
  }

  @override
  Future<Result<PluginDefinition>> importPluginFromUrl(String url) async {
    return importResult;
  }

  @override
  Future<Result<PluginDefinition>> importPluginFromPath(String path) async {
    return importResult;
  }

  @override
  Future<Result<void>> deletePlugin(String id) async {
    return const Ok(null);
  }

  @override
  Future<Result<PluginDefinition>> setEnabled(String id, bool enabled) async {
    return Ok(plugins.first);
  }

  @override
  Future<Result<PluginDefinition>> updateUserVariableValues(
    String id,
    Map<String, String> values,
  ) async {
    return Ok(plugins.first);
  }
}
