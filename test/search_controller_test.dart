import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/plugin/application/plugin_providers.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/domain/plugin_search_executor.dart';
import 'package:robyne/features/search/application/search_controller.dart';

void main() {
  test('searches all enabled plugins and keeps per-plugin results', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_search_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final pluginAPath = await _writePluginFile(tempDirectory, 'plugin-a.js');
    final pluginBPath = await _writePluginFile(tempDirectory, 'plugin-b.js');
    final disabledPath = await _writePluginFile(
      tempDirectory,
      'plugin-disabled.js',
    );

    final executor = _FakePluginSearchExecutor();
    final container = ProviderContainer(
      overrides: [pluginSearchExecutorProvider.overrideWithValue(executor)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(searchControllerProvider.notifier);
    notifier.updateKeyword('周杰伦');

    await notifier.search(<PluginDefinition>[
      _plugin('plugin-a', 'Source A', pluginAPath),
      _plugin('plugin-b', 'Source B', pluginBPath),
      _plugin('plugin-disabled', 'Disabled', disabledPath, enabled: false),
    ]);

    final state = container.read(searchControllerProvider).value!;
    expect(state.isSearching, isFalse);
    expect(state.pluginResults, hasLength(2));
    expect(state.pluginResults.map((result) => result.platform), <String>[
      'Source A',
      'Source B',
    ]);
    expect(
      state.pluginResults.first.result?.items.single.title,
      'Source A 周杰伦 page 1',
    );
    expect(
      executor.searches,
      unorderedEquals(<String>['Source A:1', 'Source B:1']),
    );

    notifier.selectPlugin('plugin-b');
    final selected = container.read(searchControllerProvider).value!;
    expect(selected.selectedPluginResult?.platform, 'Source B');
  });

  test(
    'loadMoreSelected appends the next page for the selected plugin',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_search_test_',
      );
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final pluginAPath = await _writePluginFile(tempDirectory, 'plugin-a.js');
      final pluginBPath = await _writePluginFile(tempDirectory, 'plugin-b.js');
      final executor = _FakePluginSearchExecutor();

      final container = ProviderContainer(
        overrides: [pluginSearchExecutorProvider.overrideWithValue(executor)],
      );
      addTearDown(container.dispose);

      final plugins = <PluginDefinition>[
        _plugin('plugin-a', 'Source A', pluginAPath),
        _plugin('plugin-b', 'Source B', pluginBPath),
      ];
      final notifier = container.read(searchControllerProvider.notifier);
      notifier.updateKeyword('周杰伦');

      await notifier.search(plugins);
      notifier.selectPlugin('plugin-a');
      await notifier.loadMoreSelected(plugins);

      final state = container.read(searchControllerProvider).value!;
      final selected = state.selectedPluginResult!;
      expect(selected.isLoadingMore, isFalse);
      expect(selected.error, isNull);
      expect(selected.result?.page, 2);
      expect(selected.result?.isEnd, isTrue);
      expect(selected.result?.items.map((item) => item.title), <String>[
        'Source A 周杰伦 page 1',
        'Source A 周杰伦 page 2',
      ]);
      expect(executor.searches, contains('Source A:2'));
      expect(
        executor.searches.where((entry) => entry == 'Source B:2'),
        isEmpty,
      );
    },
  );

  test('limits concurrent plugin searches', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_search_concurrency_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final pluginPaths = <String>[];
    for (var index = 0; index < 8; index += 1) {
      pluginPaths.add(
        await _writePluginFile(tempDirectory, 'plugin-$index.js'),
      );
    }
    final executor = _FakePluginSearchExecutor(
      searchDelay: const Duration(milliseconds: 10),
    );

    final container = ProviderContainer(
      overrides: [pluginSearchExecutorProvider.overrideWithValue(executor)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(searchControllerProvider.notifier);
    notifier.updateKeyword('keyword');

    await notifier.search(<PluginDefinition>[
      for (var index = 0; index < pluginPaths.length; index += 1)
        _plugin('plugin-$index', 'Source $index', pluginPaths[index]),
    ]);

    expect(executor.searches, hasLength(8));
    expect(executor.maxConcurrentSearches, lessThanOrEqualTo(3));
  });

  test(
    'cancel stops remaining plugin searches and keeps finished results',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_search_cancel_test_',
      );
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final pluginAPath = await _writePluginFile(tempDirectory, 'plugin-a.js');
      final pluginBPath = await _writePluginFile(tempDirectory, 'plugin-b.js');
      final pluginBHold = Completer<void>();
      final pluginBStarted = Completer<void>();
      final executor = _FakePluginSearchExecutor(
        beforeComplete: (plugin) async {
          if (plugin.id == 'plugin-b') {
            if (!pluginBStarted.isCompleted) {
              pluginBStarted.complete();
            }
            await pluginBHold.future;
          }
        },
      );
      final container = ProviderContainer(
        overrides: [pluginSearchExecutorProvider.overrideWithValue(executor)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(searchControllerProvider.notifier);
      notifier.updateKeyword('周杰伦');
      final searchFuture = notifier.search(<PluginDefinition>[
        _plugin('plugin-a', 'Source A', pluginAPath),
        _plugin('plugin-b', 'Source B', pluginBPath),
      ]);

      await pluginBStarted.future;
      SearchState? mid;
      for (var attempt = 0; attempt < 20; attempt += 1) {
        mid = container.read(searchControllerProvider).value;
        if (mid?.pluginResults.first.result != null) {
          break;
        }
        await Future<void>.delayed(Duration.zero);
      }

      expect(mid?.isSearching, isTrue);
      expect(mid?.pluginResults.first.result, isNotNull);
      expect(mid?.pluginResults.last.isSearching, isTrue);

      notifier.cancel();
      final cancelled = container.read(searchControllerProvider).value!;
      expect(cancelled.isSearching, isFalse);
      expect(
        cancelled.pluginResults.first.result?.items.single.title,
        'Source A 周杰伦 page 1',
      );
      expect(cancelled.pluginResults.last.isSearching, isFalse);
      expect(cancelled.pluginResults.last.error?.code, 'search.cancelled');

      pluginBHold.complete();
      await searchFuture;

      final after = container.read(searchControllerProvider).value!;
      expect(after.isSearching, isFalse);
      expect(after.pluginResults.first.result, isNotNull);
      expect(after.pluginResults.last.result, isNull);
      expect(after.pluginResults.last.error?.code, 'search.cancelled');
    },
  );
}

