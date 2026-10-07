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
import 'package:robyne/features/plugin/infrastructure/quickjs_plugin_runtime.dart';
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
        final runner = _BlockingMethodRunner(slowCompleter);
        final audio = _FakeAudioPlayerService();

        final container = ProviderContainer(
          overrides: [
            pluginRepositoryProvider.overrideWithValue(
              _FakePluginRepository(<PluginDefinition>[
                _plugin('slow', 'Slow', slowPath),
                _plugin('fast', 'Fast', fastPath),
              ]),
            ),
            pluginMethodRunnerProvider.overrideWithValue(runner),
            audioPlayerServiceProvider.overrideWithValue(audio),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(playerControllerProvider.notifier);
        final slowPlay = controller.playFromPlugin(_musicItem('Slow'));
        await runner.waitForSlowCallStarted();

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

  test('setVolume commits state without an eager full-state write', () async {
    final repository = _FakePlayerStateRepository(
      const PlayerControllerState(volume: 100),
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

    final pending = container
        .read(playerControllerProvider.notifier)
        .setVolume(37);

    // The slider must not wait for the platform round trip to show the new
    // value, and a drag endpoint must not flush a full transaction per frame.
    expect(container.read(playerControllerProvider).value!.volume, 37);
    await pending;
    expect(repository.saveCount, 0);
    expect(repository.state.volume, 100);
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
    'startup bridges restored rounded item and shorter saved duration',
    () async {
      final item = PlaybackItem.plugin(
        platform: 'Test',
        musicId: 'A',
        title: 'A',
        duration: const Duration(minutes: 3),
        raw: const <String, Object?>{'id': 'A'},
      );
      final repository = _FakePlayerStateRepository(
        PlayerControllerState(
          queue: <PlaybackItem>[item],
          currentItem: item,
          lastPosition: const Duration(seconds: 65),
          lastDuration: const Duration(minutes: 2, seconds: 58),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(
            _FakeAudioPlayerService(),
          ),
          playerStateRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(playerControllerProvider.future);

      expect(state.lastPosition, const Duration(seconds: 65));
      expect(state.lastDuration, const Duration(minutes: 2, seconds: 59));
      expect(
        state.currentItem?.duration,
        const Duration(minutes: 2, seconds: 59),
      );
      expect(
        state.queue.single.duration,
        const Duration(minutes: 2, seconds: 59),
      );
      expect(
        repository.state.currentItem?.duration,
        const Duration(minutes: 2, seconds: 59),
      );
      expect(
        repository.state.lastDuration,
        const Duration(minutes: 2, seconds: 59),
      );
    },
  );

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

  test('playing snapshots are periodically persisted without pause', () async {
    final item = PlaybackItem.plugin(
      platform: 'Test',
      musicId: 'A',
      title: 'A',
      duration: const Duration(minutes: 3),
      raw: const <String, Object?>{'id': 'A'},
    );
    final repository = _FakePlayerStateRepository(
      PlayerControllerState(
        queue: <PlaybackItem>[item],
        currentItem: item,
        lastPosition: const Duration(seconds: 10),
        lastDuration: const Duration(minutes: 3),
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
        .syncSnapshot(
          const PlayerSnapshot(
            currentSource: MediaSource(url: 'https://example.com/a.mp3'),
            position: Duration(seconds: 45),
            duration: Duration(minutes: 3),
          ),
        );

    expect(repository.state.lastPosition, const Duration(seconds: 10));

    await Future<void>.delayed(const Duration(milliseconds: 1100));

    expect(repository.progressSaveCount, 1);
    expect(repository.state.lastPosition, const Duration(seconds: 45));
    expect(repository.state.lastDuration, const Duration(minutes: 3));
  });

  test(
    'pending playback progress is flushed when controller is disposed',
    () async {
      final item = PlaybackItem.plugin(
        platform: 'Test',
        musicId: 'A',
        title: 'A',
        duration: const Duration(minutes: 3),
        raw: const <String, Object?>{'id': 'A'},
      );
      final repository = _FakePlayerStateRepository(
        PlayerControllerState(
          queue: <PlaybackItem>[item],
          currentItem: item,
          lastPosition: const Duration(seconds: 10),
          lastDuration: const Duration(minutes: 3),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(
            _FakeAudioPlayerService(),
          ),
          playerStateRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await container.read(playerControllerProvider.future);

      container
          .read(playerControllerProvider.notifier)
          .syncSnapshot(
            const PlayerSnapshot(
              currentSource: MediaSource(url: 'https://example.com/a.mp3'),
              position: Duration(seconds: 45),
              duration: Duration(minutes: 3),
            ),
          );

      container.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(repository.progressSaveCount, 1);
      expect(repository.state.lastPosition, const Duration(seconds: 45));
    },
  );

  test(
    'rounded plugin duration and shorter probed duration are bridged',
    () async {
      final item = PlaybackItem.plugin(
        platform: 'Test',
        musicId: 'A',
        title: 'A',
        duration: const Duration(minutes: 3),
        raw: const <String, Object?>{'id': 'A'},
      );
      final repository = _FakePlayerStateRepository(
        PlayerControllerState(
          queue: <PlaybackItem>[item],
          currentItem: item,
          lastPosition: const Duration(seconds: 54),
          lastDuration: const Duration(minutes: 3),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(
            _FakeAudioPlayerService(),
          ),
          playerStateRepositoryProvider.overrideWithValue(repository),
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
              duration: Duration(minutes: 2, seconds: 58),
            ),
          );

      final state = container.read(playerControllerProvider).value!;
      expect(state.lastPosition, const Duration(seconds: 55));
      expect(state.lastDuration, const Duration(minutes: 2, seconds: 59));
      expect(
        state.currentItem?.duration,
        const Duration(minutes: 2, seconds: 59),
      );
      expect(
        state.queue.single.duration,
        const Duration(minutes: 2, seconds: 59),
      );

      await container.read(playerControllerProvider.notifier).pause();

      expect(
        repository.state.currentItem?.duration,
        const Duration(minutes: 2, seconds: 59),
      );
      expect(
        repository.state.lastDuration,
        const Duration(minutes: 2, seconds: 59),
      );
    },
  );

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

  test('plugin playback prefers pluginId before platform fallback', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_player_plugin_id_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final alphaPath = await _writePluginFile(tempDirectory, 'alpha.js');
    final betaPath = await _writePluginFile(tempDirectory, 'beta.js');
    final audio = _FakeAudioPlayerService();
    final container = ProviderContainer(
      overrides: [
        pluginRepositoryProvider.overrideWithValue(
          _FakePluginRepository(<PluginDefinition>[
            _plugin('alpha', 'Shared', alphaPath),
            _plugin('beta', 'Shared', betaPath),
          ]),
        ),
        pluginMethodRunnerProvider.overrideWithValue(
          _SourceAwareMethodRunner(),
        ),
        audioPlayerServiceProvider.overrideWithValue(audio),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(playerControllerProvider.notifier)
        .playFromPlugin(_musicItem('Shared', pluginId: 'beta', id: 'song-1'));

    expect(audio.playedUrls, <String>['https://example.com/beta.mp3']);
  });
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

MusicItem _musicItem(String platform, {String? pluginId, String? id}) {
  return MusicItem(
    id: id ?? platform,
    pluginId: pluginId ?? platform.toLowerCase(),
    platform: platform,
    title: platform,
    raw: <String, Object?>{'id': id ?? platform, 'title': platform},
  );
}

class _FakePlayerStateRepository implements PlayerStateRepository {
  _FakePlayerStateRepository(this.state);

  PlayerControllerState state;
  int saveCount = 0;
  int progressSaveCount = 0;

  @override
  Future<PlayerControllerState> load() async => state;

  @override
  Future<void> save(PlayerControllerState state) async {
    saveCount += 1;
    this.state = state;
  }

  @override
  Future<void> savePlaybackProgress(PlayerControllerState state) async {
    progressSaveCount += 1;
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

class _CountingRuntimeFactory extends PluginRuntimeFactory {
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

/// Resolves a URL from whichever plugin source it was handed, so the test can
/// prove the player picked the right plugin when several share a platform.
class _SourceAwareMethodRunner implements PluginMethodRunner {
  @override
  Future<Result<Object?>> call({
    required PluginDefinition plugin,
    required String source,
    required String method,
    required List<Object?> arguments,
  }) async {
    final key = source.contains('beta') ? 'beta' : 'alpha';
    return Ok(<String, Object?>{'url': 'https://example.com/$key.mp3'});
  }
}

/// Blocks one plugin's resolution until released, so a slow response can be
/// overlapped by a newer play request.
class _BlockingMethodRunner implements PluginMethodRunner {
  _BlockingMethodRunner(this._slowCompleter);

  final Completer<void> _slowCompleter;
  final _slowCallStarted = Completer<void>();

  Future<void> waitForSlowCallStarted() => _slowCallStarted.future;

  @override
  Future<Result<Object?>> call({
    required PluginDefinition plugin,
    required String source,
    required String method,
    required List<Object?> arguments,
  }) async {
    if (plugin.platform == 'Slow') {
      _slowCallStarted.complete();
      await _slowCompleter.future;
      return Ok(<String, Object?>{'url': 'https://example.com/Slow.mp3'});
    }
    return Ok(<String, Object?>{'url': 'https://example.com/${plugin.platform}.mp3'});
  }
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
