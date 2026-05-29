import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/domain/audio_player_service.dart';
import 'package:robyne/features/player/domain/media_source.dart';
import 'package:robyne/features/player/domain/playback_item.dart';

void main() {
  test(
    'A/B/A playback keeps a deduped queue and appends history in play order',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_queue_test_',
      );
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final a = await _localItem(tempDirectory, 'A.mp3');
      final b = await _localItem(tempDirectory, 'B.mp3');
      final audio = _FakeAudioPlayerService();
      final container = ProviderContainer(
        overrides: [audioPlayerServiceProvider.overrideWithValue(audio)],
      );
      addTearDown(container.dispose);
      await container.read(playerControllerProvider.future);
      final controller = container.read(playerControllerProvider.notifier);

      await controller.playItem(a);
      await controller.playItem(b);
      await controller.playItem(a);

      final state = container.read(playerControllerProvider).value!;
      expect(state.queue.map((item) => item.title), <String>['A', 'B']);
      expect(state.currentItem?.title, 'A');
      expect(state.history.map((entry) => entry.item.title), <String>[
        'A',
        'B',
        'A',
      ]);
    },
  );

  test(
    'removing the current queue item or clearing the queue stops playback',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_queue_remove_test_',
      );
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final a = await _localItem(tempDirectory, 'A.mp3');
      final b = await _localItem(tempDirectory, 'B.mp3');
      final audio = _FakeAudioPlayerService();
      final container = ProviderContainer(
        overrides: [audioPlayerServiceProvider.overrideWithValue(audio)],
      );
      addTearDown(container.dispose);
      await container.read(playerControllerProvider.future);
      final controller = container.read(playerControllerProvider.notifier);

      await controller.playItem(a);
      await controller.playItem(b);
      final stopCountBeforeRemove = audio.stopCount;
      await controller.removeFromQueue(b.id);
      expect(audio.stopCount, stopCountBeforeRemove + 1);

      await controller.playItem(a);
      final stopCountBeforeClear = audio.stopCount;
      await controller.clearQueue();
      expect(audio.stopCount, stopCountBeforeClear + 1);
      expect(container.read(playerControllerProvider).value!.queue, isEmpty);
    },
  );

  test(
    'play modes select the next item with sequence, loop, random, and single-loop semantics',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_modes_test_',
      );
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final a = await _localItem(tempDirectory, 'A.mp3');
      final b = await _localItem(tempDirectory, 'B.mp3');
      final audio = _FakeAudioPlayerService();
      final container = ProviderContainer(
        overrides: [audioPlayerServiceProvider.overrideWithValue(audio)],
      );
      addTearDown(container.dispose);
      await container.read(playerControllerProvider.future);
      final controller = container.read(playerControllerProvider.notifier);

      await controller.playItem(a);
      await controller.playItem(b);
      await controller.playNext();
      expect(
        container.read(playerControllerProvider).value!.currentItem,
        isNull,
      );

      await controller.playItem(a);
      await controller.playItem(b);
      await controller.setPlaybackMode(PlaybackMode.allLoop);
      await controller.playNext();
      expect(
        container.read(playerControllerProvider).value!.currentItem?.title,
        'A',
      );

      await controller.setPlaybackMode(PlaybackMode.random);
      await controller.playNext();
      expect(
        container.read(playerControllerProvider).value!.currentItem?.title,
        'B',
      );

      await controller.setPlaybackMode(PlaybackMode.singleLoop);
      final historyCount = container
          .read(playerControllerProvider)
          .value!
          .history
          .length;
      await controller.handlePlaybackCompleted();
      expect(
        container.read(playerControllerProvider).value!.currentItem?.title,
        'B',
      );
      expect(
        container.read(playerControllerProvider).value!.history.length,
        historyCount,
      );
    },
  );

  test(
    'completed player snapshots advance playback according to the selected mode',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_completed_mode_test_',
      );
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final a = await _localItem(tempDirectory, 'A.mp3');
      final b = await _localItem(tempDirectory, 'B.mp3');
      final audio = _FakeAudioPlayerService();
      final container = ProviderContainer(
        overrides: [audioPlayerServiceProvider.overrideWithValue(audio)],
      );
      addTearDown(container.dispose);
      await container.read(playerControllerProvider.future);
      container.listen(playbackCompletionListenerProvider, (_, _) {});
      final controller = container.read(playerControllerProvider.notifier);

      await controller.playItem(a);
      await controller.playItem(b);
      await controller.setPlaybackMode(PlaybackMode.allLoop);

      audio.emit(const PlayerSnapshot(completed: true));
      for (var attempt = 0; attempt < 10; attempt += 1) {
        await Future<void>.delayed(Duration.zero);
        if (container
                .read(playerControllerProvider)
                .value!
                .currentItem
                ?.title ==
            'A') {
          break;
        }
      }

      expect(
        container.read(playerControllerProvider).value!.currentItem?.title,
        'A',
      );
    },
  );

  test(
    'random playback uses an injectable random source instead of a fixed first item',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_random_mode_test_',
      );
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final a = await _localItem(tempDirectory, 'A.mp3');
      final b = await _localItem(tempDirectory, 'B.mp3');
      final c = await _localItem(tempDirectory, 'C.mp3');
      final audio = _FakeAudioPlayerService();
      final container = ProviderContainer(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(audio),
          playbackRandomProvider.overrideWithValue(_FixedRandom(1)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(playerControllerProvider.future);
      final controller = container.read(playerControllerProvider.notifier);

      await controller.playItem(a);
      await controller.playItem(b);
      await controller.playItem(c);
      await controller.playItem(b);
      await controller.setPlaybackMode(PlaybackMode.random);
      await controller.playNext();

      expect(
        container.read(playerControllerProvider).value!.currentItem?.title,
        'C',
      );
    },
  );

  test('history keeps the newest 1000 entries', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_history_limit_test_',
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

    for (var index = 0; index < 1005; index += 1) {
      await controller.playItem(await _localItem(tempDirectory, '$index.mp3'));
    }

    final history = container.read(playerControllerProvider).value!.history;
    expect(history.length, 1000);
    expect(history.first.item.title, '5');
    expect(history.last.item.title, '1004');
  });
}

