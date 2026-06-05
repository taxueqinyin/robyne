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
  _FakeLyricSearchExecutor({this.searchDelay = Duration.zero});

  final Duration searchDelay;
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
