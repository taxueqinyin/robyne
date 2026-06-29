import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/database/app_database.dart' as db;
import 'package:robyne/core/database/legacy_storage_migration.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/core/storage/local_file_store.dart';
import 'package:robyne/features/library/infrastructure/local_music_repository.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/application/player_state_repository.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/player/infrastructure/local_audio_cache_service.dart';
import 'package:robyne/features/plugin/domain/plugin_runtime.dart';
import 'package:robyne/features/plugin/infrastructure/local_plugin_repository.dart';
import 'package:robyne/features/plugin/infrastructure/music_free_compat_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

void main() {
  test('migrates legacy JSON and preferences into Drift once', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SharedPreferencesAsyncPlatform.instance = _MemoryPreferencesPlatform();
    final preferences = SharedPreferencesAsync();
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_legacy_migration_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final fileStore = LocalFileStore(baseDirectory: tempDirectory);
    final database = db.AppDatabase.memory();
    addTearDown(database.close);

    final localItem = PlaybackItem.local(path: '${tempDirectory.path}/A.mp3');
    await File(localItem.localPath!).writeAsBytes(<int>[1, 2, 3]);
    final pluginItem = PlaybackItem.plugin(
      platform: 'Test',
      musicId: 'B',
      title: 'B',
      raw: const <String, Object?>{'id': 'B'},
    );
    await File(
      '${(await fileStore.dataDirectory()).path}/local_music.v1.json',
    ).writeAsString(jsonEncode(<Object?>[localItem.toJson()]));
    await File(
      '${(await fileStore.dataDirectory()).path}/player_state.v1.json',
    ).writeAsString(
      jsonEncode(
        PlayerControllerState(
          queue: <PlaybackItem>[localItem, pluginItem],
          history: <PlaybackHistoryEntry>[
            PlaybackHistoryEntry(item: pluginItem, playedAt: DateTime(2026)),
          ],
          currentItem: pluginItem,
          playbackMode: PlaybackMode.random,
          volume: 35,
          lastPosition: const Duration(seconds: 9),
          lastDuration: const Duration(minutes: 3),
        ).toJson(),
      ),
    );
    final cacheFile = File(
      '${(await fileStore.cacheDirectory()).path}/B.audio',
    );
    await cacheFile.writeAsBytes(<int>[1, 2, 3]);
    await File(
      '${(await fileStore.cacheDirectory()).path}/audio_cache.v1.json',
    ).writeAsString(
      jsonEncode(<Object?>[
        <String, Object?>{
          'itemId': pluginItem.id,
          'sourceUrl': 'https://example.com/B.mp3',
          'path': cacheFile.path,
          'size': 3,
          'createdAt': DateTime(2026).toIso8601String(),
          'lastAccessedAt': DateTime(2026).toIso8601String(),
        },
      ]),
    );
    await preferences.setString(
      'plugins.v1',
      jsonEncode(<Object?>[
        <String, Object?>{
          'id': 'Test@plugin.js',
          'platform': 'Test',
          'sourcePath': 'plugin.js',
          'enabled': true,
          'installedAt': DateTime(2026).toIso8601String(),
          'updatedAt': DateTime(2026).toIso8601String(),
          'supportedSearchTypes': <Object?>['music', 'lyric'],
        },
      ]),
    );

    final migration = LegacyStorageMigration(
      database: database,
      fileStore: fileStore,
      preferences: preferences,
    );
    await migration.ensureMigrated();
    await migration.ensureMigrated();

    final playerState = await PlayerStateRepository(database: database).load();
    final library = await LocalMusicRepository(
      fileStore: fileStore,
      database: database,
    ).listTracks();
    final plugins = await LocalPluginRepository(
      fileStore: fileStore,
      preferences: preferences,
      database: database,
      runtimeFactory: _FakeRuntimeFactory(),
      compatAdapter: MusicFreeCompatAdapter(),
    ).listPlugins();
    final cached = await LocalAudioCacheService(
      fileStore: fileStore,
      database: database,
    ).resolveCached(pluginItem);

    expect(playerState.currentItem?.id, pluginItem.id);
    expect(playerState.playbackMode, PlaybackMode.random);
    expect(library.fold((tracks) => tracks.single.id, (_) => ''), localItem.id);
    expect((plugins as Ok).value.single.platform, 'Test');
    expect(cached.fold((source) => source?.url, (_) => null), cacheFile.path);
  });

  test(
    'malformed legacy player state does not block other migration',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      SharedPreferencesAsyncPlatform.instance = _MemoryPreferencesPlatform();
      final preferences = SharedPreferencesAsync();
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_malformed_legacy_migration_test_',
      );
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final fileStore = LocalFileStore(baseDirectory: tempDirectory);
      final database = db.AppDatabase.memory();
      addTearDown(database.close);

      await File(
        '${(await fileStore.dataDirectory()).path}/player_state.v1.json',
      ).writeAsString('{"queue":[]}{"broken":true}');
      await preferences.setString(
        'plugins.v1',
        jsonEncode(<Object?>[
          <String, Object?>{
            'id': 'Test@plugin.js',
            'platform': 'Test',
            'sourcePath': 'plugin.js',
            'enabled': true,
            'installedAt': DateTime(2026).toIso8601String(),
            'updatedAt': DateTime(2026).toIso8601String(),
            'supportedSearchTypes': <Object?>['music'],
          },
        ]),
      );

      final migration = LegacyStorageMigration(
        database: database,
        fileStore: fileStore,
        preferences: preferences,
      );
      await migration.ensureMigrated();

      final plugins = await LocalPluginRepository(
        fileStore: fileStore,
        preferences: preferences,
        database: database,
        runtimeFactory: _FakeRuntimeFactory(),
        compatAdapter: MusicFreeCompatAdapter(),
      ).listPlugins();
      final playerState = await PlayerStateRepository(
        database: database,
      ).load();

      expect((plugins as Ok).value.single.platform, 'Test');
      expect(playerState.queue, isEmpty);
      expect(playerState.currentItem, isNull);
    },
  );
}

