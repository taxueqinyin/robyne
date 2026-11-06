import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/app/router.dart';
import 'package:robyne/core/layout/window_size_class.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/core/theme/domain/theme_regions.dart';
import 'package:robyne/features/discover/application/discover_controller.dart';
import 'package:robyne/features/downloads/application/download_providers.dart';
import 'package:robyne/features/library/application/library_providers.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/playlists/domain/music_playlist.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/search/domain/search_history_entry.dart';
import 'package:robyne/features/settings/domain/user_settings.dart';
import 'package:robyne/features/downloads/domain/download_task.dart';
import 'package:robyne/features/plugin/application/plugin_controller.dart';
import 'package:robyne/features/search/application/search_controller.dart'
    as search_state;
import 'package:robyne/features/search/application/search_history_controller.dart';
import 'package:robyne/features/settings/application/settings_providers.dart';
import 'package:robyne/features/playlists/application/playlist_providers.dart';

import 'support/fixture_artwork.dart';
import 'support/fixture_data.dart';
import 'support/xuan_fixture.dart';

/// Renders the app's real surfaces to PNGs so the design boards cannot drift.
///
/// The boards under `docs/design/mockups/` were hand-drawn once and then
/// rotted: thirty-odd commits later the flagship skin had moved its brand
/// colour, inverted the Now Playing surface and dropped the sidebar's profile
/// block, and none of that was visible in the mockups. Hand-drawing them
/// again would only restart the same clock.
///
/// These tests are the opposite bet: the board is *produced by the app*, so
/// there is nothing to keep in sync. Each board is one `matchesGoldenFile`
/// against a surface driven by the same providers production uses.
///
/// Run them explicitly:
///
/// ```
/// flutter test test/design_boards_test.dart --tags boards --update-goldens
/// ```
///
/// The tag keeps them out of `flutter test`: a board asserts nothing about
/// behaviour, and thirty full-window captures are not something a developer
/// wants between a save and a commit.
///
/// Every board also writes its resolved [RobyneShellPlan] next to the PNG as
/// `<name>.plan.json`. That is the layout layer `docs/design/mockups/index.html`
/// overlays: the numbers come from `RobyneShellPlan.resolve` itself, so the
/// annotation cannot disagree with the pixels underneath it.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader(
      'MiSans',
    )..addFont(rootBundle.load('assets/fonts/MiSansVF.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await FixtureArtwork.install();
  });

  // ---------------------------------------------------------------- desktop
  group('desktop boards', () {
    for (final board in _DesktopBoard.values) {
      _board(board.name, board);
    }
  });

  // ----------------------------------------------------------------- phone
  group('phone boards', () {
    for (final board in _PhoneBoard.values) {
      _board(board.name, board);
    }
  });

  // ------------------------------------------------------- responsive grid
  //
  // Five viewports, each landing on a different cell of the size-class matrix
  // (`window_size_class.dart:49`): expanded/expanded, expanded/medium,
  // medium/expanded, compact/expanded and medium/*compact height*. The last
  // one is the only set that shows the D7 degradation (no top bar), which is
  // why a landscape phone cannot be represented by a portrait one.
  group('responsive boards', () {
    for (final size in _ResponsiveSize.values) {
      for (final tab in _ResponsiveSize.skeletonTabs) {
        _board('${size.name}-${tab.name}', _ResponsiveBoard(size, tab));
      }
    }
  });
}

/// One board, tagged and opt-in.
///
/// `--tags boards` keeps these out of `flutter test`: a board asserts nothing
/// about behaviour, and a full-window capture is slow. `--update-goldens` is
/// what regenerates the PNGs; a plain run compares against them.
void _board(String name, Object board) {
  testWidgets(
    name,
    (tester) async {
      await _pumpBoard(tester, board);
      await _capture(tester, name);
    },
    tags: <String>['boards'],
    // Opt-in on top of the tag: `flutter test --tags boards` still runs them
    // deliberately, but a bare `flutter test` must skip the forty-five
    // full-window captures rather than pay for them on every commit.
    skip: !Platform.environment.containsKey('ROBYNE_BOARDS'),
  );
}

