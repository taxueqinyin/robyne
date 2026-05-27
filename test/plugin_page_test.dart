import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/errors/app_error.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/plugin/application/plugin_providers.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/domain/plugin_repository.dart';
import 'package:robyne/features/plugin/presentation/plugin_page.dart';

void main() {
  testWidgets(
    'URL import dialog can submit without disposed controller errors',
    (tester) async {
      final existing = _plugin('existing', 'Existing Plugin');
      final repository = _FakePluginRepository(
        plugins: <PluginDefinition>[existing],
        importResult: const Failure(
          AppError(
            code: 'plugin.load_failed',
            message: 'Failed to load plugin from URL.',
          ),
        ),
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
        'https://example.com/plugin.js',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Existing Plugin'), findsOneWidget);
      expect(find.textContaining('plugin.load_failed'), findsOneWidget);
    },
  );
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
