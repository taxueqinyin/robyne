import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/app/router.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/presentation/capsule_player_bar.dart'
    show capsuleQueueOpenProvider;
import 'package:robyne/features/player/application/capsule_window.dart';
import 'package:robyne/features/player/application/capsule_window_state.dart';
import 'package:robyne/app/main_window_state.dart';
import 'package:robyne/features/player/domain/playback_item.dart';

import 'support/xuan_fixture.dart';

/// The capsule is a window shape, not a page: the whole shell collapses into
/// one draggable bar, and closing it restores exactly what was underneath.
void main() {
  test('the capsule remembers its own position', () {
    // The two layouts have separate homes: the capsule must not reopen at
    // the shell's top-left corner just because that is where the shell is.
    final state = const CapsuleWindowState(position: Offset(1400, 900));
    final json = jsonEncode(state.toJson());
    expect(json, contains('1400'));

    final decoded = CapsuleWindowState.fromJson(json);
    expect(decoded?.position, const Offset(1400, 900));
  });

  test('a capsule position off-screen is pulled back into the work area', () {
    // A remembered spot on an unplugged monitor must not open the capsule
    // somewhere invisible.
    const workArea = Rect.fromLTWH(0, 0, 1920, 1080);
    final bounds = capsuleBoundsAt(
      position: const Offset(5000, 5000),
      workArea: workArea,
      playlistOpen: false,
    );
    expect(bounds.right, lessThanOrEqualTo(workArea.right));
    expect(bounds.bottom, lessThanOrEqualTo(workArea.bottom));
    expect(bounds.left, greaterThanOrEqualTo(workArea.left));
    expect(bounds.top, greaterThanOrEqualTo(workArea.top));
  });

  test('the capsule position survives a corrupt stored value', () {
    expect(CapsuleWindowState.fromJson('not json'), isNull);
    expect(CapsuleWindowState.fromJson(''), isNull);
    expect(CapsuleWindowState.fromJson(null), isNull);
    // A stored value with no usable coordinates is the same as none at all:
    // the capsule then falls back to wherever the window already is.
    expect(CapsuleWindowState.fromJson('{"left":null,"top":null}'), isNull);
  });

  test('restoring the shell prefers the bounds captured on entry', () {
    // The capsule moves the window; the shell must go back where it was, not
    // stay wherever the capsule got dragged to.
    const captured = Rect.fromLTWH(120, 80, 1280, 720);
    final result = resolveShellRestoreBounds(
      captured: captured,
      savedSize: const Size(900, 600),
      savedPosition: const Offset(10, 10),
    );
    expect(result.bounds, captured);
    expect(result.hadRealOrigin, isTrue);
  });

  test('restoring the shell ignores capsule-sized persisted geometry', () {
    // Regression: the geometry watcher writes on a timer, so a save already
    // in flight when the capsule opened can land after `suspend()`. Clamping
    // that up to the minimum restored a phone-sized window; it has to be
    // rejected instead, falling back to the documented default.
    final result = resolveShellRestoreBounds(
      savedSize: CapsuleWindow.windowWidth > 0
          ? Size(
              CapsuleWindow.windowWidth,
              CapsuleWindow.windowHeight(playlistOpen: false),
            )
          : Size.zero,
      savedPosition: const Offset(400, 400),
    );
    expect(result.bounds.size, MainWindowState.defaultSize);
    expect(result.hadRealOrigin, isFalse);
  });

  test('restoring the shell falls back to persisted geometry', () {
    const savedSize = Size(1100, 800);
    const savedPosition = Offset(64, 48);
    final result = resolveShellRestoreBounds(
      savedSize: savedSize,
      savedPosition: savedPosition,
    );
    expect(result.bounds, savedPosition & savedSize);
    expect(result.hadRealOrigin, isTrue);
  });

  test('a shell restore is taken from the largest usable source', () {
    // The captured bounds win over the persisted ones, and both are rejected
    // when they could only have come from the capsule. What must never happen
    // is restoring a size smaller than the shell can be: that is how "close"
    // used to reopen a phone-sized window.
    final fromDefault = resolveShellRestoreBounds();
    expect(fromDefault.bounds.size, MainWindowState.defaultSize);
    expect(
      fromDefault.bounds.size.width,
      greaterThanOrEqualTo(MainWindowState.minimumSize.width),
    );
    expect(
      fromDefault.bounds.size.height,
      greaterThanOrEqualTo(MainWindowState.minimumSize.height),
    );
  });

  test('a persisted size with no position is not treated as placed', () {
    // `setBounds` needs both halves, so a size without an origin must ask to
    // be centred rather than being parked at (0, 0).
    final result = resolveShellRestoreBounds(
      savedSize: MainWindowState.defaultSize,
    );
    expect(result.hadRealOrigin, isFalse);
  });

  test('the artwork keeps its clearance inside the bar', () {
    // The cover must sit above the bar's bottom edge by the declared gap and
    // rise above its top edge — no part of the circle may hang below the bar.
    final artworkBottom = CapsuleWindow.artworkTop + CapsuleWindow.artworkSize;
    final barBottom = CapsuleWindow.barTop + CapsuleWindow.barHeight;
    expect(barBottom - artworkBottom, CapsuleWindow.artworkBottomClearance);
    expect(
      CapsuleWindow.artworkTop,
      lessThan(CapsuleWindow.barTop),
      reason: 'the cover must protrude above the bar',
    );
    // The stack has to be tall enough to hold both.
    expect(CapsuleWindow.stackHeight, greaterThanOrEqualTo(artworkBottom));
    expect(CapsuleWindow.stackHeight, greaterThanOrEqualTo(barBottom));
  });

  test('the capsule window is smaller than the shell minimum', () {
    // The shell's normal minimum is 400×360; the capsule deliberately goes
    // below it, which is why the minimum has to be relaxed on entry.
    expect(CapsuleWindow.windowWidth, lessThan(400));
    expect(CapsuleWindow.windowHeight(playlistOpen: false), lessThan(200));
  });

  test('the playlist grows the window downward, not upward', () {
    // `setSize` anchors the top-left corner, so a taller window means the
    // panel was added below the bar.
    expect(
      CapsuleWindow.windowHeight(playlistOpen: true),
      greaterThan(CapsuleWindow.windowHeight(playlistOpen: false)),
    );
  });

  test('the bar is wide enough for its content', () {
    // The cover, the info/controls area and the trailing close button must
    // all fit inside the surface.
    final content =
        CapsuleWindow.artworkInset +
        CapsuleWindow.artworkSize +
        CapsuleWindow.artworkGap +
        CapsuleWindow.middleWidth +
        CapsuleWindow.closeButtonSize +
        6;
    expect(content, lessThanOrEqualTo(CapsuleWindow.barWidth));
  });

  testWidgets(
    'the title bar enters capsule mode and close restores the shell',
    (tester) async {
      final item = PlaybackItem.plugin(
        platform: 'Test',
        musicId: 'A',
        title: 'Capsule Track',
        raw: const <String, Object?>{'id': 'A'},
      );
      await _pumpShell(
        tester,
        overrides: <Object>[
          playerControllerProvider.overrideWith(
            () => _SeededPlayerController(
              PlayerControllerState(
                queue: <PlaybackItem>[item],
                currentItem: item,
              ),
            ),
          ),
        ],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RobyneShell)),
      );

      expect(find.byKey(const Key('capsule-close')), findsNothing);

      // The frameless window's controls are hidden under FLUTTER_TEST, so the
      // test drives the same state the button's callback writes.
      container.read(capsuleModeProvider.notifier).enter();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(container.read(capsuleModeProvider), isTrue);
      expect(find.byKey(const Key('shell-content')), findsNothing);
      // At rest the capsule shows the song, not the transport controls.
      expect(find.byKey(const Key('capsule-info')), findsOneWidget);
      expect(find.byKey(const Key('capsule-controls')), findsNothing);
      expect(find.byKey(const Key('capsule-drag-region')), findsOneWidget);
      expect(find.byKey(const Key('capsule-artwork')), findsOneWidget);
      // The cover overlaps the surface, so it needs its own drag layer —
      // without it the cover was the one part of the bar you could not move
      // the window by.
      expect(find.byKey(const Key('capsule-artwork-drag')), findsOneWidget);

      // Hovering the bar swaps in the transport controls.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(
        tester.getCenter(find.byKey(const Key('capsule-drag-region'))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('capsule-controls')), findsOneWidget);
      expect(find.byKey(const Key('capsule-info')), findsNothing);

      await tester.tap(find.byKey(const Key('capsule-close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(container.read(capsuleModeProvider), isFalse);
      expect(find.byKey(const Key('shell-content')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('leaving the capsule twice lands the shell once', (tester) async {
    // The capsule can be left from several paths at once — its own close
    // button, the tray's "show", a second toggle — and every exit used to run
    // its own async restore. Two restores raced over the same window: each
    // read the bounds the other had just written, and the shell settled at a
    // size neither asked for.
    final item = PlaybackItem.plugin(
      platform: 'Test',
      musicId: 'A',
      title: 'Capsule Track',
      raw: const <String, Object?>{'id': 'A'},
    );
    await _pumpShell(
      tester,
      overrides: <Object>[
        playerControllerProvider.overrideWith(
          () => _SeededPlayerController(
            PlayerControllerState(
              queue: <PlaybackItem>[item],
              currentItem: item,
            ),
          ),
        ),
      ],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RobyneShell)),
    );

    container.read(capsuleModeProvider.notifier).enter();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('shell-content')), findsNothing);

    // Two exits in the same tick: the state flips once, so a second
    // `exit()` must be a no-op rather than a second restore.
    container.read(capsuleModeProvider.notifier).exit();
    container.read(capsuleModeProvider.notifier).exit();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(container.read(capsuleModeProvider), isFalse);
    expect(find.byKey(const Key('shell-content')), findsOneWidget);
    expect(find.byKey(const Key('capsule-artwork')), findsNothing);
    expect(tester.takeException(), isNull);

    // The restored shell keeps working: collapsing again still reach the
    // capsule, so the restore did not strand the window in a half state.
    container.read(capsuleModeProvider.notifier).enter();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('capsule-drag-region')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the capsule queue button unfolds the playlist', (tester) async {
    final item = PlaybackItem.plugin(
      platform: 'Test',
      musicId: 'A',
      title: 'Capsule Track',
      raw: const <String, Object?>{'id': 'A'},
    );
    await _pumpShell(
      tester,
      overrides: <Object>[
        playerControllerProvider.overrideWith(
          () => _SeededPlayerController(
            PlayerControllerState(
              queue: <PlaybackItem>[item],
              currentItem: item,
            ),
          ),
        ),
      ],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RobyneShell)),
    );

    container.read(capsuleModeProvider.notifier).enter();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('capsule-playlist-panel')), findsNothing);
    // Remember where the bar is before the panel opens.
    final barBefore = tester.getTopLeft(
      find.byKey(const Key('capsule-drag-region')),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('capsule-drag-region'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('capsule-queue-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('capsule-playlist-panel')), findsOneWidget);
    // The playlist panel is the only surface on screen now.
    expect(find.text('Capsule Track'), findsOneWidget);
    // The panel unfolds *downward*: the bar must not move.
    final barAfter = tester.getTopLeft(
      find.byKey(const Key('capsule-drag-region')),
    );
    expect(barAfter.dy, barBefore.dy);
    final panelTop = tester.getTopLeft(
      find.byKey(const Key('capsule-playlist-panel')),
    );
    expect(panelTop.dy, greaterThan(barAfter.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening the playlist does not flash an overflow', (
    tester,
  ) async {
    // Regression: the OS resize trails the toggle, so for a frame or two
    // the panel was laid out inside the *old* short window and the column
    // overflowed — a visible flash of the striped warning on every open.
    final errors = <String>[];
    final original = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exceptionAsString());
    addTearDown(() => FlutterError.onError = original);

    final item = PlaybackItem.plugin(
      platform: 'Test',
      musicId: 'A',
      title: 'Capsule Track',
      raw: const <String, Object?>{'id': 'A'},
    );
    // The real capsule window size, so the panel faces the same cramped
    // constraints it does in the app.
    tester.view.physicalSize =
        Size(
          CapsuleWindow.windowWidth,
          CapsuleWindow.windowHeight(playlistOpen: false),
        ) *
        tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Object>[
          baseThemePackageProvider.overrideWithValue(xuanFixture()),
          playerControllerProvider.overrideWith(
            () => _SeededPlayerController(
              PlayerControllerState(
                queue: <PlaybackItem>[item],
                currentItem: item,
              ),
            ),
          ),
        ].cast(),
        child: const MaterialApp(home: RobyneShell()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(RobyneShell)),
    );
    container.read(capsuleModeProvider.notifier).enter();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    errors.clear();

    container.read(capsuleQueueOpenProvider.notifier).toggle();
    // Step the resize transient frame by frame.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(errors, isEmpty, reason: 'opening the playlist must not overflow');
  });
}

Future<void> _pumpShell(
  WidgetTester tester, {
  List<Object> overrides = const <Object>[],
}) async {
  tester.view.physicalSize =
      const Size(1280, 900) * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Object>[
        baseThemePackageProvider.overrideWithValue(xuanFixture()),
        ...overrides,
      ].cast(),
      child: const MaterialApp(home: RobyneShell()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

class _SeededPlayerController extends PlayerController {
  _SeededPlayerController(this._state);

  final PlayerControllerState _state;

  @override
  Future<PlayerControllerState> build() async => _state;
}
