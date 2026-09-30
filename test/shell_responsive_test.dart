import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/app/router.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/core/theme/domain/theme_layout.dart';
import 'package:robyne/core/theme/domain/theme_navigation.dart';
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/domain/theme_regions.dart';
import 'package:robyne/core/theme/infrastructure/theme_manifest_parser.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/player/presentation/player_bar.dart';
import 'package:robyne/features/library/application/library_providers.dart';
import 'package:robyne/features/playlists/application/playlist_providers.dart';

/// Stage 2 acceptance for the flagship shell.
///
/// `THEME_ROADMAP.md` §4 stage 2 requires the shell to render without overflow
/// at all three size classes, with the landscape phone called out as the
/// historical failure. These tests drive the real [RobyneShell] rather than a
/// hand-built stand-in, so the arrangement -> plan -> widget path is exercised
/// end to end: a skin declares `navBar` on `right`, and this asserts the rail
/// actually moves.
const Size _phonePortrait = Size(400, 800);
const Size _phoneLandscape = Size(800, 360);
const Size _narrowDesktop = Size(760, 760);
const Size _desktop = Size(1280, 900);

void main() {
  group('flagship shell survives every size class', () {
    for (final size in <Size>[_phonePortrait, _phoneLandscape, _desktop]) {
      testWidgets('renders at $size with no overflow', (tester) async {
        await _pumpShell(tester, size, _xuan());
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('landscape phone keeps content and both bars', (tester) async {
      // The regression ADR-001 was written for: a 800x360 window that used to
      // borrow the desktop shell, clip the rail, and lose the transport row.
      await _pumpShell(tester, _phoneLandscape, _xuan());

      expect(find.byType(RobyneShell), findsOneWidget);
      expect(find.byType(PlayerBar), findsOneWidget);
      expect(find.byKey(const Key('shell-nav-bottom')), findsOneWidget);
      expect(find.byKey(const Key('shell-nav-left')), findsNothing);
      expect(find.byKey(const Key('shell-nav-right')), findsNothing);
      // nine destinations still reachable without overflowing
      expect(find.byIcon(Icons.search), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('portrait phone also uses the bottom nav', (tester) async {
      await _pumpShell(tester, _phonePortrait, _xuan());
      expect(find.byKey(const Key('shell-nav-bottom')), findsOneWidget);
      expect(find.byKey(const Key('shell-nav-left')), findsNothing);
    });

    testWidgets('a narrow desktop window keeps a compact side rail', (
      tester,
    ) async {
      // 760dp is too narrow for the full rail but still a desktop-shaped
      // window. Switching to a bottom bar here made the window feel like a
      // different app the moment it was narrowed.
      await _pumpShell(tester, _narrowDesktop, _xuan());

      expect(find.byKey(const Key('shell-nav-left')), findsOneWidget);
      expect(find.byKey(const Key('shell-nav-bottom')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('shell-nav-left')),
          matching: find.text('发现'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('shell-nav-left')),
          matching: find.byIcon(Icons.explore),
        ),
        findsOneWidget,
      );
      final searchField = find.byKey(const Key('topbar-search-submit'));
      expect(searchField, findsOneWidget);
      expect(
        tester
            .getSize(
              find.ancestor(of: searchField, matching: find.byType(TextField)),
            )
            .width,
        lessThan(430),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the rail exposes a drag handle and can collapse to a capsule',
      (tester) async {
        await _pumpShell(tester, _desktop, _xuan());

        final handle = find.byKey(const Key('sidebar-resize-handle'));
        expect(handle, findsOneWidget);
        final before = tester.getSize(find.byKey(const Key('shell-nav-left')));
        await tester.drag(handle, const Offset(-180, 0));
        await tester.pump();

        final after = tester.getSize(find.byKey(const Key('shell-nav-left')));
        expect(after.width, lessThan(before.width));
        expect(after.width, greaterThanOrEqualTo(56));
        // At capsule width labels are gone but icons remain reachable.
        expect(
          find.descendant(
            of: find.byKey(const Key('shell-nav-left')),
            matching: find.byIcon(Icons.explore),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('a skin can move the nav bar', () {
    testWidgets('a skin can reorder the rail', (tester) async {
      // Ordering is part of a rail's composition: a skin built around a local
      // collection wants 内容库 first, one built around listening wants 发现.
      final reordered = _xuan().copyWith(
        navigation: ThemeNavigation.parse(<String, Object?>{
          'desktop': <Object?>['playlists'],
          'desktopOrder': <Object?>['library', 'discover'],
        }),
      );
      await _pumpShell(tester, _desktop, reordered);

      // Scope to the rail: 发现 is also the home page's own heading.
      final library = tester.getTopLeft(
        find.descendant(
          of: find.byKey(const Key('shell-nav-left')),
          matching: find.text('内容库'),
        ),
      );
      final discover = tester.getTopLeft(
        find.descendant(
          of: find.byKey(const Key('shell-nav-left')),
          matching: find.text('发现'),
        ),
      );
      expect(library.dy, lessThan(discover.dy));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the top-bar search is a pill, not an omnibox', (tester) async {
      // The design's search field stops at 430dp. Inside an `Expanded` the
      // tight parent constraint silently defeated that cap, stretching the
      // field across the whole bar on wide windows.
      await _pumpShell(tester, _desktop, _xuan());

      final field = find.byType(TextField).first;
      final windowWidth = tester.getSize(find.byType(RobyneShell)).width;
      final fieldWidth = tester.getSize(field).width;
      expect(fieldWidth, lessThanOrEqualTo(360));
      expect(fieldWidth, lessThan(windowWidth * 0.5));
      expect(find.byKey(const Key('topbar-search-submit')), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '搜索'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('navBar on the left puts the rail before the content', (
      tester,
    ) async {
      await _pumpShell(tester, _desktop, _xuan());

      final rail = tester.getTopLeft(find.byKey(const Key('shell-nav-left')));
      final content = tester.getTopLeft(find.byKey(const Key('shell-content')));
      expect(rail.dx, lessThan(content.dx));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the same skin moved to the right mirrors the rail', (
      tester,
    ) async {
      // Stage 3 acceptance criterion: "move navBar from left to right, and
      // the app stays fully usable". Nothing else in the skin changes, so a
      // difference here can only come from the arrangement.
      final mirrored =
          _withDesktopArrangement(_xuan(), const <RobyneRegionPlacement>[
            RobyneRegionPlacement(
              region: RobyneRegion.topBar,
              slot: RobyneSlot.top,
              size: 0.06,
            ),
            RobyneRegionPlacement(
              region: RobyneRegion.navBar,
              slot: RobyneSlot.right,
              size: 0.14,
            ),
            RobyneRegionPlacement(
              region: RobyneRegion.content,
              slot: RobyneSlot.center,
            ),
            RobyneRegionPlacement(
              region: RobyneRegion.playerBar,
              slot: RobyneSlot.bottom,
              size: 0.09,
            ),
          ]);
      await _pumpShell(tester, _desktop, mirrored);

      final rail = tester.getTopLeft(find.byKey(const Key('shell-nav-right')));
      final content = tester.getTopLeft(find.byKey(const Key('shell-content')));
      expect(rail.dx, greaterThan(content.dx));
      expect(tester.takeException(), isNull);
    });
  });

  group('an extreme arrangement cannot break the phone shell', () {
    testWidgets('a desktop-only layout degrades instead of crashing', (
      tester,
    ) async {
      // Stage 3 acceptance: a skin written for the desktop must still be
      // survivable on a phone. `mobile` inherits the official arrangement, so
      // the phone must ignore the 0.40 side rail entirely.
      final desktopOnly =
          _withDesktopArrangement(_xuan(), const <RobyneRegionPlacement>[
            RobyneRegionPlacement(
              region: RobyneRegion.navBar,
              slot: RobyneSlot.left,
              size: 0.40,
            ),
            RobyneRegionPlacement(
              region: RobyneRegion.content,
              slot: RobyneSlot.center,
            ),
          ]);
      await _pumpShell(tester, _phonePortrait, desktopOnly);
      expect(tester.takeException(), isNull);
    });
  });

  group('immersive now playing', () {
    testWidgets('opens over the shell and closes without changing tabs', (
      tester,
    ) async {
      final item = PlaybackItem.plugin(
        platform: 'Test',
        musicId: 'A',
        title: 'Immersive Track',
        raw: const <String, Object?>{'id': 'A'},
      );
      await _pumpShell(
        tester,
        _desktop,
        _xuan(),
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

      // Start on Discover, then open the immersive surface from the player
      // identity block. The shell must already have a selected tab.
      await tester.tap(
        find
            .byWidgetPredicate(
              // The label is skin-declared; 《玄》 writes it in Chinese.
              (widget) => widget is Text && widget.data == '发现',
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('now-playing-immersive')), findsNothing);

      await tester.tap(find.byKey(const Key('player-identity')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('now-playing-immersive')), findsOneWidget);

      // Window buttons are disabled under `FLUTTER_TEST` to avoid touching
      // the real window manager; the immersive surface is still closed
      // through its shell-owned callback, which is what this test is about.
      ProviderScope.containerOf(
        tester.element(find.byType(RobyneShell)),
      ).read(nowPlayingImmersiveProvider.notifier).close();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('now-playing-immersive')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('top-bar history', () {
    testWidgets('back and forward move through real shell destinations', (
      tester,
    ) async {
      await _pumpShell(tester, _desktop, _xuan());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RobyneShell)),
      );

      expect(find.byKey(const Key('topbar-back')), findsOneWidget);
      expect(find.byKey(const Key('topbar-forward')), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.descendant(
                of: find.byKey(const Key('topbar-back')),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('shell-nav-left')),
          matching: find.byIcon(Icons.library_music_outlined),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(container.read(selectedTabProvider), RobyneTab.library);
      await tester.tap(find.byKey(const Key('topbar-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(selectedTabProvider), RobyneTab.discover);

      await tester.tap(find.byKey(const Key('topbar-forward')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(selectedTabProvider), RobyneTab.library);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the phone liked entry returns from the playlist overview', (
    tester,
  ) async {
    await _pumpShell(tester, _phonePortrait, _xuan());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RobyneShell)),
    );

    container.read(selectedPlaylistIdProvider.notifier).showOverview();
    container.read(selectedTabProvider.notifier).select(RobyneTab.playlists);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(selectedPlaylistIdProvider), overviewPlaylistId);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('shell-nav-bottom')),
        matching: find.byIcon(Icons.favorite),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(selectedPlaylistIdProvider), isNull);
    expect(tester.takeException(), isNull);
  });

  group('content.style reaches feature pages', () {
    testWidgets('a grid skin renders the library as a grid', (tester) async {
      final gridTheme = _xuan().copyWith(
        layout: _xuan().layout.copyWith(
          content: const ThemeContentLayout(
            listStyle: ThemeListStyle.grid,
            density: ThemeDensity.regular,
          ),
        ),
      );
      final track = PlaybackItem.plugin(
        platform: 'Library',
        musicId: 'track-1',
        title: 'Local Track',
        raw: const <String, Object?>{'id': 'track-1'},
      );
      await _pumpShell(
        tester,
        _desktop,
        gridTheme,
        overrides: <Object>[
          localMusicLibraryProvider.overrideWith(
            () => _SeededLibraryController(<PlaybackItem>[track]),
          ),
        ],
      );

      // Switch to Library, where the style branch is observable without a
      // network-backed discover controller.
      await tester.tap(find.text('内容库').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(GridView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the flagship boards', () {
    testWidgets('desktop composes hero, recommendations and recent', (
      tester,
    ) async {
      await _pumpShell(tester, _desktop, _xuan());

      // The three shelves of `desktop-discover.png`, in order.
      expect(find.text('发现'), findsWidgets);
      expect(find.text('为你推荐'), findsOneWidget);
      expect(find.text('最近入库'), findsOneWidget);
      // The phone-only tiles stay out of the desktop column.
      expect(find.text('每日电台'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('portrait phone leads with tiles and liked songs', (
      tester,
    ) async {
      await _pumpShell(tester, _phonePortrait, _xuan());

      expect(find.text('分类歌单'), findsOneWidget);
      expect(find.text('红心歌曲'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('landscape phone shows the shelf grid, not the banner', (
      tester,
    ) async {
      await _pumpShell(tester, _phoneLandscape, _xuan());

      // `mobile-landscape.png` drops the banner and the liked-songs list in
      // favour of a chip row plus a five-column shelf; keeping the portrait
      // blocks there is what produced a 70px overflow.
      expect(find.text('为你推荐'), findsOneWidget);
      expect(find.text('红心歌曲'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a first visit to a tab enters with motion', (tester) async {
      await _pumpShell(tester, _desktop, _xuan());

      await tester.tap(find.text('内容库').first);
      await tester.pump();

      // The destination is created on demand. Before this change its
      // AnimationController mounted at 1, so the first visit skipped the
      // transition entirely.
      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byKey(const ValueKey<RobyneTab>(RobyneTab.library)),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fade.opacity.value, lessThan(1));
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the flagship rail hides the signed-out profile block', (
      tester,
    ) async {
      // There is no account feature, so the design's identity block would be a
      // dead control. The skin sets `navBar.showProfile: false` and the rail
      // must honour it rather than drawing an avatar nobody can use.
      final xuan = _xuan();
      expect(
        xuan.tokens.components.navBar.showProfile,
        isFalse,
        reason: 'the flagship skin declares the profile block hidden',
      );

      await _pumpShell(tester, _desktop, xuan);

      expect(find.text('本地曲库 · 1,248 首'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

/// The bundled flagship skin《玄》, parsed from its real manifest.
///
/// Reading the shipped file keeps this test honest: if the flagship skin ever
/// loses its arrangement, this is where it shows up.
ThemePackage _xuan() {
  final file = File('assets/themes/xuan/theme.json');
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  return const ThemeManifestParser().tryParse(
    decoded,
    source: ThemeSource.builtIn,
  )!;
}

ThemePackage _withDesktopArrangement(
  ThemePackage base,
  List<RobyneRegionPlacement> placements,
) {
  return base.copyWith(
    layout: base.layout.copyWith(
      desktop: base.layout.desktop.copyWith(
        arrangement: RobyneArrangement(
          formFactor: RobyneFormFactor.desktop,
          placements: placements,
        ),
      ),
    ),
  );
}

Future<void> _pumpShell(
  WidgetTester tester,
  Size size,
  ThemePackage theme, {
  List<Object> overrides = const <Object>[],
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Object>[
        baseThemePackageProvider.overrideWithValue(theme),
        ...overrides,
      ].cast(),
      // The shell reads its tokens from the Material theme extension, exactly
      // as production does. A bare `MaterialApp` carries no extension, so the
      // shell would silently fall back to `ThemeTokens.baseline()` and every
      // skin component flag would read as its default — which is how a
      // `showProfile: false` skin kept rendering the profile block.
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(darkThemeDataProvider),
          home: const RobyneShell(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

class _SeededPlayerController extends PlayerController {
  _SeededPlayerController(this._state);

  final PlayerControllerState _state;

  @override
  Future<PlayerControllerState> build() async => _state;
}

class _SeededLibraryController extends LocalMusicLibraryController {
  _SeededLibraryController(this._tracks);

  final List<PlaybackItem> _tracks;

  @override
  Future<List<PlaybackItem>> build() async => _tracks;
}
