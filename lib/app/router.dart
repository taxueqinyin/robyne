import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/debug/ime_trace.dart';
import '../features/discover/presentation/discover_page.dart';
import '../features/lyrics/application/desktop_lyric_window_controller.dart';
import '../features/lyrics/application/lyrics_providers.dart';
import '../features/lyrics/domain/lyric_document.dart';
import '../features/player/presentation/player_bar.dart';
import '../features/player/presentation/now_playing_page.dart';
import '../features/player/presentation/queue_page.dart';
import '../features/downloads/presentation/downloads_page.dart';
import '../features/player/application/player_providers.dart';
import '../features/playlists/presentation/playlists_page.dart';
import '../features/playlists/application/playlist_providers.dart';
import '../features/plugin/presentation/plugin_page.dart';
import '../features/library/presentation/library_page.dart';
import '../features/search/presentation/search_page.dart';
import '../features/settings/application/settings_providers.dart';
import '../features/settings/application/shortcut_runtime.dart';
import '../features/settings/domain/lyric_settings.dart';
import '../features/settings/domain/shortcut_action.dart';
import '../features/settings/domain/shortcut_settings.dart';
import '../features/settings/presentation/settings_page.dart';

enum RobyneTab {
  search,
  discover,
  library,
  nowPlaying,
  queue,
  playlists,
  downloads,
  plugins,
  settings,
}

final selectedTabProvider = NotifierProvider<SelectedTabNotifier, RobyneTab>(
  SelectedTabNotifier.new,
);

class SelectedTabNotifier extends Notifier<RobyneTab> {
  @override
  RobyneTab build() => RobyneTab.search;

  void select(RobyneTab tab) {
    imeTrace('tab-select from=$state to=$tab');
    state = tab;
  }
}

class RobyneShell extends ConsumerStatefulWidget {
  const RobyneShell({super.key});

  @override
  ConsumerState<RobyneShell> createState() => _RobyneShellState();
}