class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final int value;

  @override
  bool nextBool() => value.isEven;

  @override
  double nextDouble() => value.toDouble();

  @override
  int nextInt(int max) => value % max;
}

Future<PlaybackItem> _localItem(Directory directory, String name) async {
  final file = File('${directory.path}/$name');
  await file.writeAsBytes(<int>[1, 2, 3]);
  return PlaybackItem.local(path: file.path);
}

class _FakeAudioPlayerService implements AudioPlayerService {
  final _controller = StreamController<PlayerSnapshot>.broadcast();
  final playedUrls = <String>[];
  int stopCount = 0;
  PlayerSnapshot _snapshot = const PlayerSnapshot();

  @override
  PlayerSnapshot get snapshot => _snapshot;

  @override
  Stream<PlayerSnapshot> get snapshots async* {
    yield _snapshot;
    yield* _controller.stream;
  }

  void emit(PlayerSnapshot snapshot) {
    _snapshot = snapshot;
    _controller.add(snapshot);
  }

  @override
  Future<Result<void>> play(
    MediaSource source, {
    Duration startPosition = Duration.zero,
    Duration expectedDuration = Duration.zero,
  }) async {
    playedUrls.add(source.url);
    return const Ok(null);
  }

  @override
  Future<Result<void>> pause() async => const Ok(null);

  @override
  Future<Result<void>> resume() async => const Ok(null);

  @override
  Future<Result<void>> seek(Duration position) async => const Ok(null);

  @override
  Future<Result<void>> setVolume(double volume) async => const Ok(null);

  @override
  Future<Result<void>> stop() async {
    stopCount += 1;
    return const Ok(null);
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
