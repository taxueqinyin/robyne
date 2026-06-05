import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/app/app.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/domain/audio_player_service.dart';
import 'package:robyne/features/player/domain/media_source.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/player/presentation/now_playing_page.dart';
import 'package:robyne/features/playlists/application/playlist_providers.dart';
import 'package:robyne/features/playlists/domain/music_playlist.dart';

void main() {
  testWidgets('app shell exposes third-stage navigation entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioPlayerServiceProvider.overrideWithValue(_FakeAudio())],
        child: const RobyneApp(),
      ),
    );

    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('player bar keeps seek, volume, and mode controls visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(
            _FakeAudio(
              const PlayerSnapshot(
                currentSource: MediaSource(url: 'https://example.com/a.mp3'),
                duration: Duration(minutes: 3),
                position: Duration(minutes: 1),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: RobyneApp())),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('player-progress-slider')), findsOneWidget);
    expect(find.byKey(const Key('player-volume-slider')), findsOneWidget);
    expect(find.byKey(const Key('player-mode-button')), findsOneWidget);
  });

  testWidgets('lyrics system is temporarily disabled on now playing page', (
    tester,
  ) async {
    final item = PlaybackItem.plugin(
      platform: 'Lyrics',
      musicId: 'song-1',
      title: 'Song',
      raw: const <String, Object?>{'id': 'song-1'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(
            _FakeAudio(
              const PlayerSnapshot(
                currentSource: MediaSource(url: 'https://example.com/a.mp3'),
                position: Duration(minutes: 1),
                duration: Duration(minutes: 3),
              ),
            ),
          ),
          playerControllerProvider.overrideWith(
            () => _SeededPlayerController(
              PlayerControllerState(
                queue: <PlaybackItem>[item],
                currentItem: item,
              ),
            ),
          ),
          playlistControllerProvider.overrideWith(
            () => _SeededPlaylistController(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: NowPlayingPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lyrics temporarily disabled.'), findsOneWidget);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Add to playlist'), findsOneWidget);
    expect(find.text('Search and link lyric'), findsNothing);
    expect(find.text('Adjust lyric offset'), findsNothing);
  });
}

class _SeededPlayerController extends PlayerController {
  _SeededPlayerController(this._state);

  final PlayerControllerState _state;

  @override
  Future<PlayerControllerState> build() async => _state;
}

class _SeededPlaylistController extends PlaylistController {
  @override
  Future<List<MusicPlaylist>> build() async => const <MusicPlaylist>[];
}

class _FakeAudio implements AudioPlayerService {
  _FakeAudio([this._snapshot = const PlayerSnapshot()]);

  final PlayerSnapshot _snapshot;
  final _controller = StreamController<PlayerSnapshot>.broadcast();

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
