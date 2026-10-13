import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/player/presentation/now_playing_page.dart';
import 'package:robyne/features/player/presentation/artwork_view.dart';
import 'package:robyne/shared/widgets/song_actions_menu.dart';

import 'support/xuan_fixture.dart';

const PlaybackItem _item = PlaybackItem(
  id: 'plugin:x:A',
  type: PlaybackItemType.plugin,
  title: '测试歌曲',
  platform: 'Test',
  artist: '测试歌手',
  duration: Duration(minutes: 3),
);

void main() {
  // Both menus here go through `showSongActionsMenu`, whose process-wide
  // "one menu at a time" flag only clears after `showMenu` returns. A test
  // that leaves a menu open never gets there, and the flag would then block
  // the next test's menu outright.
  tearDown(endSongMenu);

  testWidgets('a secondary tap on the lyric area opens lyric actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The lyric pane owns the lower part of the trailing column; the reference
    // composition puts the artwork on the left, so the right half is lyric.
    final target = tester.getCenter(find.byType(NowPlayingPage));
    final gesture = await tester.startGesture(
      target + const Offset(220, 180),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    // Not `pumpAndSettle`: the immersive chrome runs a repeating auto-hide
    // timer, so the tree never goes quiet.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The lyric menu names itself, so its presence is unambiguous.
    expect(find.text('歌词相关功能'), findsOneWidget);
    expect(find.text('歌曲相关功能'), findsNothing);
  });

  testWidgets('a secondary tap on the artwork opens song actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The artwork column sits inboard of the leading edge (contentInset).
    final artworkCentre = tester.getCenter(find.byType(ArtworkView).first);
    final gesture = await tester.startGesture(
      artworkCentre,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('歌曲相关功能'), findsOneWidget);
    expect(find.text('下一首播放'), findsOneWidget);
    expect(find.text('歌词相关功能'), findsNothing);
  });

  testWidgets('the transport fades out with the window chrome', (tester) async {
    // The immersive player is meant to be watched, not operated: the transport
    // and the window controls appear together while the pointer is in the
    // window and fade out together when it leaves, so the artwork owns the
    // screen. This pins that contract rather than the pixel values.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    AnimatedOpacity transport() => tester.widget<AnimatedOpacity>(
      find.byKey(const Key('now-playing-transport')),
    );

    expect(transport().opacity, 1, reason: 'visible while the pointer is in');

    // Leaving the window starts the hide timer.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 400));
    await tester.pump();
    await mouse.removePointer();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();

    expect(transport().opacity, 0, reason: 'hidden once the timer fires');
  });

  testWidgets('the queue button opens a queue over the immersive player', (
    tester,
  ) async {
    // The shell's docked queue sits *behind* the immersive overlay, so the
    // player used to toggle state the user could never see. The panel has to
    // live inside the player for the button to mean anything.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    AnimatedOpacity panel() => tester.widget<AnimatedOpacity>(
      find.byKey(const Key('now-playing-queue-panel')),
    );
    expect(panel().opacity, 0, reason: 'shut until asked for');

    await tester.tap(find.byKey(const Key('now-playing-queue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(panel().opacity, 1, reason: 'the button opens the queue');
    // And every row can drop itself from the queue.
    expect(
      find.byKey(const ValueKey<String>('queue-remove-plugin:x:A')),
      findsOneWidget,
    );
  });

  testWidgets('the bottom home control reuses the page close action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var closeCount = 0;

    await tester.pumpWidget(_app(onClose: () => closeCount += 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('now-playing-transport-home')));
    await tester.pump();

    expect(closeCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('volume opens above the button and keeps the transport visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _SeededController(
      const PlayerControllerState(
        queue: <PlaybackItem>[_item],
        currentItem: _item,
        volume: 36,
      ),
    );

    await tester.pumpWidget(_app(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final button = find.byKey(const Key('now-playing-volume-button'));
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final panel = find.byKey(const Key('now-playing-volume-popover'));
    expect(panel, findsOneWidget);
    expect(find.text('36%'), findsOneWidget);
    expect(tester.getRect(panel).bottom, lessThan(tester.getRect(button).top));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(panel));
    await mouse.moveTo(tester.getCenter(panel) + const Offset(0, 1));
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const Key('now-playing-transport')),
          )
          .opacity,
      1,
      reason: 'the bar stays available while operating its volume popup',
    );

    await tester.drag(
      find.byKey(const Key('now-playing-volume-slider')),
      const Offset(0, -25),
    );
    await tester.pump();
    expect(controller.previewedVolume, greaterThan(36));
    expect(controller.committedVolume, controller.previewedVolume);
    await tester.tap(button);
    await tester.pump();
    await mouse.removePointer();
    expect(panel, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in <double>[320, 400, 560, 719, 720, 960, 1280, 1920]) {
    testWidgets('immersive controls fit a ${width}dp window', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app(onClose: () {}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(const Key('now-playing-transport-home')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('now-playing-volume-button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('now-playing-quality')), findsOneWidget);
      expect(
        find.byKey(const Key('now-playing-desktop-lyrics')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('now-playing-queue')), findsOneWidget);
      final page = tester.getRect(find.byType(NowPlayingPage));
      final controls = tester.getRect(
        find.byKey(const Key('now-playing-center-controls')),
      );
      expect(controls.center.dx, closeTo(page.center.dx, 0.01));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the chrome stays put while the pointer rests on it', (
    tester,
  ) async {
    // Hiding used to be a pure timer: it kept running while the pointer sat
    // on a button, so a user who paused before clicking watched the button
    // fade out and then clicked nothing. Hovering must hold the chrome — it
    // hides when the pointer leaves, never while it is being aimed.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    AnimatedOpacity transport() => tester.widget<AnimatedOpacity>(
      find.byKey(const Key('now-playing-transport')),
    );

    // The chrome bands (top controls at the top edge, transport at the bottom)
    // are the only hover surfaces; the page centre is the lyrics and must not
    // hold the chrome up.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 780));
    await mouse.moveTo(const Offset(401, 781));
    await tester.pump();
    expect(transport().opacity, 1, reason: 'shown on hover');

    // Far longer than the 1s hide timer: hovering suppresses it entirely.
    await tester.pump(const Duration(seconds: 5));
    expect(transport().opacity, 1, reason: 'still shown while hovered');

    // Leaving restarts the timer, and it fires.
    await mouse.removePointer();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();
    expect(transport().opacity, 0, reason: 'hidden once the pointer leaves');
  });
}

Widget _app({VoidCallback? onClose, _SeededController? controller}) {
  return ProviderScope(
    overrides: [
      baseThemePackageProvider.overrideWithValue(xuanFixture()),
      playerControllerProvider.overrideWith(
        () =>
            controller ??
            _SeededController(
              const PlayerControllerState(
                queue: <PlaybackItem>[_item],
                currentItem: _item,
                lastDuration: Duration(minutes: 3),
              ),
            ),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: NowPlayingPage(
          immersive: true,
          showWindowControls: true,
          onClose: onClose,
        ),
      ),
    ),
  );
}

class _SeededController extends PlayerController {
  _SeededController(this._seed);

  final PlayerControllerState _seed;
  double? previewedVolume;
  double? committedVolume;

  @override
  Future<PlayerControllerState> build() async => _seed;

  @override
  void previewVolume(double volume) => previewedVolume = volume;

  @override
  Future<void> setVolume(double volume) async {
    committedVolume = volume;
    state = AsyncData(state.requireValue.copyWith(volume: volume));
  }
}
