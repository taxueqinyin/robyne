import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/core/storage/local_file_store.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/application/player_state_repository.dart';
import 'package:robyne/features/player/domain/audio_player_service.dart';
import 'package:robyne/features/player/domain/media_source.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/player/infrastructure/local_audio_cache_service.dart';
import 'package:robyne/features/plugin/application/plugin_providers.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/domain/plugin_repository.dart';
import 'package:robyne/features/plugin/domain/plugin_runtime.dart';
import 'package:robyne/features/search/domain/music_item.dart';

void main() {
  test(
    'late media resolution from an old play request cannot replace newer playback',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_player_test_',
      );
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final slowPath = await _writePluginFile(tempDirectory, 'slow.js');
      final fastPath = await _writePluginFile(tempDirectory, 'fast.js');
      final slowCompleter = Completer<void>();
      final runtimeFactory = _FakeRuntimeFactory(slowCompleter);
      final audio = _FakeAudioPlayerService();

      final container = ProviderContainer(
        overrides: [
          pluginRepositoryProvider.overrideWithValue(
            _FakePluginRepository(<PluginDefinition>[
              _plugin('slow', 'Slow', slowPath),
              _plugin('fast', 'Fast', fastPath),
            ]),
          ),
          pluginRuntimeFactoryProvider.overrideWithValue(runtimeFactory),
          audioPlayerServiceProvider.overrideWithValue(audio),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(playerControllerProvider.notifier);
      final slowPlay = controller.playFromPlugin(_musicItem('Slow'));
      await runtimeFactory.waitForSlowRuntimeStarted();

      await controller.playFromPlugin(_musicItem('Fast'));
      expect(audio.playedUrls, <String>['https://example.com/Fast.mp3']);

      slowCompleter.complete();
      await slowPlay;

      expect(audio.playedUrls, <String>['https://example.com/Fast.mp3']);
      expect(audio.stopCount, 2);
    },
  );

  test('pause and resume delegate to the audio service', () async {
    final audio = _FakeAudioPlayerService();
    final container = ProviderContainer(
      overrides: [audioPlayerServiceProvider.overrideWithValue(audio)],
    );
    addTearDown(container.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    await controller.pause();
    await controller.resume();

    expect(audio.pauseCount, 1);
    expect(audio.resumeCount, 1);
  });

  test('playing a new item keeps the saved volume applied', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_player_volume_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final audio = _FakeAudioPlayerService();
    final container = ProviderContainer(
      overrides: [audioPlayerServiceProvider.overrideWithValue(audio)],
    );
    addTearDown(container.dispose);
    await container.read(playerControllerProvider.future);
    final controller = container.read(playerControllerProvider.notifier);

    await controller.setVolume(37);
    await controller.playItem(await _localItem(tempDirectory, 'A.mp3'));

    expect(audio.volumeCalls.sublist(audio.volumeCalls.length - 2), <double>[
      37,
      37,
    ]);
    expect(container.read(playerControllerProvider).value!.volume, 37);
  });

  test('restored current item can be played from its saved position', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_player_restore_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final item = await _localItem(tempDirectory, 'A.mp3');
    final repository = _FakePlayerStateRepository(
      PlayerControllerState(
        queue: <PlaybackItem>[item],
        currentItem: item,
        volume: 41,
        lastPosition: const Duration(seconds: 23),
      ),
    );
    final audio = _FakeAudioPlayerService();
    final container = ProviderContainer(
      overrides: [
        audioPlayerServiceProvider.overrideWithValue(audio),
        playerStateRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(playerControllerProvider.future);

    await container
        .read(playerControllerProvider.notifier)
        .resumeOrPlayCurrent();

    expect(audio.playedUrls, <String>[item.localPath!]);
    expect(audio.playStartPositions, <Duration>[const Duration(seconds: 23)]);
    expect(audio.volumeCalls, <double>[41, 41]);
  });

  test('empty startup snapshot does not clear restored progress', () async {
    final item = PlaybackItem.plugin(
      platform: 'Test',
      musicId: 'A',
      title: 'A',
      raw: const <String, Object?>{'id': 'A'},
    );
    final repository = _FakePlayerStateRepository(
      PlayerControllerState(
        queue: <PlaybackItem>[item],
        currentItem: item,
        lastPosition: const Duration(seconds: 65),
        lastDuration: const Duration(minutes: 4),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        audioPlayerServiceProvider.overrideWithValue(_FakeAudioPlayerService()),
        playerStateRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(playerControllerProvider.future);

    container
        .read(playerControllerProvider.notifier)
        .syncSnapshot(const PlayerSnapshot());

    final state = container.read(playerControllerProvider).value!;
    expect(state.lastPosition, const Duration(seconds: 65));
    expect(state.lastDuration, const Duration(minutes: 4));
  });

  test(
    'initial zero snapshot cannot replace a pending restored position',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_player_restore_snapshot_test_',
      );
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final item = await _localItem(tempDirectory, 'A.mp3');
      final repository = _FakePlayerStateRepository(
        PlayerControllerState(
          queue: <PlaybackItem>[item],
          currentItem: item,
          lastPosition: const Duration(seconds: 50),
          lastDuration: const Duration(minutes: 3),
        ),
      );
      final audio = _FakeAudioPlayerService();
      final container = ProviderContainer(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(audio),
          playerStateRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(playerControllerProvider.future);

      await container
          .read(playerControllerProvider.notifier)
          .resumeOrPlayCurrent();
      container
          .read(playerControllerProvider.notifier)
          .syncSnapshot(
            PlayerSnapshot(
              currentSource: MediaSource(url: item.localPath!),
              position: Duration.zero,
              duration: const Duration(minutes: 3),
            ),
          );

      expect(
        container.read(playerControllerProvider).value!.lastPosition,
        const Duration(seconds: 50),
      );
      expect(
        container.read(playerControllerProvider).value!.restoreTargetPosition,
        const Duration(seconds: 50),
      );

      container
          .read(playerControllerProvider.notifier)
          .syncSnapshot(
            PlayerSnapshot(
              currentSource: MediaSource(url: item.localPath!),
              position: const Duration(seconds: 50),
              duration: const Duration(minutes: 3),
            ),
          );
      expect(
        container.read(playerControllerProvider).value!.lastPosition,
        const Duration(seconds: 50),
      );
      expect(
        container.read(playerControllerProvider).value!.restoreTargetPosition,
        const Duration(seconds: 50),
      );

      container
          .read(playerControllerProvider.notifier)
          .syncSnapshot(
            PlayerSnapshot(
              currentSource: MediaSource(url: item.localPath!),
              position: Duration.zero,
              duration: const Duration(minutes: 3),
            ),
          );
      expect(
        container.read(playerControllerProvider).value!.lastPosition,
        const Duration(seconds: 50),
      );
      expect(
        container.read(playerControllerProvider).value!.restoreTargetPosition,
        const Duration(seconds: 50),
      );

      container
          .read(playerControllerProvider.notifier)
          .syncSnapshot(
            PlayerSnapshot(
              currentSource: MediaSource(url: item.localPath!),
              position: const Duration(seconds: 51),
              duration: const Duration(minutes: 3),
            ),
          );

      expect(
        container.read(playerControllerProvider).value!.lastPosition,
        const Duration(seconds: 50),
      );
      expect(
        container.read(playerControllerProvider).value!.restoreTargetPosition,
        const Duration(seconds: 50),
      );

      container
          .read(playerControllerProvider.notifier)
          .syncSnapshot(
            PlayerSnapshot(
              currentSource: MediaSource(url: item.localPath!),
              position: const Duration(seconds: 52),
              duration: const Duration(minutes: 3),
            ),
          );

      expect(
        container.read(playerControllerProvider).value!.lastPosition,
        const Duration(seconds: 50),
      );
      expect(
        container.read(playerControllerProvider).value!.restoreTargetPosition,
        const Duration(seconds: 50),
      );

      await Future<void>.delayed(const Duration(milliseconds: 1600));
      container
          .read(playerControllerProvider.notifier)
          .syncSnapshot(
            PlayerSnapshot(
              currentSource: MediaSource(url: item.localPath!),
              position: const Duration(seconds: 53),
              duration: const Duration(minutes: 3),
            ),
          );

      expect(
        container.read(playerControllerProvider).value!.lastPosition,
        const Duration(seconds: 53),
      );
      expect(
        container.read(playerControllerProvider).value!.restoreTargetPosition,
        Duration.zero,
      );
    },
  );

  test('zero duration snapshot cannot clear restored duration', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_player_restore_duration_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final item = await _localItem(tempDirectory, 'A.mp3');
    final repository = _FakePlayerStateRepository(
      PlayerControllerState(
        queue: <PlaybackItem>[item],
        currentItem: item,
        lastPosition: const Duration(seconds: 50),
        lastDuration: const Duration(minutes: 3),
      ),
    );
    final audio = _FakeAudioPlayerService();
    final container = ProviderContainer(
      overrides: [
        audioPlayerServiceProvider.overrideWithValue(audio),
        playerStateRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(playerControllerProvider.future);

    await container
        .read(playerControllerProvider.notifier)
        .resumeOrPlayCurrent();
    container
        .read(playerControllerProvider.notifier)
        .syncSnapshot(
          PlayerSnapshot(
            currentSource: MediaSource(url: item.localPath!),
            position: const Duration(seconds: 51),
          ),
        );

    final state = container.read(playerControllerProvider).value!;
    expect(state.lastPosition, const Duration(seconds: 50));
    expect(state.lastDuration, const Duration(minutes: 3));
    expect(state.restoreTargetPosition, const Duration(seconds: 50));
  });

  test('restore guard ignores early forward position snapshots', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_player_restore_guard_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final item = await _localItem(tempDirectory, 'A.mp3');
    final repository = _FakePlayerStateRepository(
      PlayerControllerState(
        queue: <PlaybackItem>[item],
        currentItem: item,
        lastPosition: const Duration(seconds: 50),
        lastDuration: const Duration(minutes: 3),
      ),
    );
    final audio = _FakeAudioPlayerService();
    final container = ProviderContainer(
      overrides: [
        audioPlayerServiceProvider.overrideWithValue(audio),
        playerStateRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(playerControllerProvider.future);

    await container
        .read(playerControllerProvider.notifier)
        .resumeOrPlayCurrent();
    for (final position in const <Duration>[
      Duration(seconds: 51),
      Duration(seconds: 52),
    ]) {
      container
          .read(playerControllerProvider.notifier)
          .syncSnapshot(
            PlayerSnapshot(
              currentSource: MediaSource(url: item.localPath!),
              position: position,
              duration: const Duration(minutes: 3),
            ),
          );
    }

    expect(
      container.read(playerControllerProvider).value!.lastPosition,
      const Duration(seconds: 50),
    );
    expect(
      container.read(playerControllerProvider).value!.restoreTargetPosition,
      const Duration(seconds: 50),
    );

    await Future<void>.delayed(const Duration(milliseconds: 1600));
    container
        .read(playerControllerProvider.notifier)
        .syncSnapshot(
          PlayerSnapshot(
            currentSource: MediaSource(url: item.localPath!),
            position: const Duration(seconds: 53),
            duration: const Duration(minutes: 3),
          ),
        );

    expect(
      container.read(playerControllerProvider).value!.lastPosition,
      const Duration(seconds: 53),
    );
    expect(
      container.read(playerControllerProvider).value!.restoreTargetPosition,
      Duration.zero,
    );
  });

  test('restore guard ignores early duration snapshots', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_player_restore_duration_guard_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final item = await _localItem(tempDirectory, 'A.mp3');
    final repository = _FakePlayerStateRepository(
      PlayerControllerState(
        queue: <PlaybackItem>[item],
        currentItem: item,
        lastPosition: const Duration(seconds: 50),
        lastDuration: const Duration(minutes: 3),
      ),
    );
    final audio = _FakeAudioPlayerService();
    final container = ProviderContainer(
      overrides: [
        audioPlayerServiceProvider.overrideWithValue(audio),
        playerStateRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(playerControllerProvider.future);

    await container
        .read(playerControllerProvider.notifier)
        .resumeOrPlayCurrent();
    container
        .read(playerControllerProvider.notifier)
        .syncSnapshot(
          PlayerSnapshot(
            currentSource: MediaSource(url: item.localPath!),
            position: const Duration(seconds: 51),
            duration: const Duration(minutes: 3, seconds: 1),
          ),
        );

    final state = container.read(playerControllerProvider).value!;
    expect(state.lastPosition, const Duration(seconds: 50));
    expect(state.lastDuration, const Duration(minutes: 3));
    expect(state.restoreTargetPosition, const Duration(seconds: 50));
  });

  test('one second duration jitter cannot replace saved duration', () async {
    final item = PlaybackItem.plugin(
      platform: 'Test',
      musicId: 'A',
      title: 'A',
      raw: const <String, Object?>{'id': 'A'},
    );
    final container = ProviderContainer(
      overrides: [
        audioPlayerServiceProvider.overrideWithValue(_FakeAudioPlayerService()),
        playerStateRepositoryProvider.overrideWithValue(
          _FakePlayerStateRepository(
            PlayerControllerState(
              queue: <PlaybackItem>[item],
              currentItem: item,
              lastPosition: const Duration(seconds: 54),
              lastDuration: const Duration(minutes: 3),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(playerControllerProvider.future);

    container
        .read(playerControllerProvider.notifier)
        .syncSnapshot(
          const PlayerSnapshot(
            currentSource: MediaSource(url: 'https://example.com/a.mp3'),
            position: Duration(seconds: 55),
            duration: Duration(minutes: 3, seconds: 1),
          ),
        );

    final state = container.read(playerControllerProvider).value!;
    expect(state.lastPosition, const Duration(seconds: 55));
    expect(state.lastDuration, const Duration(minutes: 3));
  });

  test('plugin item duration repairs polluted saved duration', () async {
    final item = PlaybackItem.plugin(
      platform: 'Test',
      musicId: 'A',
      title: 'A',
      duration: const Duration(minutes: 3),
      raw: const <String, Object?>{'id': 'A'},
    );
    final container = ProviderContainer(
      overrides: [
        audioPlayerServiceProvider.overrideWithValue(_FakeAudioPlayerService()),
        playerStateRepositoryProvider.overrideWithValue(
          _FakePlayerStateRepository(
            PlayerControllerState(
              queue: <PlaybackItem>[item],
              currentItem: item,
              lastPosition: const Duration(seconds: 54),
              lastDuration: const Duration(minutes: 3, seconds: 1),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(playerControllerProvider.future);

    container
        .read(playerControllerProvider.notifier)
        .syncSnapshot(
          const PlayerSnapshot(
            currentSource: MediaSource(url: 'https://example.com/a.mp3'),
            position: Duration(seconds: 55),
            duration: Duration(minutes: 3, seconds: 1),
          ),
        );

    final state = container.read(playerControllerProvider).value!;
    expect(state.lastPosition, const Duration(seconds: 55));
    expect(state.lastDuration, const Duration(minutes: 3));
  });

  test(
    'cached plugin item plays without resolving remote media first',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_player_cached_plugin_test_',
      );
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final pluginPath = await _writePluginFile(tempDirectory, 'cached.js');
      final cachedFile = File('${tempDirectory.path}/cached.audio');
      await cachedFile.writeAsBytes(<int>[1, 2, 3]);
      final runtimeFactory = _CountingRuntimeFactory();
      final audio = _FakeAudioPlayerService();
      final item = PlaybackItem.plugin(
        platform: 'Cached',
        musicId: 'A',
        title: 'A',
        raw: const <String, Object?>{'id': 'A'},
      );
      final container = ProviderContainer(
        overrides: [
          pluginRepositoryProvider.overrideWithValue(
            _FakePluginRepository(<PluginDefinition>[
              _plugin('cached', 'Cached', pluginPath),
            ]),
          ),
          pluginRuntimeFactoryProvider.overrideWithValue(runtimeFactory),
          audioPlayerServiceProvider.overrideWithValue(audio),
          audioCacheServiceProvider.overrideWithValue(
            _FakeCacheService(MediaSource(url: cachedFile.path), tempDirectory),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(playerControllerProvider.notifier).playItem(item);

      expect(audio.playedUrls, <String>[cachedFile.path]);
      expect(runtimeFactory.createCount, 0);
    },
  );
}

Future<PlaybackItem> _localItem(Directory directory, String name) async {
  final file = File('${directory.path}/$name');
  await file.writeAsBytes(<int>[1, 2, 3]);
  return PlaybackItem.local(path: file.path);
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
    installedAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

MusicItem _musicItem(String platform) {
  return MusicItem(
    id: platform,
    platform: platform,
    title: platform,
    raw: <String, Object?>{'id': platform, 'title': platform},
  );
}

class _FakePlayerStateRepository implements PlayerStateRepository {
  _FakePlayerStateRepository(this.state);

  PlayerControllerState state;

  @override
  Future<PlayerControllerState> load() async => state;

  @override
  Future<void> save(PlayerControllerState state) async {
    this.state = state;
  }

  @override
  Future<void> clearHistory() async {
    state = state.copyWith(history: const <PlaybackHistoryEntry>[]);
  }
}

class _FakePluginRepository implements PluginRepository {
  _FakePluginRepository(this._plugins);

  final List<PluginDefinition> _plugins;

  @override
  Future<Result<List<PluginDefinition>>> listPlugins() async {
    return Ok(_plugins);
  }

  @override
  Future<Result<void>> deletePlugin(String id) async => const Ok(null);

  @override
  Future<Result<PluginDefinition>> importPluginFromPath(String path) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<PluginDefinition>> importPluginFromUrl(String url) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<PluginDefinition>> updateUserVariableValues(
    String id,
    Map<String, String> values,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<PluginDefinition>> setEnabled(String id, bool enabled) async {
    throw UnimplementedError();
  }
}

class _FakeRuntimeFactory implements PluginRuntimeFactory {
  _FakeRuntimeFactory(this._slowCompleter);

  final Completer<void> _slowCompleter;
  final _slowRuntimeStarted = Completer<void>();

  Future<void> waitForSlowRuntimeStarted() => _slowRuntimeStarted.future;

  @override
  Future<PluginRuntime> create() async {
    return _FakeRuntime(_slowCompleter, _slowRuntimeStarted);
  }
}

class _CountingRuntimeFactory implements PluginRuntimeFactory {
  int createCount = 0;

  @override
  Future<PluginRuntime> create() async {
    createCount += 1;
    return _CountingRuntime();
  }
}

class _CountingRuntime implements PluginRuntime {
  @override
  Future<Result<Map<String, Object?>>> loadPlugin(
    String source, {
    Map<String, String> userVariables = const <String, String>{},
  }) async {
    return const Ok(<String, Object?>{'platform': 'Cached'});
  }

  @override
  Future<Result<Object?>> callMethod(
    String method,
    List<Object?> arguments, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return const Ok(<String, Object?>{'url': 'https://example.com/cached.mp3'});
  }

  @override
  Future<void> dispose() async {}
}

class _FakeRuntime implements PluginRuntime {
  _FakeRuntime(this._slowCompleter, this._slowRuntimeStarted);

  final Completer<void> _slowCompleter;
  final Completer<void> _slowRuntimeStarted;
  String _platform = 'unknown';

  @override
  Future<Result<Map<String, Object?>>> loadPlugin(
    String source, {
    Map<String, String> userVariables = const <String, String>{},
  }) async {
    _platform = source.contains('slow') ? 'Slow' : 'Fast';
    return Ok(<String, Object?>{'platform': _platform});
  }

  @override
  Future<Result<Object?>> callMethod(
    String method,
    List<Object?> arguments, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_platform == 'Slow') {
      if (!_slowRuntimeStarted.isCompleted) {
        _slowRuntimeStarted.complete();
      }
      await _slowCompleter.future;
    }
    return Ok(<String, Object?>{'url': 'https://example.com/$_platform.mp3'});
  }

  @override
  Future<void> dispose() async {}
}

class _FakeCacheService extends LocalAudioCacheService {
  _FakeCacheService(this.cachedSource, Directory directory)
    : super(fileStore: LocalFileStore(baseDirectory: directory));

  final MediaSource? cachedSource;

  @override
  Future<Result<MediaSource?>> resolveCached(PlaybackItem item) async {
    return Ok(cachedSource);
  }

  @override
  Future<Result<MediaSource>> resolve(
    PlaybackItem item,
    MediaSource remote,
  ) async {
    return Ok(cachedSource ?? remote);
  }

  @override
  Future<Result<void>> cache(PlaybackItem item, MediaSource source) async {
    return const Ok(null);
  }
}

class _FakeAudioPlayerService implements AudioPlayerService {
  final playedUrls = <String>[];
  int stopCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  final volumeCalls = <double>[];
  final playStartPositions = <Duration>[];
  Duration? seekedTo;

  @override
  PlayerSnapshot get snapshot => const PlayerSnapshot();

  @override
  Stream<PlayerSnapshot> get snapshots => const Stream<PlayerSnapshot>.empty();

  @override
  Future<Result<void>> play(
    MediaSource source, {
    Duration startPosition = Duration.zero,
    Duration expectedDuration = Duration.zero,
  }) async {
    playedUrls.add(source.url);
    playStartPositions.add(startPosition);
    return const Ok(null);
  }

  @override
  Future<Result<void>> pause() async {
    pauseCount += 1;
    return const Ok(null);
  }

  @override
  Future<Result<void>> resume() async {
    resumeCount += 1;
    return const Ok(null);
  }

  @override
  Future<Result<void>> seek(Duration position) async {
    seekedTo = position;
    return const Ok(null);
  }

  @override
  Future<Result<void>> setVolume(double volume) async {
    volumeCalls.add(volume);
    return const Ok(null);
  }

  @override
  Future<Result<void>> stop() async {
    stopCount += 1;
    return const Ok(null);
  }

  @override
  Future<void> dispose() async {}
}