Future<String> _writePluginFile(Directory directory, String name) async {
  final file = File('${directory.path}/$name');
  await file.writeAsString('// $name');
  return file.path;
}

PluginDefinition _plugin(
  String id,
  String platform,
  String sourcePath, {
  bool enabled = true,
}) {
  return PluginDefinition(
    id: id,
    platform: platform,
    sourcePath: sourcePath,
    enabled: enabled,
    installedAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class _FakePluginSearchExecutor implements PluginSearchExecutor {
  _FakePluginSearchExecutor({
    this.searchDelay = Duration.zero,
    this.beforeComplete,
  });

  final Duration searchDelay;
  final Future<void> Function(PluginDefinition plugin)? beforeComplete;
  final List<String> searches = <String>[];
  int _activeSearches = 0;
  int maxConcurrentSearches = 0;

  @override
  Future<Result<Object?>> search({
    required PluginDefinition plugin,
    required String source,
    required String keyword,
    required int page,
    required String searchType,
  }) async {
    _activeSearches += 1;
    if (_activeSearches > maxConcurrentSearches) {
      maxConcurrentSearches = _activeSearches;
    }
    try {
      final hold = beforeComplete;
      if (hold != null) {
        await hold(plugin);
      }
      if (searchDelay > Duration.zero) {
        await Future<void>.delayed(searchDelay);
      }
      searches.add('${plugin.platform}:$page');
      return Ok(<String, Object?>{
        'page': page,
        'isEnd': page >= 2,
        'data': <Object?>[
          <String, Object?>{
            'id': '${plugin.platform}-$page',
            'title': '${plugin.platform} $keyword page $page',
          },
        ],
      });
    } finally {
      _activeSearches -= 1;
    }
  }
}
