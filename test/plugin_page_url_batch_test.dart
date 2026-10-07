import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/errors/app_error.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/plugin/application/plugin_providers.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/domain/plugin_repository.dart';
import 'package:robyne/features/plugin/domain/plugin_sort.dart';
import 'package:robyne/features/plugin/presentation/plugin_page.dart';

void main() {
  testWidgets('partial list import shows the plugins that landed', (
    tester,
  ) async {
    final existing = _plugin('before', 'Before');
    final repository = _PartialFailureRepository(
      starting: <PluginDefinition>[existing],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [pluginRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: PluginPage())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import from URL'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'https://music.nairocy.com/plugins.json',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();

    // The regression: imported plugins used to be discarded entirely.
    expect(find.text('Imported 0'), findsOneWidget);
    expect(find.text('Imported 1'), findsOneWidget);
    expect(find.text('Imported 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

/// Plugins commit during the import, then a partial failure is reported —
/// exactly what a real plugin list with a few dead links produces.
class _PartialFailureRepository implements PluginRepository {
  _PartialFailureRepository({required this.starting});

  final List<PluginDefinition> starting;
  final List<PluginDefinition> _all = <PluginDefinition>[];

  @override
  Future<Result<List<PluginDefinition>>> listPlugins() async {
    return Ok(
      _all.isEmpty
          ? List<PluginDefinition>.of(starting)
          : List<PluginDefinition>.of(_all),
    );
  }

  @override
  Future<PluginImportBatchResult> importPluginBatchFromUrl(
    String url, {
    PluginImportProgressCallback? onProgress,
  }) async {
    _all
      ..addAll(starting)
      ..addAll(<PluginDefinition>[
        for (var i = 0; i < 3; i += 1) _plugin('p$i', 'Imported $i'),
      ]);
    return PluginImportBatchResult(
      importedCount: 3,
      updatedCount: 0,
      skippedCount: 0,
      errors: List<AppError>.unmodifiable(<AppError>[
        const AppError(
          code: 'plugin.download_failed',
          message: 'Download failed with HTTP 403.',
        ),
      ]),
    );
  }

  @override
  Future<Result<PluginDefinition>> importPluginFromUrl(String url) async =>
      Ok(_all.first);

  @override
  Future<Result<PluginDefinition>> importPluginFromPath(String path) async =>
      Ok(_all.first);

  @override
  Future<PluginImportBatchResult> importPluginsFromPaths(
    List<String> paths, {
    PluginImportProgressCallback? onProgress,
  }) async => const PluginImportBatchResult(
    importedCount: 0,
    updatedCount: 0,
    skippedCount: 0,
    errors: <AppError>[],
  );

  @override
  Future<Result<void>> deletePlugin(String id) async => const Ok(null);

  @override
  Future<Result<List<PluginDefinition>>> reorderPlugins(
    List<String> orderedIds,
  ) async {
    return Ok(applyPluginOrder(List<PluginDefinition>.of(_all), orderedIds));
  }

  @override
  Future<Result<PluginDefinition>> setEnabled(String id, bool enabled) async =>
      Ok(_all.first);

  @override
  Future<Result<PluginDefinition>> updateUserVariableValues(
    String id,
    Map<String, String> values,
  ) async => Ok(_all.first);
}
