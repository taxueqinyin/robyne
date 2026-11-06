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
import 'package:robyne/core/theme/infrastructure/token_resolver.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/player/presentation/player_bar.dart';
import 'package:robyne/features/search/application/search_controller.dart'
    as search_state;
import 'package:robyne/features/search/presentation/search_page.dart';
import 'package:robyne/features/library/application/library_providers.dart';
import 'package:robyne/features/playlists/application/playlist_providers.dart';
import 'package:robyne/features/playlists/domain/music_playlist.dart';
import 'package:robyne/features/discover/application/discover_controller.dart';
import 'package:robyne/features/discover/domain/online_collection.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/search/domain/music_item.dart';

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

  group('the phone search page can run a second search', () {
    testWidgets('the results page carries a keyword box', (tester) async {
      // The phone arrangement has no `topBar`, so the shell draws no global
      // search field. Without a field on the page itself the only way to look
      // for something else was to navigate back to the home header — the
      // results were a dead end with no way out except the nav bar.
      await _pumpShell(tester, _phonePortrait, _xuan());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RobyneShell)),
      );

      container.read(selectedTabProvider.notifier).select(RobyneTab.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SearchPage), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the field on the results page runs a new query', (
      tester,
    ) async {
      await _pumpShell(tester, _phonePortrait, _xuan());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RobyneShell)),
      );

      container.read(selectedTabProvider.notifier).select(RobyneTab.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.byType(TextField), 'second query');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        container.read(search_state.searchControllerProvider).value?.keyword,
        'second query',
      );
      // Still on the results page: submitting must not bounce the user
      // somewhere else to show them what they asked for.
      expect(container.read(selectedTabProvider), RobyneTab.search);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the field fits a landscape phone without overflow', (
      tester,
    ) async {
      // 800x360 is the cramped end of the mobile shell: the title, subtitle
      // and keyword box now all sit above the results.
      await _pumpShell(tester, _phoneLandscape, _xuan());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RobyneShell)),
      );

      container.read(selectedTabProvider.notifier).select(RobyneTab.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SearchPage), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the desktop shell still owns the only field', (tester) async {
      // The desktop on-screen invariant is unchanged: one field, in the top
      // bar, and no duplicate on the results page.
      await _pumpShell(tester, _desktop, _xuan());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RobyneShell)),
      );

      container.read(selectedTabProvider.notifier).select(RobyneTab.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SearchPage), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byKey(const Key('topbar-search-submit')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
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
    testWidgets('phone immersive surface closes on the visible back button', (
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
        _phonePortrait,
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
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RobyneShell)),
      );

      container.read(nowPlayingImmersiveProvider.notifier).open();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('now-playing-immersive')), findsOneWidget);

      await tester.tap(find.byKey(const Key('now-playing-close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(nowPlayingImmersiveProvider), isFalse);
      expect(find.byKey(const Key('now-playing-immersive')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'phone immersive surface consumes system back instead of the app',
      (tester) async {
        final item = PlaybackItem.plugin(
          platform: 'Test',
          musicId: 'A',
          title: 'Immersive Track',
          raw: const <String, Object?>{'id': 'A'},
        );
        await _pumpShell(
          tester,
          _phonePortrait,
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
        final container = ProviderScope.containerOf(
          tester.element(find.byType(RobyneShell)),
        );

        container.read(nowPlayingImmersiveProvider.notifier).open();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final navigatorState = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        final maybePopped = navigatorState.maybePop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // PopScope intercepts the pop: the shell stays and the player closes
        // rather than the route being removed (which on Android means "leave
        // the app").
        expect(maybePopped, completes);
        expect(container.read(nowPlayingImmersiveProvider), isFalse);
        expect(find.byType(RobyneShell), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
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

    testWidgets('the discover drill-down lights up the top-bar back', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        _desktop,
        _xuan(),
        overrides: <Object>[
          discoverControllerProvider.overrideWith(
            _SeededDiscoverController.new,
          ),
        ],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RobyneShell)),
      );
      expect(_topbarBackEnabled(tester), isFalse);

      // Opening a collection is page-local state, so the shell only learns
      // about it through the history entry the router records from the page's
      // key. Without that the arrow stayed dark and a ranking became a dead
      // end.
      await container
          .read(discoverControllerProvider.notifier)
          .openCollection(_collection);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        container.read(discoverControllerProvider).selectedCollection,
        isNotNull,
      );
      expect(_topbarBackEnabled(tester), isTrue);

      await tester.tap(find.byKey(const Key('topbar-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        container.read(discoverControllerProvider).selectedCollection,
        isNull,
      );

      // Forward must land on the same drill-down: the history only carries the
      // key, so this also covers the lookup back into the loaded catalogue.
      await tester.tap(find.byKey(const Key('topbar-forward')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        container.read(discoverControllerProvider).selectedCollectionKey,
        _collection.uniqueKey,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the system back closes the drill-down, not the app', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        _phonePortrait,
        _xuan(),
        overrides: <Object>[
          discoverControllerProvider.overrideWith(
            _SeededDiscoverController.new,
          ),
        ],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RobyneShell)),
      );
      await container
          .read(discoverControllerProvider.notifier)
          .openCollection(_collection);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final navigatorState = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      final maybePopped = navigatorState.maybePop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Without the PopScope the gesture would leave the app from inside a
      // ranking, which reads exactly like the back button doing nothing.
      expect(maybePopped, completes);
      expect(
        container.read(discoverControllerProvider).selectedCollection,
        isNull,
      );
      expect(find.byType(RobyneShell), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping 发现 again returns the drill-down to the catalogue', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        _desktop,
        _xuan(),
        overrides: <Object>[
          discoverControllerProvider.overrideWith(
            _SeededDiscoverController.new,
          ),
        ],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RobyneShell)),
      );
      await container
          .read(discoverControllerProvider.notifier)
          .openCollection(_collection);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_topbarBackEnabled(tester), isTrue);

      // The nav entry is the phone-shaped back: no panel arrow, and a short
      // landscape window has no top bar at all.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('shell-nav-left')),
          matching: find.text('发现'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        container.read(discoverControllerProvider).selectedCollection,
        isNull,
      );
      // Closing rewrites the history entry instead of stacking a second one,
      // so the back arrow cannot re-open the page the user just left.
      expect(_topbarBackEnabled(tester), isFalse);
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

  testWidgets('a rail playlist drops its highlight when another tab opens', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      _desktop,
      _xuan(),
      overrides: <Object>[
        playlistControllerProvider.overrideWith(_SeededPlaylistController.new),
      ],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RobyneShell)),
    );
    final selectedFill = RobyneTheme.of(
      tester.element(find.byType(RobyneShell)),
    ).tokens.components.navBar.selectedIndicatorFill;

    Color? railPlaylistFill() {
      return tester
          .widget<Material>(
            find
                .ancestor(
                  of: find.descendant(
                    of: find.byKey(const Key('shell-nav-left')),
                    matching: find.text('Rail playlist'),
                  ),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color;
    }

    container.read(selectedPlaylistIdProvider.notifier).select('playlist:rail');
    container.read(selectedTabProvider.notifier).select(RobyneTab.playlists);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(railPlaylistFill(), selectedFill);

    // The rail's playlist id survives the destination change (the back stack
    // needs it), but the highlight must not: two rows used to look selected.
    for (final tab in <RobyneTab>[
      RobyneTab.discover,
      RobyneTab.library,
      RobyneTab.downloads,
    ]) {
      container.read(selectedTabProvider.notifier).select(tab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(railPlaylistFill(), isNot(selectedFill), reason: '$tab');
      expect(container.read(selectedPlaylistIdProvider), 'playlist:rail');
    }
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

  group('the flagship discover page', () {
    testWidgets('desktop leads with sources, rankings and hot playlists', (
      tester,
    ) async {
      await _pumpShell(tester, _desktop, _xuan());

      // Both catalogue sections are first-level content now; the plugin
      // browser that used to hide them one level down is gone.
      expect(find.text('发现'), findsWidgets);
      expect(find.text('排行榜'), findsOneWidget);
      expect(find.text('热门歌单'), findsOneWidget);
      // The daily radio block was removed with the old home composition.
      expect(find.text('每日电台'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'portrait phone keeps both sections and drops the old shelves',
      (tester) async {
        await _pumpShell(tester, _phonePortrait, _xuan());

        expect(find.text('排行榜'), findsOneWidget);
        expect(find.text('热门歌单'), findsOneWidget);
        expect(find.text('分类歌单'), findsNothing);
        expect(find.text('红心歌曲'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('landscape phone stacks the two sections without overflow', (
      tester,
    ) async {
      await _pumpShell(tester, _phoneLandscape, _xuan());

      // 800x360 is the historical overflow case: the compact header plus two
      // stacked sections must still fit.
      expect(find.text('排行榜'), findsOneWidget);
      expect(find.text('热门歌单'), findsOneWidget);
      expect(find.text('为你推荐'), findsNothing);
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

/// One manual playlist, so the rail has a row to light up.
class _SeededPlaylistController extends PlaylistController {
  @override
  Future<List<MusicPlaylist>> build() async => const <MusicPlaylist>[
    MusicPlaylist(
      id: 'playlist:rail',
      name: 'Rail playlist',
      isFavorites: false,
      items: <PlaybackItem>[],
    ),
  ];
}

/// One collection for the drill-down history test: the page only ever puts
/// its key in the snapshot, so the fixture needs nothing but an identity.
const OnlineCollectionItem _collection = OnlineCollectionItem(
  id: 'top-1',
  pluginId: 'fixture-plugin-0',
  platform: 'Fixture',
  kind: OnlineCollectionKind.topList,
  title: 'Top 50',
  raw: <String, Object?>{'id': 'top-1'},
);

bool _topbarBackEnabled(WidgetTester tester) {
  final button = tester.widget<IconButton>(
    find.descendant(
      of: find.byKey(const Key('topbar-back')),
      matching: find.byType(IconButton),
    ),
  );
  return button.onPressed != null;
}

/// A discover controller with the network taken out.
///
/// The drill-down is page state, so the history wiring can be tested without
/// a plugin round-trip: `openCollection` records the selection and the panel
/// renders the (empty) track list.
class _SeededDiscoverController extends DiscoverController {
  @override
  DiscoverState build() => DiscoverState(
    pluginSignature: discoverPluginSignature(const <PluginDefinition>[]),
    // The catalogue has to hold the item: the history only stores its key, so
    // the forward arrow restores the drill-down by looking it up here.
    hotPlaylistItems: const <OnlineCollectionItem>[_collection],
  );

  @override
  Future<void> syncPlugins(List<PluginDefinition> plugins) async {}

  @override
  Future<void> openCollection(OnlineCollectionItem collection) {
    state = state.copyWith(
      selectedCollection: collection,
      detail: OnlineCollectionDetail(
        collection: collection,
        items: const <MusicItem>[],
        page: 1,
        isEnd: true,
      ),
    );
    return Future<void>.value();
  }
}
