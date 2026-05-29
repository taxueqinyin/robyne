import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/player/presentation/player_bar.dart';
import '../features/player/presentation/queue_page.dart';
import '../features/plugin/presentation/plugin_page.dart';
import '../features/library/presentation/library_page.dart';
import '../features/search/presentation/search_page.dart';

enum RobyneTab { search, library, queue, plugins }

final selectedTabProvider = NotifierProvider<SelectedTabNotifier, RobyneTab>(
  SelectedTabNotifier.new,
);

class SelectedTabNotifier extends Notifier<RobyneTab> {
  @override
  RobyneTab build() => RobyneTab.search;

  void select(RobyneTab tab) {
    state = tab;
  }
}

class RobyneShell extends ConsumerWidget {
  const RobyneShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(selectedTabProvider);

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
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music),
                label: Text('Library'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.queue_music_outlined),
                selectedIcon: Icon(Icons.queue_music),
                label: Text('Queue'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.extension_outlined),
                selectedIcon: Icon(Icons.extension),
                label: Text('Plugins'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: switch (selectedTab) {
                    RobyneTab.search => const SearchPage(),
                    RobyneTab.library => const LibraryPage(),
                    RobyneTab.queue => const QueuePage(),
                    RobyneTab.plugins => const PluginPage(),
                  },
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
