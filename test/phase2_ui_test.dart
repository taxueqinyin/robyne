import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/app/app.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/domain/audio_player_service.dart';
import 'package:robyne/features/player/domain/media_source.dart';

import 'support/xuan_fixture.dart';

void main() {
  testWidgets('app shell exposes the flagship navigation entries', (
    tester,
  ) async {
    // The flagship sidebar is a desktop-shaped surface; the default 800x600
    // test viewport resolves to the phone shell, so declare the desktop size
    // this assertion is about.
    tester.view.physicalSize =
        const Size(1280, 900) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Object>[
          audioPlayerServiceProvider.overrideWithValue(_FakeAudio()),
          // Skin-declared chrome: assert against the real flagship manifest
          // rather than waiting on the bundled asset's async load.
          baseThemePackageProvider.overrideWithValue(xuanFixture()),
        ].cast(),
        child: const RobyneApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Flagship《玄》groups navigation by intent: a branded rail with the
    // primary destinations, and the queue as its own panel rather than an
    // equal-weight nav entry.
    // The label comes from the skin now, and《玄》declares it in Chinese.
    expect(find.text('内容库'), findsOneWidget);
    expect(find.byKey(const Key('shell-nav-left')), findsOneWidget);
    expect(find.byKey(const Key('shell-nav-bottom')), findsNothing);
  });

  testWidgets('player bar exposes seek and volume sliders', (tester) async {
    // The design spec (§5.1) reserves the volume slider for windows of at
    // least 960dp; the default 800x600 test viewport sits below that, so a
    // desktop viewport has to be declared to see the full transport row.
    _setViewport(tester, const Size(1280, 900));
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

/// The design spec hides the volume slider below 960dp, so tests that assert
/// on the full transport row have to declare a desktop-sized viewport.
void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
}
