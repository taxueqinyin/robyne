import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/app/app.dart';
import 'package:robyne/core/database/app_database.dart' as db;
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/lyrics/application/lyrics_providers.dart';
import 'package:robyne/features/lyrics/infrastructure/lyric_repository.dart';
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

    expect(find.text('Discover'), findsOneWidget);
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

  testWidgets('lyric offset slider updates the active lyric before closing', (
    tester,
  ) async {
    final database = db.AppDatabase.memory();
    addTearDown(database.close);
    final item = PlaybackItem.plugin(
      platform: 'Lyrics',
      musicId: 'song-1',
      title: 'Song',
      raw: const <String, Object?>{'id': 'song-1'},
    );
    final lyricRepository = LyricRepository(database: database);
    await lyricRepository.associatePluginLyric(
      item: item,
      rawLyric: _lrcLines(40),
      pluginPlatform: 'Lyrics',
      pluginRaw: const <String, Object?>{'id': 'lyric-1'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(
            _FakeAudio(
              const PlayerSnapshot(
                currentSource: MediaSource(url: 'https://example.com/a.mp3'),
                position: Duration(milliseconds: 20500),
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
          lyricRepositoryProvider.overrideWithValue(lyricRepository),
          playlistControllerProvider.overrideWith(
            () => _SeededPlaylistController(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: NowPlayingPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(_lyricIsActive(tester, 'line 20'), isTrue);
    expect(find.text('line 30'), findsNothing);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();

    expect(find.text('Lyric offset'), findsOneWidget);
    tester
        .widget<Slider>(find.byKey(const Key('lyric-offset-slider')))
        .onChanged
        ?.call(10000);
    await tester.pumpAndSettle();

    expect(_lyricIsActive(tester, 'line 30'), isTrue);
  });
}

String _lrcLines(int count) {
  return <String>[
    for (var second = 1; second <= count; second += 1)
      '[00:${second.toString().padLeft(2, '0')}.00]line $second',
  ].join('\n');
}

bool _lyricIsActive(WidgetTester tester, String text) {
  final context = tester.element(find.text(text));
  return DefaultTextStyle.of(context).style.color ==
      Theme.of(context).colorScheme.primary;
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
