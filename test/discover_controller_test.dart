import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/errors/app_error.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/discover/application/discover_controller.dart';
import 'package:robyne/features/plugin/application/plugin_providers.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/domain/plugin_discovery_executor.dart';

void main() {
  test('syncs enabled plugins and loads rankings', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_discover_controller_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final pluginPath = await _writePluginFile(tempDirectory, 'discover.js');
    final executor = _FakePluginDiscoveryExecutor();
    final container = ProviderContainer(
      overrides: [pluginDiscoveryExecutorProvider.overrideWithValue(executor)],
    );
    addTearDown(container.dispose);

    final controller = container.read(discoverControllerProvider.notifier);
    await controller.syncPlugins(<PluginDefinition>[
      _plugin('plugin-a', 'Source A', pluginPath),
      _plugin('plugin-b', 'Disabled', pluginPath, enabled: false),
    ]);

    final state = container.read(discoverControllerProvider);
    expect(state.selectedPluginId, 'plugin-a');
    expect(state.topListGroups.single.items.single.title, 'Top 50');
    expect(executor.topListsCalls, 1);
  });

  test('loads hot playlists and paginates playlist detail', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_discover_controller_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final pluginPath = await _writePluginFile(tempDirectory, 'discover.js');
    final executor = _FakePluginDiscoveryExecutor();
    final container = ProviderContainer(
      overrides: [pluginDiscoveryExecutorProvider.overrideWithValue(executor)],
    );
    addTearDown(container.dispose);

    final controller = container.read(discoverControllerProvider.notifier);
    await controller.syncPlugins(<PluginDefinition>[
      _plugin('plugin-a', 'Source A', pluginPath),
    ]);
    await controller.selectSurface(DiscoverSurface.hotPlaylists);

    var state = container.read(discoverControllerProvider);
    expect(state.selectedSheetTag?.title, 'Mood');
    expect(state.hotPlaylistItems.single.title, 'Mood Page 1');

    await controller.loadMoreHotPlaylists();
    state = container.read(discoverControllerProvider);
    expect(state.hotPlaylistItems.map((item) => item.title), <String>[
      'Mood Page 1',
      'Mood Page 2',
    ]);

    await controller.openCollection(state.hotPlaylistItems.first);
    state = container.read(discoverControllerProvider);
    expect(state.detail?.items.single.title, 'Sheet Song 1');

    await controller.loadMoreDetail();
    state = container.read(discoverControllerProvider);
    expect(state.detail?.items.map((item) => item.title), <String>[
      'Sheet Song 1',
      'Sheet Song 2',
    ]);
    expect(executor.musicSheetInfoPages, <int>[1, 2]);
  });

  test('reports unsupported plugin methods as plugin-owned errors', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_discover_controller_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final pluginPath = await _writePluginFile(tempDirectory, 'discover.js');
    final executor = _FakePluginDiscoveryExecutor()
      ..recommendSheetTagsResult = const Failure(
        AppError(
          code: 'plugin.runtime_error',
          message: 'Plugin method not found: getRecommendSheetTags',
        ),
      );
    final container = ProviderContainer(
      overrides: [pluginDiscoveryExecutorProvider.overrideWithValue(executor)],
    );
    addTearDown(container.dispose);

    final controller = container.read(discoverControllerProvider.notifier);
    await controller.syncPlugins(<PluginDefinition>[
      _plugin('plugin-a', 'fixture-a', pluginPath),
    ]);
    await controller.selectSurface(DiscoverSurface.hotPlaylists);

    final error = container.read(discoverControllerProvider).hotPlaylistsError;
    expect(error?.code, 'plugin.method_unsupported');
    expect(
      error?.message,
      contains(
        'fixture-a plugin does not expose getRecommendSheetTags, so hot playlist tags is unavailable',
      ),
    );
    expect(error?.message, contains('Check whether the plugin is outdated'));
  });

  test(
    'reports plugin-owned failures when discovery method execution breaks',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_discover_controller_',
      );
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final pluginPath = await _writePluginFile(tempDirectory, 'discover.js');
      final executor = _FakePluginDiscoveryExecutor()
        ..topListDetailResult = const Failure(
          AppError(
            code: 'plugin.runtime_error',
            message: 'Plugin method getTopListDetail failed.',
          ),
        );
      final container = ProviderContainer(
        overrides: [
          pluginDiscoveryExecutorProvider.overrideWithValue(executor),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(discoverControllerProvider.notifier);
      await controller.syncPlugins(<PluginDefinition>[
        _plugin('plugin-a', 'fixture-a', pluginPath),
      ]);
      final collection = container
          .read(discoverControllerProvider)
          .topListGroups
          .single
          .items
          .single;

      await controller.openCollection(collection);

      final error = container.read(discoverControllerProvider).detailError;
      expect(error?.code, 'plugin.runtime_error');
      expect(
        error?.message,
        contains('fixture-a plugin failed while calling getTopListDetail'),
      );
      expect(
        error?.message,
        contains('Check whether the plugin is outdated or broken'),
      );
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

class _FakePluginDiscoveryExecutor implements PluginDiscoveryExecutor {
  int topListsCalls = 0;
  final List<int> recommendSheetPages = <int>[];
  final List<int> musicSheetInfoPages = <int>[];
  Result<Object?>? topListDetailResult;
  Result<Object?>? recommendSheetTagsResult;

  @override
  Future<Result<Object?>> getTopLists({
    required PluginDefinition plugin,
    required String source,
  }) async {
    topListsCalls += 1;
    return const Ok(<Object?>[
      <String, Object?>{
        'title': 'Official',
        'data': <Object?>[
          <String, Object?>{'id': 'top-1', 'title': 'Top 50'},
        ],
      },
    ]);
  }

  @override
  Future<Result<Object?>> getTopListDetail({
    required PluginDefinition plugin,
    required String source,
    required Map<String, Object?> topList,
  }) async {
    final result = topListDetailResult;
    if (result != null) {
      return result;
    }
    return const Ok(<String, Object?>{
      'musicList': <Object?>[
        <String, Object?>{'id': 'top-song', 'title': 'Rank Song'},
      ],
    });
  }

  @override
  Future<Result<Object?>> getRecommendSheetTags({
    required PluginDefinition plugin,
    required String source,
  }) async {
    final result = recommendSheetTagsResult;
    if (result != null) {
      return result;
    }
    return const Ok(<String, Object?>{
      'pinned': <Object?>[
        <String, Object?>{'id': 'mood', 'title': 'Mood'},
      ],
      'data': <Object?>[
        <String, Object?>{
          'title': 'Scenes',
          'data': <Object?>[
            <String, Object?>{'id': 'work', 'title': 'Work'},
          ],
        },
      ],
    });
  }

  @override
  Future<Result<Object?>> getRecommendSheetsByTag({
    required PluginDefinition plugin,
    required String source,
    required Map<String, Object?> tag,
    required int page,
  }) async {
    recommendSheetPages.add(page);
    return Ok(<String, Object?>{
      'page': page,
      'isEnd': page >= 2,
      'data': <Object?>[
        <String, Object?>{
          'id': 'sheet-$page',
          'title': '${tag['title']} Page $page',
          'artist': 'Editor',
        },
      ],
    });
  }

  @override
  Future<Result<Object?>> getMusicSheetInfo({
    required PluginDefinition plugin,
    required String source,
    required Map<String, Object?> sheetItem,
    required int page,
  }) async {
    musicSheetInfoPages.add(page);
    return Ok(<String, Object?>{
      'page': page,
      'isEnd': page >= 2,
      'musicList': <Object?>[
        <String, Object?>{
          'id': 'sheet-song-$page',
          'title': 'Sheet Song $page',
        },
      ],
    });
  }
}