class _FakeRuntimeFactory extends PluginRuntimeFactory {
  @override
  Future<PluginRuntime> create() async {
    throw UnimplementedError();
  }
}

final class _MemoryPreferencesPlatform extends SharedPreferencesAsyncPlatform {
  final Map<String, Object> _values = <String, Object>{};

  @override
  Future<void> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    _values[key] = value;
  }

  @override
  Future<String?> getString(
    String key,
    SharedPreferencesOptions options,
  ) async {
    final value = _values[key];
    return value is String ? value : null;
  }

  @override
  Future<Map<String, Object>> getPreferences(
    GetPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    return Map<String, Object>.from(_values);
  }

  @override
  Future<Set<String>> getKeys(
    GetPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    return _values.keys.toSet();
  }

  @override
  Future<void> clear(
    ClearPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    _values.clear();
  }

  @override
  Future<void> setBool(
    String key,
    bool value,
    SharedPreferencesOptions options,
  ) async {
    _values[key] = value;
  }

  @override
  Future<bool?> getBool(String key, SharedPreferencesOptions options) async {
    final value = _values[key];
    return value is bool ? value : null;
  }

  @override
  Future<void> setDouble(
    String key,
    double value,
    SharedPreferencesOptions options,
  ) async {
    _values[key] = value;
  }

  @override
  Future<double?> getDouble(
    String key,
    SharedPreferencesOptions options,
  ) async {
    final value = _values[key];
    return value is double ? value : null;
  }

  @override
  Future<void> setInt(
    String key,
    int value,
    SharedPreferencesOptions options,
  ) async {
    _values[key] = value;
  }

  @override
  Future<int?> getInt(String key, SharedPreferencesOptions options) async {
    final value = _values[key];
    return value is int ? value : null;
  }

  @override
  Future<void> setStringList(
    String key,
    List<String> value,
    SharedPreferencesOptions options,
  ) async {
    _values[key] = value;
  }

  @override
  Future<List<String>?> getStringList(
    String key,
    SharedPreferencesOptions options,
  ) async {
    final value = _values[key];
    return value is List<String> ? value : null;
  }
}
