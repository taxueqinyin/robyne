import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/layout/window_size_class.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/domain/audio_player_service.dart';
import 'package:robyne/features/player/domain/media_source.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/player/presentation/now_playing_page.dart';
import 'package:robyne/features/player/presentation/player_bar.dart';
import 'package:robyne/features/player/presentation/queue_page.dart';
import 'package:robyne/features/playlists/application/playlist_providers.dart';
import 'package:robyne/features/playlists/domain/music_playlist.dart';

/// Representative surfaces the app must render without dropping content.
///
/// Each size deliberately sits on a different side of the Material 3
/// breakpoints defined in [WindowSizeClass]:
///
/// - phone portrait: compact width + medium height
/// - phone landscape: medium width + compact height (the case that used to
///   borrow the desktop shell and clip its content)
/// - desktop: expanded width + expanded height
const _phonePortrait = Size(400, 800);
const _phoneLandscape = Size(800, 360);
const _desktop = Size(1280, 900);

void main() {
  group('WindowSizeClass', () {
    test('classifies width and height independently', () {
      expect(
        WindowSizeClass.fromSize(const Size(400, 800)),
        isA<WindowSizeClass>()
            .having((c) => c.width, 'width', WindowWidthClass.compact)
            .having((c) => c.height, 'height', WindowHeightClass.medium),
      );

      // The exact combination that regressed: a landscape phone is NOT wide.
      final landscape = WindowSizeClass.fromSize(_phoneLandscape);
      expect(landscape.width, WindowWidthClass.medium);
      expect(landscape.height, WindowHeightClass.compact);
      expect(landscape.isCompactHeight, isTrue);
      expect(landscape.isCompactWidth, isFalse);

      final desktop = WindowSizeClass.fromSize(_desktop);
      expect(desktop.width, WindowWidthClass.expanded);
      expect(desktop.height, WindowHeightClass.expanded);
      expect(desktop.isCompactHeight, isFalse);
    });

    test('clamps declared dimensions into the viewport', () {
      final sizeClass = WindowSizeClass.fromSize(const Size(400, 800));
      // 300dp cover art in a 400dp-wide window must shrink.
      expect(sizeClass.clampDimension(300, maxRatio: 0.62), lessThan(300));
      // A value that already fits is left alone.
      expect(sizeClass.clampDimension(100, maxRatio: 0.62), 100);
    });
  });

  group('survives every viewport without overflow', () {
    for (final size in <Size>[_phonePortrait, _phoneLandscape, _desktop]) {
      testWidgets('PlayerBar renders at $size', (tester) async {
        await _pumpAt(
          tester,
          size,
          Consumer(
            builder: (context, ref, _) =>
                const Scaffold(body: SizedBox(height: 400, child: PlayerBar())),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(PlayerBar), findsOneWidget);
      });

      testWidgets('QueuePage renders at $size', (tester) async {
        await _pumpAt(
          tester,
          size,
          Consumer(builder: (context, ref, _) => const QueuePage()),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Queue'), findsWidgets);
      });

      testWidgets('NowPlayingPage renders at $size', (tester) async {
        final item = PlaybackItem.plugin(
          platform: 'Test',
          musicId: 'A',
          title: 'A Very Long Track Title That Must Not Overflow',
          raw: const <String, Object?>{'id': 'A'},
        );
        await _pumpAt(
          tester,
          size,
          Consumer(builder: (context, ref, _) => const NowPlayingPage()),
          overrides: [
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
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('landscape phone keeps the transport controls reachable', (
    tester,
  ) async {
    final audio = _FakeAudio(
      const PlayerSnapshot(
        currentSource: MediaSource(url: 'https://example.com/a.mp3'),
        duration: Duration(minutes: 3),
        position: Duration(minutes: 1),
      ),
    );

    await _pumpAt(
      tester,
      _phoneLandscape,
      Consumer(
        builder: (context, ref, _) =>
            const Scaffold(body: SizedBox(height: 64, child: PlayerBar())),
      ),
      overrides: [audioPlayerServiceProvider.overrideWithValue(audio)],
    );

    // The mini bar must keep play/pause and next; the progress row is gone
    // because a 360dp window cannot afford it. Full controls live on the
    // Now Playing page.
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
    expect(find.byKey(const Key('player-progress-slider')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop keeps the full player bar', (tester) async {
    final audio = _FakeAudio(
      const PlayerSnapshot(
        currentSource: MediaSource(url: 'https://example.com/a.mp3'),
        duration: Duration(minutes: 3),
        position: Duration(minutes: 1),
        volume: 50,
      ),
    );

    await _pumpAt(
      tester,
      _desktop,
      Consumer(
        builder: (context, ref, _) =>
            const Scaffold(body: SizedBox(height: 200, child: PlayerBar())),
      ),
      overrides: [audioPlayerServiceProvider.overrideWithValue(audio)],
    );

    expect(find.byKey(const Key('player-progress-slider')), findsOneWidget);
    expect(find.byKey(const Key('player-volume-slider')), findsOneWidget);
    expect(find.byKey(const Key('player-mode-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('queue collapses to tabs below the expanded breakpoint', (
    tester,
  ) async {
    await _pumpAt(
      tester,
      _phonePortrait,
      Consumer(builder: (context, ref, _) => const QueuePage()),
    );
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('History'), findsWidgets);

    await _pumpAt(
      tester,
      _desktop,
      Consumer(builder: (context, ref, _) => const QueuePage()),
    );
    // Side-by-side panes: no tab bar, and both panes are on screen at once.
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(VerticalDivider), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Pumps [child] inside a viewport of exactly [size] logical pixels.
///
/// Flutter widget tests default to 800x600, which hides every compact-height
/// defect; the size must be injected explicitly.
Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  Widget child, {
  List<Object>? overrides,
}) async {
  // Flutter widget tests default to 800x600, which hides every compact-height
  // defect; the size must be injected explicitly.
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: (overrides ?? const <Object>[]).cast(),
      child: MaterialApp(
        home: Scaffold(body: SizedBox.expand(child: child)),
      ),
    ),
  );
  await tester.pump();
  // Allow the framework to surface layout overflow errors.
  await tester.pump(const Duration(milliseconds: 100));
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

  final _controller = StreamController<PlayerSnapshot>.broadcast();
  // Kept mutable so a test can re-emit a new snapshot mid-widget.
  // ignore: prefer_final_fields
  PlayerSnapshot _snapshot;

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
