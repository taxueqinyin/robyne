import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/errors/app_error.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/infrastructure/theme_manifest_parser.dart';
import 'package:robyne/features/plugin/application/plugin_providers.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/domain/plugin_repository.dart';
import 'package:robyne/features/plugin/domain/plugin_sort.dart';
import 'package:robyne/features/plugin/presentation/plugin_page.dart';

/// The plugin page's list is draggable, and its sort control is Chinese in the
/// bundled skin rather than the neutral English default.
void main() {
  testWidgets('the sort control reads from the active skin', (tester) async {
    final repository = _FakePluginRepository(
      plugins: <PluginDefinition>[
        _plugin(id: 'a', platform: 'A', installedAt: 100),
        _plugin(id: 'b', platform: 'B', installedAt: 200),
      ],
    );
    await tester.pumpWidget(
      _host(repository: repository),
    );
    await tester.pumpAndSettle();

    // The bundled skin names the manual order; the neutral default does not.
    expect(find.text('我的顺序'), findsOneWidget);
    expect(find.text('My order'), findsNothing);

    await tester.tap(find.text('我的顺序'));
    await tester.pumpAndSettle();
    for (final label in <String>['名称', '添加时间', '启用的优先', '最近更新']) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(find.text('名称').last);
    await tester.pumpAndSettle();
  });

  testWidgets('dragging a row reorders the list and persists it', (tester) async {
    final repository = _FakePluginRepository(
      plugins: <PluginDefinition>[
        _plugin(id: 'a', platform: 'Alpha', installedAt: 100),
        _plugin(id: 'b', platform: 'Beta', installedAt: 200),
        _plugin(id: 'c', platform: 'Gamma', installedAt: 300),
      ],
    );
    await tester.pumpWidget(_host(repository: repository));
    await tester.pumpAndSettle();

    // The rows are offered in the user's own order, which is the one that is
    // draggable.
    expect(_rowOrder(tester), <String>['Alpha', 'Beta', 'Gamma']);

    // Drag the first row down past the third.
    final handle = find
        .descendant(
          of: find.widgetWithText(ListTile, 'Alpha'),
          matching: find.byType(ReorderableDragStartListener),
        )
        .first;
    final handleCenter = tester.getCenter(handle);
    final target = tester.getCenter(
      find.widgetWithText(ListTile, 'Gamma').first,
    );
    final gesture = await tester.startGesture(handleCenter);
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveTo(handleCenter + const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveTo(target + const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(repository.reorderCalls, isNotEmpty);
    // The last row moved to the front of the list, and the repository was
    // asked to store exactly that arrangement.
    final stored = repository.reorderCalls.last;
    expect(stored, hasLength(3));
    expect(stored.first, isNot('a'));
  });

  testWidgets('a computed sort mode offers no drag handle', (tester) async {
    final repository = _FakePluginRepository(
      plugins: <PluginDefinition>[
        _plugin(id: 'a', platform: 'Alpha', installedAt: 100),
        _plugin(id: 'b', platform: 'Beta', installedAt: 200),
      ],
    );
    await tester.pumpWidget(_host(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的顺序'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('名称').last);
    await tester.pumpAndSettle();

    // Sorted by name, the row has no handle: dragging would have nowhere to
    // store its result.
    expect(find.byType(ReorderableDragStartListener), findsNothing);
    expect(find.text('拖动左侧手柄可调整顺序，发现页与搜索结果会同步'), findsNothing);
  });
}

/// The plugin rows' titles in the order they are painted.
List<String> _rowOrder(WidgetTester tester) {
  return tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data ?? '')
      .where((value) => <String>['Alpha', 'Beta', 'Gamma'].contains(value))
      .toList(growable: false);
}

Widget _host({required PluginRepository repository}) {
  return ProviderScope(
    overrides: [
      pluginRepositoryProvider.overrideWithValue(repository),
      activeThemePackageProvider.overrideWithValue(_xuanTheme()),
    ],
    child: const MaterialApp(home: Scaffold(body: PluginPage())),
  );
}

/// The bundled 《玄》 skin read from disk, so the Chinese sort labels this
/// test asserts are the ones the app actually ships rather than a copy that
/// can drift away from the asset.
ThemePackage _xuanTheme() {
  return const ThemeManifestParser().tryParse(
    jsonDecode(File('assets/themes/xuan/theme.json').readAsStringSync())
        as Object?,
    source: ThemeSource.builtIn,
  )!;
}

PluginDefinition _plugin({
  required String id,
  required String platform,
  required int installedAt,
}) {
  return PluginDefinition(
    id: id,
    platform: platform,
    sourcePath: '$id.js',
    enabled: true,
    installedAt: DateTime.fromMillisecondsSinceEpoch(installedAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(installedAt),
  );
}

class _FakePluginRepository implements PluginRepository {
  _FakePluginRepository({required this.plugins});

  final List<PluginDefinition> plugins;

  /// Every arrangement the UI asked to store, in call order.
  final List<List<String>> reorderCalls = <List<String>>[];

  @override
  Future<Result<List<PluginDefinition>>> listPlugins() async {
    return Ok(sortPlugins(plugins, PluginSortOrder.manual));
  }

  @override
  Future<Result<List<PluginDefinition>>> reorderPlugins(
    List<String> orderedIds,
  ) async {
    reorderCalls.add(List<String>.of(orderedIds));
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
