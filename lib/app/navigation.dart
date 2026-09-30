import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/debug/ime_trace.dart';

/// The shell's destinations.
///
/// This lives apart from the shell widget so feature pages can navigate
/// without importing the shell that renders them — a page asking to "open
/// playlists" should not drag the whole router into its dependency graph.
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

/// Whether the Discover destination is showing the plugin browser.
///
/// This is shell state rather than page-local state because two surfaces drive
/// it: the home header offers the way in, and the browser's own back button
/// closes it. Keeping it in a provider is also what lets the flagship home
/// page stay a `StatelessWidget`-style composition driven by skin data.
final discoverBrowserProvider = NotifierProvider<DiscoverBrowserNotifier, bool>(
  DiscoverBrowserNotifier.new,
);

class DiscoverBrowserNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void open() => state = true;

  void close() => state = false;
}

class SelectedTabNotifier extends Notifier<RobyneTab> {
  @override
  // The flagship lands on Discover, matching the design's first screen.
  // Search is a top-bar action rather than the initial destination.
  RobyneTab build() => RobyneTab.discover;

  void select(RobyneTab tab) {
    imeTrace('tab-select from=$state to=$tab');
    state = tab;
  }
}

/// The shell's browser-style history.
///
/// This deliberately lives beside the tab notifier instead of replacing it:
/// the notifier stays the one source for the selected destination, while this
/// small stack records enough state to drive the top-bar arrows. The playlist
/// id is captured as an opaque part of a history entry; the playlist page
/// remains the owner of what that id means.
class NavigationSnapshot {
  const NavigationSnapshot({required this.tab, this.playlistId});

  final RobyneTab tab;
  final String? playlistId;

  @override
  bool operator ==(Object other) {
    return other is NavigationSnapshot &&
        other.tab == tab &&
        other.playlistId == playlistId;
  }

  @override
  int get hashCode => Object.hash(tab, playlistId);
}

class NavigationHistoryState {
  const NavigationHistoryState({
    this.entries = const <NavigationSnapshot>[
      NavigationSnapshot(tab: RobyneTab.discover),
    ],
    this.index = 0,
  });

  static const int capacity = 50;

  final List<NavigationSnapshot> entries;
  final int index;

  NavigationSnapshot get current => entries[index];
  bool get canGoBack => index > 0;
  bool get canGoForward => index + 1 < entries.length;

  NavigationHistoryState push(NavigationSnapshot snapshot) {
    if (snapshot == current) {
      return this;
    }
    final next = entries.take(index + 1).toList(growable: true)..add(snapshot);
    final trimmed = next.length > capacity
        ? next.sublist(next.length - capacity)
        : next;
    return NavigationHistoryState(
      entries: List<NavigationSnapshot>.unmodifiable(trimmed),
      index: trimmed.length - 1,
    );
  }

  NavigationHistoryState back() {
    return canGoBack
        ? NavigationHistoryState(entries: entries, index: index - 1)
        : this;
  }

  NavigationHistoryState forward() {
    return canGoForward
        ? NavigationHistoryState(entries: entries, index: index + 1)
        : this;
  }
}

final navigationHistoryProvider =
    NotifierProvider<NavigationHistoryNotifier, NavigationHistoryState>(
      NavigationHistoryNotifier.new,
    );

class NavigationHistoryNotifier extends Notifier<NavigationHistoryState> {
  @override
  NavigationHistoryState build() => const NavigationHistoryState();

  void record({required RobyneTab tab, String? playlistId}) {
    state = state.push(NavigationSnapshot(tab: tab, playlistId: playlistId));
  }

  void back() {
    if (!state.canGoBack) {
      return;
    }
    state = state.back();
  }

  void forward() {
    if (!state.canGoForward) {
      return;
    }
    state = state.forward();
  }
}
