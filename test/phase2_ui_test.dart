import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/app/app.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/domain/audio_player_service.dart';
import 'package:robyne/features/player/domain/media_source.dart';

void main() {
  testWidgets('app shell exposes Library and Queue navigation entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioPlayerServiceProvider.overrideWithValue(_FakeAudio())],
        child: const RobyneApp(),
      ),
    );

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Queue'), findsOneWidget);
  });

  testWidgets('player bar exposes seek and volume sliders', (tester) async {
    final audio = _FakeAudio(
      const PlayerSnapshot(
        currentSource: MediaSource(url: 'https://example.com/a.mp3'),
        duration: Duration(minutes: 3),
        position: Duration(minutes: 1),
        volume: 50,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioPlayerServiceProvider.overrideWithValue(audio)],
        child: const MaterialApp(home: Scaffold(body: RobyneApp())),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('player-progress-slider')), findsOneWidget);
    expect(find.byKey(const Key('player-volume-slider')), findsOneWidget);
    expect(find.byKey(const Key('player-mode-button')), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('player-progress-slider')),
      const Offset(80, 0),
    );
    await tester.pump();
    expect(audio.seekCalls, isNotEmpty);

    await tester.drag(
      find.byKey(const Key('player-volume-slider')),
      const Offset(-40, 0),
    );
    await tester.pump();
    expect(audio.volumeCalls, isNotEmpty);

    await tester.tap(find.byKey(const Key('player-mode-button')));
    await tester.pump();
    expect(find.byIcon(Icons.shuffle), findsOneWidget);
  });
}

class _FakeAudio implements AudioPlayerService {
  _FakeAudio([this._snapshot = const PlayerSnapshot()]);

  final _controller = StreamController<PlayerSnapshot>.broadcast();
  final PlayerSnapshot _snapshot;
  final seekCalls = <Duration>[];
  final volumeCalls = <double>[];

  @override
  PlayerSnapshot get snapshot => _snapshot;

  @override
  Stream<PlayerSnapshot> get snapshots async* {
    yield _snapshot;
    yield* _controller.stream;
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
  Future<Result<void>> resume() async => const Ok(null);

  @override
  Future<Result<void>> seek(Duration position) async {
    seekCalls.add(position);
    return const Ok(null);
  }

  @override
  Future<Result<void>> setVolume(double volume) async {
    volumeCalls.add(volume);
    return const Ok(null);
  }

  @override
  Future<Result<void>> stop() async => const Ok(null);

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
