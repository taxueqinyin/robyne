import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/app/app.dart';
import 'package:robyne/core/database/app_database.dart' as db;
import 'package:robyne/core/result/result.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/core/theme/infrastructure/token_resolver.dart';
import 'package:robyne/features/lyrics/application/lyrics_providers.dart';
import 'package:robyne/features/lyrics/infrastructure/lyric_repository.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/domain/audio_player_service.dart';
import 'package:robyne/features/player/domain/media_source.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/player/presentation/now_playing_page.dart';
import 'package:robyne/features/playlists/application/playlist_providers.dart';
import 'package:robyne/features/playlists/domain/music_playlist.dart';

import 'support/xuan_fixture.dart';

void main() {
  testWidgets('app shell exposes third-stage navigation entries', (
    tester,
  ) async {
    tester.view.physicalSize =
        const Size(1280, 900) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Object>[
          audioPlayerServiceProvider.overrideWithValue(_FakeAudio()),
          // Skin-declared chrome: assert against the real flagship manifest.
          baseThemePackageProvider.overrideWithValue(xuanFixture()),
        ].cast(),
        child: const RobyneApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The flagship rail keeps the primary destinations labelled; queue and
    // now-playing are surfaces, not equal-weight navigation rows. Liked songs
    // and the user's playlists are separate entries with separate meanings.
    expect(find.text('发现'), findsWidgets);
    expect(find.text('内容库'), findsOneWidget);
    expect(find.text('我喜欢'), findsWidgets);
    // The rail separates liked songs from the user's playlist/collection
    // group, so the second heading is part of the composition now.
    expect(find.text('我的歌单'), findsOneWidget);
    expect(find.text('插件'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('player bar keeps seek, volume, and mode controls visible', (
    tester,
  ) async {
    // The volume slider is reserved for windows of at least 960dp
    // (design spec §5.1), so the desktop transport row only exists in a
    // desktop viewport.
    tester.view.physicalSize =
        const Size(1280, 900) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          baseThemePackageProvider.overrideWithValue(xuanFixture()),
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
    expect(find.byKey(const Key('player-volume-button')), findsOneWidget);
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
          baseThemePackageProvider.overrideWithValue(xuanFixture()),
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

    // The per-track menu no longer sits inline on the page: the lyric region
    // owns its own right-click menu, which is where the offset control lives.
    // The active line is drawn several times — blurred glow passes under the
    // ink — so the finder matches more than one copy.
    final lyricCentre = tester.getCenter(find.text('line 20').first);
    final gesture = await tester.startGesture(
      lyricCentre,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('歌词相关功能'), findsOneWidget);
    // The flagship skin names the control in its own language, so the
    // assertion follows the skin rather than the neutral default.
    expect(find.text('歌词偏移'), findsOneWidget);
    // The offset control is a dial: one full revolution is 10s. Dragging
    // around the hub is the real interaction, so the test sweeps the pointer
    // along the rim rather than poking a widget's callback.
    await _sweepDial(tester, turns: 1);
    await tester.pumpAndSettle();

    expect(_lyricIsActive(tester, 'line 30'), isTrue);
  });
}

/// Drags a pointer around the offset dial [turns] times.
///
/// The dial integrates angle deltas, so the sweep has to walk the rim in small
/// steps: a straight `drag` would cut across the hub where the angle is
/// undefined and would not accumulate a full turn.
Future<void> _sweepDial(WidgetTester tester, {required int turns}) async {
  final dialCentre = tester.getCenter(
    find.byKey(const Key('lyric-offset-dial')),
  );
  const radius = 48.0;
  const steps = 36;
  Offset at(double fraction) {
    final angle = fraction * 2 * math.pi;
    return dialCentre + Offset(math.sin(angle), -math.cos(angle)) * radius;
  }

  final gesture = await tester.startGesture(at(0));
  for (var turn = 0; turn < turns; turn++) {
    for (var step = 1; step <= steps; step++) {
      await gesture.moveTo(at(turn + step / steps));
      await tester.pump();
    }
  }
  await gesture.up();
}

String _lrcLines(int count) {
  return <String>[
    for (var second = 1; second <= count; second += 1)
      '[00:${second.toString().padLeft(2, '0')}.00]line $second',
  ].join('\n');
}

bool _lyricIsActive(WidgetTester tester, String text) {
  // The active line is painted as several stacked copies (blurred glow passes
  // plus the ink), so the finder matches all of them. The ink copy is the one
  // whose colour is the resolved lyric colour.
  final tokens = RobyneTheme.of(tester.element(find.text(text).first)).tokens;
  return find
      .text(text)
      .evaluate()
      .any(
        (element) =>
            DefaultTextStyle.of(element).style.color ==
            tokens.components.lyric.activeLine,
      );
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
