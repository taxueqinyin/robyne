import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/domain/audio_player_service.dart';
import 'package:robyne/features/player/domain/media_source.dart';
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
  Future<Result<void>> play(MediaSource source) async => const Ok(null);

  @override
  Future<Result<void>> pause() async => const Ok(null);

  @override
  Future<Result<void>> resume() async {
    resumeCount += 1;
    return const Ok(null);
  }

  @override
  Future<Result<void>> stop() async => const Ok(null);

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
