import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/errors/app_error.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/plugin/application/plugin_controller.dart';
import 'package:robyne/features/plugin/application/plugin_providers.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/domain/plugin_repository.dart';
import 'package:robyne/features/plugin/domain/plugin_sort.dart';

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

  test(
    'batch path import refreshes successful plugins and reports failures',
    () async {
      final existing = _plugin('existing', 'Existing');
      final imported = _plugin('imported', 'Imported');
      final repository = _FakePluginRepository(
        plugins: <PluginDefinition>[existing],
        importResult: Ok(imported),
        pathResults: <String, Result<PluginDefinition>>{
          'good.js': Ok(imported),
          'bad.js': const Failure(
            AppError(code: 'plugin.load_failed', message: 'Bad plugin.'),
          ),
        },
      );
      final container = ProviderContainer(
        overrides: [pluginRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(pluginControllerProvider.future);
      final result = await container
          .read(pluginControllerProvider.notifier)
          .importFromPaths(<String>['good.js', 'bad.js']);

      expect(result.importedCount, 1);
      expect(result.updatedCount, 0);
      expect(result.skippedCount, 0);
      expect(result.errors.single.code, 'plugin.load_failed');
      expect(container.read(pluginControllerProvider).value, <PluginDefinition>[
        existing,
        imported,
      ]);
    },
  );

  test('batch path import exposes progress while work is running', () async {
    final imported = _plugin('imported', 'Imported');
    final importStarted = Completer<void>();
    final releaseImport = Completer<void>();
    final repository = _FakePluginRepository(
      plugins: <PluginDefinition>[],
      importResult: Ok(imported),
      importStarted: importStarted,
      importGate: releaseImport.future,
    );
    final container = ProviderContainer(
      overrides: [pluginRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(pluginControllerProvider.future);
    final importFuture = container
        .read(pluginControllerProvider.notifier)
        .importFromPaths(<String>['slow.js']);

    await importStarted.future;
    final runningProgress = container.read(pluginImportProgressProvider);
    expect(runningProgress, isNotNull);
    expect(runningProgress?.total, 1);
    expect(runningProgress?.completed, 0);
    expect(runningProgress?.updatedCount, 0);
    expect(runningProgress?.skippedCount, 0);
    expect(runningProgress?.currentLabel, 'slow.js');

    releaseImport.complete();
    final result = await importFuture;

    expect(result.importedCount, 1);
    expect(container.read(pluginImportProgressProvider), isNull);
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
  _FakePluginRepository({
    required this.plugins,
    required this.importResult,
    this.pathResults = const <String, Result<PluginDefinition>>{},
    this.importStarted,
    this.importGate,
  });

  final List<PluginDefinition> plugins;
  final Result<PluginDefinition> importResult;
  final Map<String, Result<PluginDefinition>> pathResults;
  final Completer<void>? importStarted;
  final Future<void>? importGate;

  @override
  Future<Result<List<PluginDefinition>>> listPlugins() async {
    return Ok(plugins);
  }

  @override
  Future<Result<PluginDefinition>> importPluginFromUrl(String url) async {
    return importResult;
  }

  @override
  Future<PluginImportBatchResult> importPluginBatchFromUrl(
    String url, {
    PluginImportProgressCallback? onProgress,
  }) async {
    final errors = <AppError>[];
    var importedCount = 0;
    if (importResult case Ok<PluginDefinition>(:final value)) {
      plugins.add(value);
      importedCount = 1;
    } else if (importResult case Failure<PluginDefinition>(:final error)) {
      errors.add(error);
    }
    onProgress?.call(
      PluginImportProgressSnapshot(
        total: 1,
        completed: 0,
        importedCount: 0,
        updatedCount: 0,
        skippedCount: 0,
        failedCount: 0,
        currentLabel: url,
      ),
    );
    return PluginImportBatchResult(
      importedCount: importedCount,
      updatedCount: 0,
      skippedCount: 0,
      errors: errors,
    );
  }

  @override
  Future<Result<PluginDefinition>> importPluginFromPath(String path) async {
    final result = await importPluginsFromPaths(<String>[path]);
    if (result.importedCount > 0 || result.updatedCount > 0) {
      return Ok(plugins.last);
    }
    final error = result.errors.isNotEmpty
        ? result.errors.first
        : const AppError(code: 'plugin.skipped', message: 'Skipped.');
    return Failure(error);
  }

  @override
  Future<PluginImportBatchResult> importPluginsFromPaths(
    List<String> paths, {
    PluginImportProgressCallback? onProgress,
  }) async {
    var importedCount = 0;
    final errors = <AppError>[];
    onProgress?.call(
      PluginImportProgressSnapshot(
        total: paths.length,
        completed: 0,
        importedCount: 0,
        updatedCount: 0,
        skippedCount: 0,
        failedCount: 0,
      ),
    );
    for (var index = 0; index < paths.length; index += 1) {
      final path = paths[index];
      if (!(importStarted?.isCompleted ?? true)) {
        importStarted?.complete();
      }
      onProgress?.call(
        PluginImportProgressSnapshot(
          total: paths.length,
          completed: index,
          importedCount: importedCount,
          updatedCount: 0,
          skippedCount: 0,
          failedCount: errors.length,
          currentLabel: path,
        ),
      );
      final gate = importGate;
      if (gate != null) {
        await gate;
      }
      final result = pathResults[path] ?? importResult;
      if (result case Ok<PluginDefinition>(:final value)) {
        plugins.add(value);
        importedCount += 1;
      } else if (result case Failure<PluginDefinition>(:final error)) {
        errors.add(error);
      }
      onProgress?.call(
        PluginImportProgressSnapshot(
          total: paths.length,
          completed: index + 1,
          importedCount: importedCount,
          updatedCount: 0,
          skippedCount: 0,
          failedCount: errors.length,
          currentLabel: path,
        ),
      );
    }
    return PluginImportBatchResult(
      importedCount: importedCount,
      updatedCount: 0,
      skippedCount: 0,
      errors: List<AppError>.unmodifiable(errors),
    );
  }

  @override
  Future<Result<void>> deletePlugin(String id) async {
    return const Ok(null);
  }

  @override
  Future<Result<List<PluginDefinition>>> reorderPlugins(
    List<String> orderedIds,
  ) async {
    return Ok(applyPluginOrder(List<PluginDefinition>.of(plugins), orderedIds));
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