class _RobyneShellState extends ConsumerState<RobyneShell> {
  final _mountedTabs = <RobyneTab>{RobyneTab.search};
  final ShortcutTracker _shortcutTracker = ShortcutTracker();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalShortcut);
    unawaited(_registerDesktopLyricControlHandler());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalShortcut);
    unawaited(desktopLyricControlChannel.setMethodCallHandler(null));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(selectedTabProvider);
    ref.listen<DesktopLyricPayload>(currentDesktopLyricPayloadProvider, (
      previous,
      next,
    ) {
      unawaited(ref.read(desktopLyricWindowControllerProvider).sync(next));
    });
    _mountedTabs.add(selectedTab);

    return Scaffold(
      body: Row(
        children: <Widget>[
          NavigationRail(
            selectedIndex: selectedTab.index,
            onDestinationSelected: (index) {
              ref
                  .read(selectedTabProvider.notifier)
                  .select(RobyneTab.values[index]);
            },
            labelType: NavigationRailLabelType.all,
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: Text('Search'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: Text('Discover'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music),
                label: Text('Library'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.album_outlined),
                selectedIcon: Icon(Icons.album),
                label: Text('Now Playing'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.queue_music_outlined),
                selectedIcon: Icon(Icons.queue_music),
                label: Text('Queue'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.playlist_play_outlined),
                selectedIcon: Icon(Icons.playlist_play),
                label: Text('Playlists'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.download_outlined),
                selectedIcon: Icon(Icons.download),
                label: Text('Downloads'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.extension_outlined),
                selectedIcon: Icon(Icons.extension),
                label: Text('Plugins'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      for (final tab in RobyneTab.values)
                        if (_mountedTabs.contains(tab))
                          Offstage(
                            offstage: selectedTab != tab,
                            child: TickerMode(
                              enabled: selectedTab == tab,
                              child: _TabContent(tab: tab),
                            ),
                          ),
                    ],
                  ),
                ),
                const PlayerBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _handleGlobalShortcut(KeyEvent event) {
    final settings =
        ref.read(settingsControllerProvider).value?.shortcuts ??
        ShortcutSettings.defaults();
    return _dispatchShortcut(event, settings);
  }

  bool _dispatchShortcut(KeyEvent event, ShortcutSettings settings) {
    if (ref.read(shortcutCaptureActiveProvider) || _isTextInputFocused()) {
      return false;
    }
    final action = _shortcutTracker.match(
      event,
      matchingShortcutActions(event, settings.bindings),
    );
    if (action != null) {
      unawaited(_executeShortcut(action));
      return true;
    }
    return false;
  }

  Future<void> _registerDesktopLyricControlHandler() async {
    await desktopLyricControlChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case desktopLyricToggleEnabledMethod:
          await ref
              .read(settingsControllerProvider.notifier)
              .toggleDesktopLyricsEnabled();
          return true;
        case desktopLyricToggleAlwaysOnTopMethod:
          await ref
              .read(settingsControllerProvider.notifier)
              .toggleDesktopLyricsAlwaysOnTop();
          return true;
        case desktopLyricDecreaseFontSizeMethod:
          await ref
              .read(settingsControllerProvider.notifier)
              .adjustDesktopLyricFontSize(-LyricSettings.fontSizeStep);
          return true;
        case desktopLyricIncreaseFontSizeMethod:
          await ref
              .read(settingsControllerProvider.notifier)
              .adjustDesktopLyricFontSize(LyricSettings.fontSizeStep);
          return true;
        case desktopLyricPreviousTrackMethod:
          await ref.read(playerControllerProvider.notifier).playPrevious();
          return true;
        case desktopLyricTogglePlaybackMethod:
          final snapshot = ref.read(playerSnapshotsProvider).value;
          if (snapshot?.playing == true) {
            await ref.read(playerControllerProvider.notifier).pause();
          } else {
            await ref
                .read(playerControllerProvider.notifier)
                .resumeOrPlayCurrent();
          }
          return true;
        case desktopLyricNextTrackMethod:
          await ref.read(playerControllerProvider.notifier).playNext();
          return true;
        case desktopLyricToggleLockedMethod:
          await ref
              .read(settingsControllerProvider.notifier)
              .toggleDesktopLyricsLocked();
          return true;
        case desktopLyricSetWindowPositionMethod:
          final arguments = call.arguments;
          if (arguments is! Map) {
            return false;
          }
          final left = (arguments['left'] as num?)?.toDouble();
          final top = (arguments['top'] as num?)?.toDouble();
          if (left == null || top == null) {
            return false;
          }
          await ref
              .read(settingsControllerProvider.notifier)
              .setDesktopLyricWindowPosition(left: left, top: top);
          return true;
        default:
          return null;
      }
    });
  }

  bool _isTextInputFocused() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) {
      return false;
    }
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  Future<void> _executeShortcut(ShortcutAction action) async {
    switch (action) {
      case ShortcutAction.playPause:
        final snapshot = ref.read(playerSnapshotsProvider).value;
        if (snapshot?.playing == true) {
          await ref.read(playerControllerProvider.notifier).pause();
          return;
        }
        await ref.read(playerControllerProvider.notifier).resumeOrPlayCurrent();
        return;
      case ShortcutAction.nextTrack:
        await ref.read(playerControllerProvider.notifier).playNext();
        return;
      case ShortcutAction.previousTrack:
        await ref.read(playerControllerProvider.notifier).playPrevious();
        return;
      case ShortcutAction.volumeUp:
        await _adjustVolume(5);
        return;
      case ShortcutAction.volumeDown:
        await _adjustVolume(-5);
        return;
      case ShortcutAction.desktopLyrics:
        await ref
            .read(settingsControllerProvider.notifier)
            .toggleDesktopLyricsEnabled();
        return;
      case ShortcutAction.toggleFavorite:
        final item = ref.read(currentPlaybackItemProvider);
        if (item != null) {
          await ref
              .read(playlistControllerProvider.notifier)
              .toggleFavorite(item);
        }
        return;
      case ShortcutAction.currentLyricLine:
        await _seekToLyricBoundary((document, position) {
          return document.startOfCurrentLine(position);
        });
        return;
      case ShortcutAction.previousLyricLine:
        await _seekToLyricBoundary((document, position) {
          return document.startOfPreviousLine(position);
        });
        return;
      case ShortcutAction.nextLyricLine:
        await _seekToLyricBoundary((document, position) {
          return document.startOfNextLine(position);
        });
        return;
    }
  }

  Future<void> _adjustVolume(double delta) async {
    final playerState = ref.read(playerControllerProvider).value;
    final snapshot = ref.read(playerSnapshotsProvider).value;
    final currentVolume = playerState?.volume ?? snapshot?.volume ?? 100;
    await ref
        .read(playerControllerProvider.notifier)
        .setVolume((currentVolume + delta).clamp(0, 100).toDouble());
  }

  Future<void> _seekToLyricBoundary(
    Duration? Function(LyricDocument document, Duration position) resolve,
  ) async {
    final document = ref.read(currentLyricsProvider).value;
    if (document == null || !document.isSynchronized) {
      return;
    }
    final target = resolve(document, ref.read(currentPlaybackPositionProvider));
    if (target == null) {
      return;
    }
    await ref.read(playerControllerProvider.notifier).seek(target);
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({required this.tab});

  final RobyneTab tab;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      RobyneTab.search => const SearchPage(),
      RobyneTab.discover => const DiscoverPage(),
      RobyneTab.library => const LibraryPage(),
      RobyneTab.nowPlaying => const NowPlayingPage(),
      RobyneTab.queue => const QueuePage(),
      RobyneTab.playlists => const PlaylistsPage(),
      RobyneTab.downloads => const DownloadsPage(),
      RobyneTab.plugins => const PluginPage(),
      RobyneTab.settings => const SettingsPage(),
    };
  }
}
