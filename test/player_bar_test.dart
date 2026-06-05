import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/domain/audio_player_service.dart';
import 'package:robyne/features/player/domain/media_source.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/player/presentation/player_bar.dart';

void main() {
  testWidgets('play pause button resumes after playback is paused', (
    tester,
  ) async {
    final audio = _FakeAudioPlayerService(
      const PlayerSnapshot(
        playing: false,
        currentSource: MediaSource(url: 'https://example.com/a.mp3'),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioPlayerServiceProvider.overrideWithValue(audio)],
        child: const MaterialApp(home: Scaffold(body: PlayerBar())),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing);

    final playButton = find.widgetWithIcon(IconButton, Icons.play_arrow);
    expect(tester.widget<IconButton>(playButton).onPressed, isNotNull);

    await tester.tap(playButton);
    await tester.pump();

    expect(audio.resumeCount, 1);
  });

  testWidgets(
    'restored current item enables play button without a loaded source',
    (tester) async {
      final audio = _FakeAudioPlayerService();
      final item = PlaybackItem.plugin(
        platform: 'Test',
        musicId: 'A',
        title: 'A',
        raw: const <String, Object?>{'id': 'A'},
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerServiceProvider.overrideWithValue(audio),
            playerControllerProvider.overrideWith(
              () => _SeededPlayerController(
                PlayerControllerState(
                  queue: <PlaybackItem>[item],
                  currentItem: item,
                  volume: 32,
                  lastPosition: const Duration(seconds: 9),
                  lastDuration: const Duration(minutes: 3),
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: PlayerBar())),
        ),
      );
      await tester.pump();

      final playButton = find.widgetWithIcon(IconButton, Icons.play_arrow);
      expect(tester.widget<IconButton>(playButton).onPressed, isNotNull);
      final volumeSlider = tester.widget<Slider>(
        find.byKey(const Key('player-volume-slider')),
      );
      expect(volumeSlider.value, 32);
      expect(find.text('00:09 / 03:00'), findsOneWidget);

      final progressSlider = find.byKey(const Key('player-progress-slider'));
      expect(tester.widget<Slider>(progressSlider).onChanged, isNotNull);
      await tester.drag(progressSlider, const Offset(80, 0));
      await tester.pump();
      expect(find.text('00:00 / 03:00'), findsNothing);
    },
  );

  testWidgets(
    'restoring playback keeps the saved position during zero snapshots',
    (tester) async {
      final audio = _FakeAudioPlayerService(
        const PlayerSnapshot(
          currentSource: MediaSource(url: 'https://example.com/a.mp3'),
          position: Duration.zero,
          duration: Duration(minutes: 3),
        ),
      );
      final item = PlaybackItem.plugin(
        platform: 'Test',
        musicId: 'A',
        title: 'A',
        raw: const <String, Object?>{'id': 'A'},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerServiceProvider.overrideWithValue(audio),
            playerControllerProvider.overrideWith(
              () => _SeededPlayerController(
                PlayerControllerState(
                  queue: <PlaybackItem>[item],
                  currentItem: item,
                  lastPosition: const Duration(seconds: 50),
                  lastDuration: const Duration(minutes: 3),
                  restoreTargetPosition: const Duration(seconds: 50),
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: PlayerBar())),
        ),
      );
      await tester.pump();

      expect(find.text('00:50 / 03:00'), findsOneWidget);
      expect(find.text('00:00 / 03:00'), findsNothing);
    },
  );

  testWidgets(
    'restoring playback keeps the saved duration during duration snapshots',
    (tester) async {
      final audio = _FakeAudioPlayerService(
        const PlayerSnapshot(
          currentSource: MediaSource(url: 'https://example.com/a.mp3'),
          position: Duration(seconds: 51),
          duration: Duration(minutes: 3, seconds: 1),
        ),
      );
      final item = PlaybackItem.plugin(
        platform: 'Test',
        musicId: 'A',
        title: 'A',
        raw: const <String, Object?>{'id': 'A'},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerServiceProvider.overrideWithValue(audio),
            playerControllerProvider.overrideWith(
              () => _SeededPlayerController(
                PlayerControllerState(
                  queue: <PlaybackItem>[item],
                  currentItem: item,
                  lastPosition: const Duration(seconds: 50),
                  lastDuration: const Duration(minutes: 3),
                  restoreTargetPosition: const Duration(seconds: 50),
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: PlayerBar())),
        ),
      );
      await tester.pump();

      expect(find.text('00:50 / 03:00'), findsOneWidget);
      expect(find.text('00:50 / 03:01'), findsNothing);
    },
  );

  testWidgets(
    'restored playback bridges rounded item and shorter saved duration',
    (tester) async {
      final audio = _FakeAudioPlayerService();
      final item = PlaybackItem.plugin(
        platform: 'Test',
        musicId: 'A',
        title: 'A',
        duration: const Duration(minutes: 3),
        raw: const <String, Object?>{'id': 'A'},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerServiceProvider.overrideWithValue(audio),
            playerControllerProvider.overrideWith(
              () => _SeededPlayerController(
                PlayerControllerState(
                  queue: <PlaybackItem>[item],
                  currentItem: item,
                  lastPosition: const Duration(seconds: 50),
                  lastDuration: const Duration(minutes: 2, seconds: 58),
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: PlayerBar())),
        ),
      );
      await tester.pump();

      expect(find.text('00:50 / 02:59'), findsOneWidget);
      expect(find.text('00:50 / 02:58'), findsNothing);
      expect(find.text('00:50 / 03:00'), findsNothing);
    },
  );

  testWidgets('loaded source with zero duration still shows saved duration', (
    tester,
  ) async {
    final audio = _FakeAudioPlayerService(
      const PlayerSnapshot(
        currentSource: MediaSource(url: 'https://example.com/a.mp3'),
        position: Duration(seconds: 51),
      ),
    );
    final item = PlaybackItem.plugin(
      platform: 'Test',
      musicId: 'A',
      title: 'A',
      raw: const <String, Object?>{'id': 'A'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(audio),
          playerControllerProvider.overrideWith(
            () => _SeededPlayerController(
              PlayerControllerState(
                queue: <PlaybackItem>[item],
                currentItem: item,
                lastPosition: const Duration(seconds: 51),
                lastDuration: const Duration(minutes: 3),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: PlayerBar())),
      ),
    );
    await tester.pump();

    expect(find.text('00:51 / 03:00'), findsOneWidget);
    expect(find.text('00:51 / 00:00'), findsNothing);
  });

  testWidgets('loaded source keeps saved duration during one second jitter', (
    tester,
  ) async {
    final audio = _FakeAudioPlayerService(
      const PlayerSnapshot(
        currentSource: MediaSource(url: 'https://example.com/a.mp3'),
        position: Duration(seconds: 55),
        duration: Duration(minutes: 3, seconds: 1),
      ),
    );
    final item = PlaybackItem.plugin(
      platform: 'Test',
      musicId: 'A',
      title: 'A',
      raw: const <String, Object?>{'id': 'A'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(audio),
          playerControllerProvider.overrideWith(
            () => _SeededPlayerController(
              PlayerControllerState(
                queue: <PlaybackItem>[item],
                currentItem: item,
                lastPosition: const Duration(seconds: 54),
                lastDuration: const Duration(minutes: 3),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: PlayerBar())),
      ),
    );
    await tester.pump();

    expect(find.text('00:55 / 03:00'), findsOneWidget);
    expect(find.text('00:55 / 03:01'), findsNothing);
  });

  testWidgets(
    'loaded source bridges rounded plugin and shorter probed duration',
    (tester) async {
      final audio = _FakeAudioPlayerService(
        const PlayerSnapshot(
          currentSource: MediaSource(url: 'https://example.com/a.mp3'),
          position: Duration(seconds: 55),
          duration: Duration(minutes: 2, seconds: 58),
        ),
      );
      final item = PlaybackItem.plugin(
        platform: 'Test',
        musicId: 'A',
        title: 'A',
        duration: const Duration(minutes: 3),
        raw: const <String, Object?>{'id': 'A'},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerServiceProvider.overrideWithValue(audio),
            playerControllerProvider.overrideWith(
              () => _SeededPlayerController(
                PlayerControllerState(
                  queue: <PlaybackItem>[item],
                  currentItem: item,
                  lastPosition: const Duration(seconds: 54),
                  lastDuration: const Duration(minutes: 3),
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: PlayerBar())),
        ),
      );
      await tester.pump();

      expect(find.text('00:55 / 02:59'), findsOneWidget);
      expect(find.text('00:55 / 02:58'), findsNothing);
      expect(find.text('00:55 / 03:00'), findsNothing);
    },
  );

  testWidgets('plugin item duration wins over polluted saved duration', (
    tester,
  ) async {
    final audio = _FakeAudioPlayerService(
      const PlayerSnapshot(
        currentSource: MediaSource(url: 'https://example.com/a.mp3'),
        position: Duration(seconds: 55),
        duration: Duration(minutes: 3, seconds: 1),
      ),
    );
    final item = PlaybackItem.plugin(
      platform: 'Test',
      musicId: 'A',
      title: 'A',
      duration: const Duration(minutes: 3),
      raw: const <String, Object?>{'id': 'A'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(audio),
          playerControllerProvider.overrideWith(
            () => _SeededPlayerController(
              PlayerControllerState(
                queue: <PlaybackItem>[item],
                currentItem: item,
                lastPosition: const Duration(seconds: 54),
                lastDuration: const Duration(minutes: 3, seconds: 1),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: PlayerBar())),
      ),
    );
    await tester.pump();

    expect(find.text('00:55 / 03:00'), findsOneWidget);
    expect(find.text('00:55 / 03:01'), findsNothing);
  });
}

class _SeededPlayerController extends PlayerController {
  _SeededPlayerController(this._state);

  final PlayerControllerState _state;

  @override
  Future<PlayerControllerState> build() async => _state;
}

class _FakeAudioPlayerService implements AudioPlayerService {
  _FakeAudioPlayerService([this._snapshot = const PlayerSnapshot()]);

  final _controller = StreamController<PlayerSnapshot>.broadcast();
  PlayerSnapshot _snapshot;
  int resumeCount = 0;

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
  }) async => const Ok(null);

  @override
  Future<Result<void>> pause() async => const Ok(null);

  @override
  Future<Result<void>> resume() async {
    resumeCount += 1;
    return const Ok(null);
  }

  @override
  Future<Result<void>> seek(Duration position) async => const Ok(null);

  @override
  Future<Result<void>> setVolume(double volume) async => const Ok(null);

  @override
  Future<Result<void>> stop() async => const Ok(null);

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
