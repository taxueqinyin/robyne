import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/lyrics/application/lyrics_providers.dart';
import 'package:robyne/features/plugin/application/plugin_providers.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/domain/plugin_search_executor.dart';

void main() {
  test('limits concurrent lyric plugin searches', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_lyric_search_concurrency_test_',
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
    final executor = _FakeLyricSearchExecutor(
      searchDelay: const Duration(milliseconds: 10),
    );
    final container = ProviderContainer(
      overrides: [pluginSearchExecutorProvider.overrideWithValue(executor)],
    );
    addTearDown(container.dispose);

    await container
        .read(lyricSearchControllerProvider.notifier)
        .search('keyword', <PluginDefinition>[
          for (var index = 0; index < pluginPaths.length; index += 1)
            _plugin('plugin-$index', 'Source $index', pluginPaths[index]),
        ]);

    final state = container.read(lyricSearchControllerProvider).value!;
    expect(state.isSearching, isFalse);
    expect(state.pluginResults, hasLength(8));
    expect(executor.searches, hasLength(8));
    expect(executor.maxConcurrentSearches, lessThanOrEqualTo(3));
  });

  test(
    'cancel stops remaining lyric plugin searches and keeps finished results',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_lyric_search_cancel_test_',
      );
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final pluginAPath = await _writePluginFile(tempDirectory, 'plugin-a.js');
      final pluginBPath = await _writePluginFile(tempDirectory, 'plugin-b.js');
      final pluginBHold = Completer<void>();
      final pluginBStarted = Completer<void>();
      final executor = _FakeLyricSearchExecutor(
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

      final searchFuture = container
          .read(lyricSearchControllerProvider.notifier)
          .search('keyword', <PluginDefinition>[
            _plugin('plugin-a', 'Source A', pluginAPath),
            _plugin('plugin-b', 'Source B', pluginBPath),
          ]);

      await pluginBStarted.future;
      LyricSearchState? mid;
      for (var attempt = 0; attempt < 20; attempt += 1) {
        mid = container.read(lyricSearchControllerProvider).value;
        if (mid?.pluginResults.first.items.isNotEmpty ?? false) {
          break;
        }
        await Future<void>.delayed(Duration.zero);
      }

      expect(mid?.isSearching, isTrue);
      expect(mid?.pluginResults.first.items, isNotEmpty);
      expect(mid?.pluginResults.last.isSearching, isTrue);

      container.read(lyricSearchControllerProvider.notifier).cancel();
      final cancelled = container.read(lyricSearchControllerProvider).value!;
      expect(cancelled.isSearching, isFalse);
      expect(
        cancelled.pluginResults.first.items.single.title,
        'Source A lyric',
      );
      expect(cancelled.pluginResults.last.isSearching, isFalse);
      expect(
        cancelled.pluginResults.last.error?.code,
        'lyric.search_cancelled',
      );

      pluginBHold.complete();
      await searchFuture;

      final after = container.read(lyricSearchControllerProvider).value!;
      expect(after.isSearching, isFalse);
      expect(after.pluginResults.first.items, isNotEmpty);
      expect(after.pluginResults.last.items, isEmpty);
      expect(after.pluginResults.last.error?.code, 'lyric.search_cancelled');
    },
  );
}

Future<String> _writePluginFile(Directory directory, String name) async {
  final file = File('${directory.path}/$name');
  await file.writeAsString('// $name');
  return file.path;
}

PluginDefinition _plugin(String id, String platform, String sourcePath) {
  return PluginDefinition(
    id: id,
    platform: platform,
    sourcePath: sourcePath,
    enabled: true,
    supportedSearchTypes: const <String>['lyric'],
    installedAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class _FakeLyricSearchExecutor implements PluginSearchExecutor {
  _FakeLyricSearchExecutor({
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
      searches.add(plugin.platform);
      return Ok(<String, Object?>{
        'page': 1,
        'isEnd': true,
        'data': <Object?>[
          <String, Object?>{
            'id': plugin.platform,
            'title': '${plugin.platform} lyric',
          },
        ],
      });
    } finally {
      _activeSearches -= 1;
    }
  }
}
