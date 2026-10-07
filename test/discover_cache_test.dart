import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/errors/app_error.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/discover/application/discover_controller.dart';
import 'package:robyne/features/discover/infrastructure/discover_cache_store.dart';
import 'package:robyne/features/plugin/application/plugin_providers.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/domain/plugin_discovery_executor.dart';

/// Guards the review finding: switching plugins or tabs must not re-hit the
/// plugin runtime while the cached catalogue is still fresh, and the refresh
/// button must still be able to force a real request.
void main() {
  late Directory tempDirectory;
  late PluginDefinition plugin;
  late _CountingExecutor executor;
  late ProviderContainer container;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('robyne_cache_');
    final source = File('${tempDirectory.path}/plugin.js');
    await source.writeAsString('// plugin');
    plugin = PluginDefinition(
      id: 'plugin-a',
      platform: 'Source A',
      sourcePath: source.path,
      enabled: true,
      installedAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    executor = _CountingExecutor();
    container = ProviderContainer(
      overrides: [pluginDiscoveryExecutorProvider.overrideWithValue(executor)],
    );
    addTearDown(() async {
      container.dispose();
      await tempDirectory.delete(recursive: true);
    });
  });

  test('switching away and back reuses the cached rankings', () async {
    final controller = container.read(discoverControllerProvider.notifier);
    await controller.syncPlugins(<PluginDefinition>[plugin]);

    expect(executor.topListCalls, 1, reason: 'the first load must fetch');
    expect(
      container.read(discoverControllerProvider).topListGroups,
      isNotEmpty,
    );

    // Leave the destination and come back: the data is still inside the TTL,
    // so no second request is allowed.
    await controller.selectSurface(DiscoverSurface.hotPlaylists);
    await controller.selectSurface(DiscoverSurface.rankings);

    expect(
      executor.topListCalls,
      1,
      reason: 'a tab switch inside the TTL must not refetch rankings',
    );
    expect(
      container.read(discoverControllerProvider).topListGroups,
      isNotEmpty,
      reason: 'the cached rankings must still be painted',
    );
  });

  test('the refresh button still forces a real request', () async {
    final controller = container.read(discoverControllerProvider.notifier);
    await controller.syncPlugins(<PluginDefinition>[plugin]);
    expect(executor.topListCalls, 1);

    await controller.reloadCurrentSurface();

    expect(
      executor.topListCalls,
      2,
      reason: 'an explicit refresh must bypass the cache',
    );
  });

  test('a new controller can hydrate rankings from the cache store', () async {
    final store = InMemoryDiscoverCacheStore();
    final firstContainer = ProviderContainer(
      overrides: [
        pluginDiscoveryExecutorProvider.overrideWithValue(executor),
        discoverCacheStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(firstContainer.dispose);

    final first = firstContainer.read(discoverControllerProvider.notifier);
    await first.syncPlugins(<PluginDefinition>[plugin]);
    expect(executor.topListCalls, 1);

    final secondContainer = ProviderContainer(
      overrides: [
        pluginDiscoveryExecutorProvider.overrideWithValue(executor),
        discoverCacheStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(secondContainer.dispose);

    final second = secondContainer.read(discoverControllerProvider.notifier);
    await second.syncPlugins(<PluginDefinition>[plugin]);

    expect(executor.topListCalls, 1, reason: 'the disk cache must be reused');
    expect(
      secondContainer.read(discoverControllerProvider).topListGroups,
      isNotEmpty,
    );
  });

  test('switching plugins reads each plugin cache independently', () async {
    final second = PluginDefinition(
      id: 'plugin-b',
      platform: 'Source B',
      sourcePath: plugin.sourcePath,
      enabled: true,
      installedAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final controller = container.read(discoverControllerProvider.notifier);
    await controller.syncPlugins(<PluginDefinition>[plugin, second]);

    // Switch to the second plugin and back: each direction is one load, and
    // returning to the first one is a cache hit, not a third request.
    await controller.selectPlugin('plugin-b');
    expect(executor.topListCalls, 2, reason: 'a new plugin must load once');

    await controller.selectPlugin('plugin-a');
    expect(
      executor.topListCalls,
      2,
      reason: 'returning to a plugin inside the TTL must be a cache hit',
    );
  });

  test(
    'seedHomeShelf tries each plugin until one serves hot playlists',
    () async {
      final rankingOnly = PluginDefinition(
        id: 'plugin-rank-only',
        platform: 'Rank Only',
        sourcePath: plugin.sourcePath,
        enabled: true,
        installedAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      executor.failTagsFor = {'plugin-rank-only'};
      final controller = container.read(discoverControllerProvider.notifier);
      await controller.syncPlugins(<PluginDefinition>[rankingOnly, plugin]);

      await controller.seedHomeShelf();

      // The first plugin is probed and fails, the second succeeds and wins.
      // The selected plugin is left on the winner so the browser shows the
      // same shelf instead of an error.
      expect(executor.tagPluginIds, ['plugin-rank-only', 'plugin-a']);
      expect(controller.state.selectedPluginId, 'plugin-a');
      expect(controller.state.hotPlaylistItems, isNotEmpty);
    },
  );

  test(
    'seedHomeShelf leaves the selection when the first plugin works',
    () async {
      final controller = container.read(discoverControllerProvider.notifier);
      await controller.syncPlugins(<PluginDefinition>[plugin]);

      await controller.seedHomeShelf();

      expect(controller.state.selectedPluginId, 'plugin-a');
      expect(controller.state.hotPlaylistItems, isNotEmpty);
      expect(executor.tagCalls, 1);
    },
  );
}

class _CountingExecutor implements PluginDiscoveryExecutor {
  int topListCalls = 0;
  int tagCalls = 0;
  int sheetCalls = 0;

  /// Plugin ids whose `getRecommendSheetTags` should fail, standing in for the
  /// real "plugin method not found" case (fixture-a has no recommend sheets).
  Set<String> failTagsFor = <String>{};

  /// Each plugin id passed to `getRecommendSheetTags`, in call order, so a
  /// test can pin down which plugins `seedHomeShelf` probed.
  final List<String> tagPluginIds = <String>[];

  @override
  Future<Result<Object?>> getTopLists({
    required PluginDefinition plugin,
    required String source,
  }) async {
    topListCalls += 1;
    return Ok<Object?>(<Object?>[
      <String, Object?>{
        'title': 'Official',
        'list': <Object?>[
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
    return const Ok<Object?>(<String, Object?>{'musicList': <Object?>[]});
  }

  @override
  Future<Result<Object?>> getRecommendSheetTags({
    required PluginDefinition plugin,
    required String source,
  }) async {
    tagCalls += 1;
    tagPluginIds.add(plugin.id);
    if (failTagsFor.contains(plugin.id)) {
      return const Failure<Object?>(
        AppError(
          code: 'plugin.method_unsupported',
          message: 'Plugin method not found: getRecommendSheetTags',
        ),
      );
    }
    return Ok<Object?>(<String, Object?>{
      'data': <Object?>[
        <String, Object?>{
          'title': 'Scenes',
          'data': <Object?>[
            <String, Object?>{'id': 'mood', 'title': 'Mood'},
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
    sheetCalls += 1;
    return Ok<Object?>(<String, Object?>{
      'data': <Object?>[
        <String, Object?>{'id': 'sheet-1', 'title': 'Mood Page 1'},
      ],
      'isEnd': true,
    });
  }

  @override
  Future<Result<Object?>> getMusicSheetInfo({
    required PluginDefinition plugin,
    required String source,
    required Map<String, Object?> sheetItem,
    required int page,
  }) async {
    return const Ok<Object?>(<String, Object?>{'musicList': <Object?>[]});
  }
}