/// A desktop-window board: one destination, one state, at 1360x900.
enum _DesktopBoard {
  discover('desktop-discover', RobyneTab.discover),
  library('desktop-library', RobyneTab.library),
  search('desktop-search', RobyneTab.search),
  playlists('desktop-playlists', RobyneTab.playlists),
  downloads('desktop-downloads', RobyneTab.downloads),
  plugins('desktop-plugins', RobyneTab.plugins),
  settings('desktop-settings', RobyneTab.settings),
  settingsAppearance(
    'desktop-settings-appearance',
    RobyneTab.settings,
    settingsTab: 1,
  ),
  settingsShortcuts(
    'desktop-settings-shortcuts',
    RobyneTab.settings,
    settingsTab: 2,
  ),
  settingsLyrics('desktop-settings-lyrics', RobyneTab.settings, settingsTab: 3),
  queueDocked('desktop-queue-docked', RobyneTab.discover, queue: true),
  queueOverlay('desktop-queue-overlay', RobyneTab.library, queue: true),
  nowPlaying('desktop-now-playing', RobyneTab.nowPlaying, immersive: true);

  const _DesktopBoard(
    this.name,
    this.tab, {
    this.settingsTab = 0,
    this.queue = false,
    this.immersive = false,
  });

  final String name;
  final RobyneTab tab;
  final int settingsTab;
  final bool queue;
  final bool immersive;

  Size get size => const Size(1360, 900);
}

/// A phone board.
enum _PhoneBoard {
  portraitDiscover('mobile-portrait-discover', RobyneTab.discover),
  portraitLibrary('mobile-portrait-library', RobyneTab.library),
  portraitSearch('mobile-portrait-search', RobyneTab.search),
  portraitMine('mobile-portrait-mine', RobyneTab.playlists),
  queueDrawer('mobile-queue-drawer', RobyneTab.discover, queue: true),
  landscapeDiscover('mobile-landscape-discover', RobyneTab.discover);

  const _PhoneBoard(this.name, this.tab, {this.queue = false});

  final String name;
  final RobyneTab tab;
  final bool queue;

  Size get size => name.startsWith('mobile-landscape')
      ? const Size(800, 360)
      : const Size(400, 800);
}

/// The five viewports the skeleton tabs are captured at.
enum _ResponsiveSize {
  desktopWide('desktop-1360x900', 1360, 900),
  desktopMedium('desktop-960x700', 960, 700),
  desktopNarrow('desktop-760x760', 760, 760),
  phonePortrait('phone-400x800', 400, 800),
  phoneLandscape('phone-800x360', 800, 360);

  const _ResponsiveSize(this.name, this.width, this.height);

  final String name;
  final double width;
  final double height;

  Size get size => Size(width, height);

  /// The destinations whose chrome is worth pinning at every size.
  ///
  /// Not every page: 34 boards x 5 sizes is 170 captures, and a board of the
  /// plugin list at 760dp says nothing the 1360dp board does not. These five
  /// are the ones whose layout actually changes — the ones carrying a rail, a
  /// queue, a search field or a tab bar.
  static const List<RobyneTab> skeletonTabs = <RobyneTab>[
    RobyneTab.discover,
    RobyneTab.library,
    RobyneTab.search,
    RobyneTab.playlists,
    RobyneTab.settings,
  ];
}

/// One skeleton tab at one viewport.
class _ResponsiveBoard {
  const _ResponsiveBoard(this.size, this.tab);

  final _ResponsiveSize size;
  final RobyneTab tab;

  String get name => '${size.name}-${tab.name}';
}

