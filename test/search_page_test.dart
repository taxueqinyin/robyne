import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/plugin/application/plugin_providers.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/domain/plugin_repository.dart';
import 'package:robyne/features/search/application/search_controller.dart';
import 'package:robyne/features/search/presentation/search_page.dart';

void main() {
  testWidgets('search field does not update global state while composing', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        pluginRepositoryProvider.overrideWithValue(_FakePluginRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SearchPage())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '中文');
    await tester.pump();

    expect(container.read(searchControllerProvider).value?.keyword, isEmpty);
  });
}

class _FakePluginRepository implements PluginRepository {
  @override
  Future<Result<List<PluginDefinition>>> listPlugins() async {
    return const Ok(<PluginDefinition>[]);
  }

  @override
  Future<Result<void>> deletePlugin(String id) async {
    return const Ok(null);
  }

  @override
  Future<Result<PluginDefinition>> importPluginFromPath(String path) async {
    throw UnimplementedError();
  }

  @override
  Future<PluginImportBatchResult> importPluginsFromPaths(
    List<String> paths, {
    PluginImportProgressCallback? onProgress,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<PluginDefinition>> importPluginFromUrl(String url) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<PluginDefinition>> setEnabled(String id, bool enabled) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<PluginDefinition>> updateUserVariableValues(
    String id,
    Map<String, String> values,
  ) async {
    throw UnimplementedError();
  }
}
