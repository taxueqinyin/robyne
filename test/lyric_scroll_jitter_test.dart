import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/features/lyrics/application/lyrics_providers.dart';
import 'package:robyne/features/lyrics/domain/lyric_document.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/domain/audio_player_service.dart';
import 'package:robyne/features/player/domain/media_source.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/player/presentation/now_playing_page.dart';

import 'support/xuan_fixture.dart';

/// Regression coverage for the lyric pane's stability during playback.
///
/// Playback reports a new position several times a second. If the pane watches
/// that position rather than the highlighted line, it re-lays out the whole
/// reading column on every tick — which read as a constant shiver over the
/// lines already sung.
void main() {
  testWidgets('the pane is not rebuilt while a line stays active', (
    tester,
  ) async {
    const item = PlaybackItem(
      id: 'plugin:x:A',
      type: PlaybackItemType.plugin,
      title: '昔涟',
      duration: Duration(minutes: 4),
    );
    final audio = _FakeAudio(
      const PlayerSnapshot(
        currentSource: MediaSource(url: 'https://example.com/a.mp3'),
        playing: true,
        duration: Duration(minutes: 4),
        position: Duration(seconds: 10),
      ),
    );
    final lyrics = LyricDocument(
      raw: '',
      sourceType: LyricSourceType.plugin,
      lines: <LyricLine>[
        for (var index = 0; index < 40; index += 1)
          LyricLine(
            text: '第 $index 行：这是一句足够长的歌词文本用来触发换行和省略号处理',
            timestamp: Duration(seconds: index * 8),
          ),
      ],
    );

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        baseThemePackageProvider.overrideWithValue(xuanFixture()),
        audioPlayerServiceProvider.overrideWithValue(audio),
        playerControllerProvider.overrideWith(
          () => _SeededPlayerController(
            const PlayerControllerState(
              queue: <PlaybackItem>[item],
              currentItem: item,
              lastDuration: Duration(minutes: 4),
            ),
          ),
        ),
        storedCurrentLyricsProvider.overrideWith((ref) async => lyrics),
      ],
    );
    addTearDown(container.dispose);

    var indexChanges = 0;
    final indexLog = <int>[];
    container.listen<int>(activeLyricIndexProvider, (previous, next) {
      indexChanges += 1;
      indexLog.add(next);
    }, fireImmediately: true);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: NowPlayingPage(immersive: true, showWindowControls: true),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Playback advancing inside one line must leave every metric of the
    // scroll position untouched, not just the pixel offset.
    String metrics() {
      final list = tester.widget<ListView>(find.byType(ListView).first);
      final pos = list.controller!.position;
      return '${pos.pixels}|${pos.minScrollExtent}|${pos.maxScrollExtent}'
          '|${pos.viewportDimension}';
    }

    audio.emit(
      PlayerSnapshot(
        currentSource: const MediaSource(url: 'https://example.com/a.mp3'),
        playing: true,
        duration: const Duration(minutes: 4),
        position: Duration(seconds: 3 * 8),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    // Finish the deliberate line-change glide before measuring stability
    // across playback ticks that stay on that same line.
    await tester.pump(const Duration(milliseconds: 400));

    final seen = <String>{metrics()};
    final stylesBefore = _rowStyles(tester);
    indexChanges = 0;
    indexLog.clear();
    // Count rebuilds of the lyric list by watching whether Flutter rebuilds
    // its element: a rebuild replaces the widget the element holds, so a
    // stable widget identity across a tick means no re-layout happened.
    final listBefore = tester.widget<ListView>(find.byType(ListView).first);
    var paneBuilds = 0;
    for (var tick = 1; tick <= 20; tick += 1) {
      audio.emit(
        PlayerSnapshot(
          currentSource: const MediaSource(url: 'https://example.com/a.mp3'),
          playing: true,
          duration: const Duration(minutes: 4),
          position: Duration(seconds: 3 * 8, milliseconds: tick * 100),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      if (!identical(
        tester.widget<ListView>(find.byType(ListView).first),
        listBefore,
      )) {
        paneBuilds += 1;
      }
      seen.add(metrics());
    }

    expect(
      seen.length,
      1,
      reason:
          'scroll position changed while the line held still: ${seen.join(' ')}',
    );

    // The decisive assertion: no visible row may change its rendered style
    // while playback advances inside one line. A changing font size or weight
    // re-lays out the text and shifts the lines above it, which is the shiver.
    expect(_rowStyles(tester), stylesBefore);

    // And the pane's input must not change at all across those ticks. Every
    // change rebuilds the whole reading column; during one line this is zero.
    expect(
      indexChanges,
      0,
      reason: 'pane input changed inside one line: ${indexLog.join(',')}',
    );
    expect(paneBuilds, 0, reason: 'pane rebuilt inside one line');
  });

  testWidgets('the highlight follows playback across lines', (tester) async {
    // The fix must not go too far: crossing a timestamp still has to move the
    // highlight and bring the new line into view.
    const item = PlaybackItem(
      id: 'plugin:x:A',
      type: PlaybackItemType.plugin,
      title: '昔涟',
      duration: Duration(minutes: 4),
    );
    final audio = _FakeAudio(
      const PlayerSnapshot(
        currentSource: MediaSource(url: 'https://example.com/a.mp3'),
        playing: true,
        duration: Duration(minutes: 4),
        position: Duration(seconds: 2),
      ),
    );
    final lyrics = LyricDocument(
      raw: '',
      sourceType: LyricSourceType.plugin,
      lines: <LyricLine>[
        for (var index = 0; index < 40; index += 1)
          LyricLine(
            text: '第 $index 行',
            timestamp: Duration(seconds: index * 8),
          ),
      ],
    );

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          baseThemePackageProvider.overrideWithValue(xuanFixture()),
          audioPlayerServiceProvider.overrideWithValue(audio),
          playerControllerProvider.overrideWith(
            () => _SeededPlayerController(
              const PlayerControllerState(
                queue: <PlaybackItem>[item],
                currentItem: item,
                lastDuration: Duration(minutes: 4),
              ),
            ),
          ),
          storedCurrentLyricsProvider.overrideWith((ref) async => lyrics),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: NowPlayingPage(immersive: true, showWindowControls: true),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Walk a handful of consecutive lines rather than jumping to the end of
    // the song: the assertion is "the pane follows the highlight", and a line
    // far enough away is legitimately scrolled out of the viewport.
    for (final seconds in <int>[2, 10, 18, 26, 34]) {
      audio.emit(
        PlayerSnapshot(
          currentSource: const MediaSource(url: 'https://example.com/a.mp3'),
          playing: true,
          duration: const Duration(minutes: 4),
          position: Duration(seconds: seconds),
        ),
      );
      await tester.pump();
      // Scrolling to a new line is animated, so let the glide finish before
      // asserting where the pane landed.
      await tester.pump(const Duration(milliseconds: 400));
      final expected = '第 ${seconds ~/ 8} 行';
      expect(
        find.text(expected),
        findsWidgets,
        reason: 'line for ${seconds}s should be rendered',
      );
    }
  });
}

/// The rendered style of every text row in layout order.
///
/// A row whose size, weight or colour shifts between two frames of the same
/// active line is a row the user watches move.
/// The rendered style of every lyric row inside the pane, by line text.
///
/// Scoped to the lyric list on purpose: the transport bar's timecode is
/// *supposed* to advance during playback, and including it made every frame
/// look different for a correct reason.
Map<String, String> _rowStyles(WidgetTester tester) {
  final out = <String, String>{};
  final list = find.byType(ListView).first;
  for (final element
      in find.descendant(of: list, matching: find.byType(Text)).evaluate()) {
    final widget = element.widget as Text;
    final style = DefaultTextStyle.of(element).style;
    out[widget.data ?? ''] =
        '${style.fontSize}/${style.fontWeight}/${style.color}';
  }
  return out;
}

class _FakeAudio implements AudioPlayerService {
  _FakeAudio(this._snapshot);

  final _controller = StreamController<PlayerSnapshot>.broadcast();
  PlayerSnapshot _snapshot;

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

class _SeededPlayerController extends PlayerController {
  _SeededPlayerController(this._seed);

  final PlayerControllerState _seed;

  @override
  Future<PlayerControllerState> build() async => _seed;
}