/// Pumps [RobyneShell] at the board's size with every provider seeded.
Future<void> _pumpBoard(WidgetTester tester, Object board) async {
  final size = switch (board) {
    _DesktopBoard() => board.size,
    _PhoneBoard() => board.size,
    _ResponsiveBoard() => board.size.size,
    _ => throw ArgumentError('unknown board $board'),
  };
  final tab = switch (board) {
    _DesktopBoard() => board.tab,
    _PhoneBoard() => board.tab,
    _ResponsiveBoard() => board.tab,
    _ => throw ArgumentError('unknown board $board'),
  };
  final queue = board is _DesktopBoard
      ? board.queue
      : board is _PhoneBoard
      ? board.queue
      : false;

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Object>[
        baseThemePackageProvider.overrideWithValue(xuanFixture()),
        settingsControllerProvider.overrideWith(
          () => _SeededSettingsController(FixtureData.settings),
        ),
        playerControllerProvider.overrideWith(
          () => _SeededPlayerController(
            PlayerControllerState(
              queue: FixtureData.tracks,
              currentItem: FixtureData.nowPlaying,
              history: FixtureData.history,
              lastPosition: const Duration(seconds: 84),
              lastDuration: FixtureData.nowPlaying.duration ?? Duration.zero,
            ),
          ),
        ),
        localMusicLibraryProvider.overrideWith(
          () => _SeededLibraryController(FixtureData.tracks),
        ),
        playlistControllerProvider.overrideWith(
          () => _SeededPlaylistController(FixtureData.playlists),
        ),
        downloadControllerProvider.overrideWith(
          () => _SeededDownloadController(FixtureData.downloads),
        ),
        pluginControllerProvider.overrideWith(
          () => _SeededPluginController(FixtureData.plugins),
        ),
        searchHistoryControllerProvider.overrideWith(
          () => _SeededSearchHistoryController(FixtureData.searchHistory),
        ),
        search_state.searchControllerProvider.overrideWith(
          () => _SeededSearchController(),
        ),
        discoverControllerProvider.overrideWith(_SeededDiscoverController.new),
        if (queue) queuePanelVisibleProvider.overrideWith(() => _TrueQueue()),
      ].cast(),
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

  final container = ProviderScope.containerOf(
    tester.element(find.byType(RobyneShell)),
  );
  container.read(selectedTabProvider.notifier).select(tab);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  // Covers resolve through `ArtworkView`, which stats a `file://` url with
  // real IO. The stepped test clock never gives that future a turn, so every
  // cover would render as the grey fallback and the boards would show nothing
  // of the material layer. `runAsync` hands the loop back to the platform for
  // one real turn; the extra pump then drains the rebuilds it triggered.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));

  if (board is _DesktopBoard) {
    await _applyDesktopState(tester, container, board);
  }
}

