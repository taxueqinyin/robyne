import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/debug/ime_trace.dart';
import '../features/discover/presentation/discover_page.dart';
import '../features/player/presentation/player_bar.dart';
import '../features/player/presentation/now_playing_page.dart';
import '../features/player/presentation/queue_page.dart';
import '../features/downloads/presentation/downloads_page.dart';
import '../features/playlists/presentation/playlists_page.dart';
import '../features/plugin/presentation/plugin_page.dart';
import '../features/library/presentation/library_page.dart';
import '../features/search/presentation/search_page.dart';
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

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(selectedTabProvider);
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
