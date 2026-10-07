import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/core/theme/infrastructure/theme_manifest_parser.dart';
import 'package:robyne/features/plugin/application/plugin_providers.dart';
import 'package:robyne/features/plugin/application/plugin_controller.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/domain/plugin_repository.dart';
import 'package:robyne/features/search/domain/music_item.dart';
import 'package:robyne/features/search/domain/search_result.dart';
import 'package:robyne/features/search/application/search_controller.dart'
    as search_state;
import 'package:robyne/core/theme/domain/theme_package.dart';
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

    expect(
      container.read(search_state.searchControllerProvider).value?.keyword,
      isEmpty,
    );
  });

  testWidgets('search page renders source pills instead of Material chips', (
    tester,
  ) async {
    final plugin = PluginDefinition(
      id: 'plugin-a',
      platform: 'Source A',
      sourcePath: 'unused.js',
      enabled: true,
      installedAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final item = MusicItem(
      id: 'one',
      pluginId: plugin.id,
      platform: plugin.platform,
      title: 'Night Route',
      artist: 'Echo FM',
      raw: const <String, Object?>{'id': 'one'},
    );
    final result = SearchResult(items: <MusicItem>[item], page: 1, isEnd: true);
    final container = ProviderContainer(
      overrides: [
        pluginRepositoryProvider.overrideWithValue(_FakePluginRepository()),
        pluginControllerProvider.overrideWith(
          () => _FakePluginController([plugin]),
        ),
        search_state.searchControllerProvider.overrideWith(
          () => _SeededSearchController(plugin, result),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SearchPage())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Night Route'), findsOneWidget);
    expect(find.text('Source A'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('result tabs follow the plugin page order', (tester) async {
    // The user dragged "Source C" to the top of the plugin page. Searches
    // finish in whatever order they finish, so the tabs must be laid out from
    // the stored arrangement rather than from completion order.
    final plugins = <PluginDefinition>[
      _plugin(id: 'c', platform: 'Source C', installedAt: 300, sortIndex: 1),
      _plugin(id: 'a', platform: 'Source A', installedAt: 100, sortIndex: 2),
      _plugin(id: 'b', platform: 'Source B', installedAt: 200, sortIndex: 3),
    ];
    final container = ProviderContainer(
      overrides: [
        pluginRepositoryProvider.overrideWithValue(_FakePluginRepository()),
        pluginControllerProvider.overrideWith(
          () => _FakePluginController(plugins),
        ),
        search_state.searchControllerProvider.overrideWith(
          () => _SeededMultiSearchController(
            // Deliberately handed in completion order, not the user's order.
            <search_state.PluginSearchState>[
              for (final plugin in <PluginDefinition>[
                plugins[1],
                plugins[2],
                plugins[0],
              ])
                search_state.PluginSearchState(
                  pluginId: plugin.id,
                  platform: plugin.platform,
                  result: const SearchResult(
                    items: <MusicItem>[],
                    page: 1,
                    isEnd: true,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SearchPage())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final tabs = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data ?? '')
        .where((value) => value.startsWith('Source'))
        .toList(growable: false);
    expect(tabs, <String>['Source C 0', 'Source A 0', 'Source B 0']);
  });

  testWidgets('search page uses the skin-declared chrome strings', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        pluginRepositoryProvider.overrideWithValue(_FakePluginRepository()),
        activeThemePackageProvider.overrideWithValue(_xuanTheme()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SearchPage())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('搜索'), findsWidgets);
    expect(find.text('Search'), findsNothing);
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
  Future<Result<List<PluginDefinition>>> reorderPlugins(
    List<String> orderedIds,
  ) async {
    return const Ok(<PluginDefinition>[]);
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
  Future<PluginImportBatchResult> importPluginBatchFromUrl(
    String url, {
    PluginImportProgressCallback? onProgress,
  }) async {
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

/// A parsed copy of the bundled flagship, so the assertions run against the
/// manifest that ships rather than against a made-up fixture.
ThemePackage _xuanTheme() {
  return const ThemeManifestParser().tryParse(
    jsonDecode(File('assets/themes/xuan/theme.json').readAsStringSync())
        as Object?,
    source: ThemeSource.builtIn,
  )!;
}

class _FakePluginController extends PluginController {
  _FakePluginController(this._plugins);

  final List<PluginDefinition> _plugins;

  @override
  Future<List<PluginDefinition>> build() async => _plugins;
}

/// A controller that already holds a finished search for one plugin.
class _SeededSearchController extends search_state.SearchController {
  _SeededSearchController(this.plugin, this.result);

  final PluginDefinition plugin;
  final SearchResult result;

  @override
  search_state.SearchState build() {
    return search_state.SearchState(
      keyword: 'night',
      selectedPluginId: plugin.id,
      pluginResults: <search_state.PluginSearchState>[
        search_state.PluginSearchState(
          pluginId: plugin.id,
          platform: plugin.platform,
          result: result,
        ),
      ],
    );
  }
}

/// A controller holding finished searches for several plugins, handed in the
/// order the searches completed.
class _SeededMultiSearchController extends search_state.SearchController {
  _SeededMultiSearchController(this.results);

  final List<search_state.PluginSearchState> results;

  @override
  search_state.SearchState build() {
    return search_state.SearchState(
      keyword: 'night',
      selectedPluginId: results.first.pluginId,
      pluginResults: results,
    );
  }
}

PluginDefinition _plugin({
  required String id,
  required String platform,
  required int installedAt,
  int sortIndex = 0,
}) {
  return PluginDefinition(
    id: id,
    platform: platform,
    sourcePath: '$id.js',
    enabled: true,
    installedAt: DateTime.fromMillisecondsSinceEpoch(installedAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(installedAt),
    sortIndex: sortIndex,
  );
}