/// Settings tabs and the immersive player need interaction, not just a tab.
Future<void> _applyDesktopState(
  WidgetTester tester,
  dynamic container,
  _DesktopBoard board,
) async {
  if (board.settingsTab > 0) {
    // The settings surface owns a TabBar; there is no key on it, so drive it
    // through the tab's own controller the way a click would.
    final tabs = find.byType(Tab);
    if (tabs.evaluate().length > board.settingsTab) {
      await tester.tap(tabs.at(board.settingsTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }
  if (board.immersive) {
    container.read(nowPlayingImmersiveProvider.notifier).open();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// Writes the PNG and the layout annotation that goes with it.
Future<void> _capture(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(RobyneShell),
    matchesGoldenFile('goldens/boards/$name.png'),
  );

  // The layout layer. Written from the plan the shell actually resolved, so
  // the annotation cannot drift from the pixels: both come from the same
  // pump. `docs/design/mockups/index.html` reads these files to draw its
  // overlay, which is what keeps the mockup's numbers honest.
  final shell = tester.elementList(find.byType(RobyneShell)).firstOrNull;
  if (shell == null) {
    return;
  }
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final layout = ProviderScope.containerOf(
    shell,
  ).read(activeThemePackageProvider).layout;
  // The same form-factor decision the shell makes (`router.dart:153`). A
  // medium-width window in landscape is a *phone*: its height is compact, so
  // it cannot carry the desktop shell's rail plus bars. Re-deriving it here
  // rather than always reading `layout.desktop` is what makes the landscape
  // board's annotation match its pixels — the earlier version claimed a top
  // bar on a 360dp-tall window that had already dropped it.
  final sizeClass = WindowSizeClass.fromSize(size);
  final isDesktopShell =
      sizeClass.width == WindowWidthClass.expanded ||
      (sizeClass.width == WindowWidthClass.medium &&
          !sizeClass.isCompactHeight);
  final plan = RobyneShellPlan.resolve(
    arrangement: isDesktopShell
        ? layout.desktop.arrangement
        : layout.mobile.arrangement,
    width: size.width,
    height: size.height,
  );
  final json = const JsonEncoder.withIndent('  ').convert(_planToJson(plan));
  // Real IO inside a widget test has to go through `runAsync`: the test
  // binding owns the microtask queue, and a plain `dart:io` await never
  // gets a turn while a frame is pending — which hangs the test rather than
  // failing it.
  await tester.runAsync(() async {
    final file = File('test/goldens/boards/$name.plan.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(json, flush: true);
  });
}

Map<String, Object?> _planToJson(RobyneShellPlan plan) {
  return <String, Object?>{
    'topBarVisible': plan.topBarVisible,
    'topExtent': plan.topExtent,
    'bottomExtent': plan.bottomExtent,
    'leftExtent': plan.leftExtent,
    'rightExtent': plan.rightExtent,
    'navSlot': plan.navSlot?.name,
    'navIconOnly': plan.navIconOnly,
    'queueSlot': plan.queueSlot?.name,
    'queueSideExtent': plan.queueSideExtent,
    'queueOverlay': plan.queueOverlay,
    'playerBarHeight': plan.playerBarHeight,
    'playerMini': plan.playerMini,
    'navBarBottomHeight': plan.navBarBottomHeight,
    'contentWidth': plan.contentWidth,
    'contentHeight': plan.contentHeight,
  };
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

class _SeededPlaylistController extends PlaylistController {
  _SeededPlaylistController(this._playlists);

  final List<MusicPlaylist> _playlists;

  @override
  Future<List<MusicPlaylist>> build() async => _playlists;
}

class _SeededDownloadController extends DownloadController {
  _SeededDownloadController(this._tasks);

  final List<DownloadTask> _tasks;

  @override
  Future<List<DownloadTask>> build() async => _tasks;
}

class _SeededPluginController extends PluginController {
  _SeededPluginController(this._plugins);

  final List<PluginDefinition> _plugins;

  @override
  Future<List<PluginDefinition>> build() async => _plugins;
}

class _SeededSearchHistoryController extends SearchHistoryController {
  _SeededSearchHistoryController(this._entries);

  final List<SearchHistoryEntry> _entries;

  @override
  Future<List<SearchHistoryEntry>> build() async => _entries;
}

class _SeededSearchController extends search_state.SearchController {
  @override
  search_state.SearchState build() => search_state.SearchState(
    keyword: '林俊杰',
    pluginResults: <search_state.PluginSearchState>[
      search_state.PluginSearchState(
        pluginId: 'fixture-plugin-0',
        platform: '酷我',
        result: FixtureData.searchResult,
      ),
    ],
  );
}

class _SeededSettingsController extends SettingsController {
  _SeededSettingsController(this._settings);

  final UserSettings _settings;

  @override
  Future<UserSettings> build() async => _settings;
}

class _TrueQueue extends QueuePanelNotifier {
  @override
  bool? build() => true;
}

/// The discovery shelves, seeded rather than fetched.
///
/// [DiscoverController] is an ordinary `Notifier`, so the board can hand it a
/// state directly instead of stubbing a plugin round trip.
class _SeededDiscoverController extends DiscoverController {
  @override
  DiscoverState build() => DiscoverState(
    pluginSignature: discoverPluginSignature(FixtureData.plugins),
    selectedPluginId: 'fixture-plugin-0',
    topListGroups: FixtureData.topListGroups,
    hotPlaylistItems: FixtureData.hotPlaylists,
  );

  // The board seeds the catalogue directly; syncing would reset it and then
  // try to read fixture plugin files that do not exist on disk.
  @override
  Future<void> syncPlugins(List<PluginDefinition> plugins) async {}
}
