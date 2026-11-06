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
  const NavigationSnapshot({
    required this.tab,
    this.playlistId,
    this.discoverCollectionKey,
  });

  final RobyneTab tab;
  final String? playlistId;

  /// The discover drill-down, as `OnlineCollectionItem.uniqueKey`.
  ///
  /// Null means the discover page is showing its catalogue. The key is opaque
  /// here for the same reason the playlist id is: the page owns what it means,
  /// the shell only needs something it can put back.
  final String? discoverCollectionKey;

  @override
  bool operator ==(Object other) {
    return other is NavigationSnapshot &&
        other.tab == tab &&
        other.playlistId == playlistId &&
        other.discoverCollectionKey == discoverCollectionKey;
  }

  @override
  int get hashCode => Object.hash(tab, playlistId, discoverCollectionKey);
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

  /// Rewrites the entry the shell is standing on.
  ///
  /// Closing a drill-down is not a new destination — pushing a second
  /// "discover, no collection" entry would leave the old one behind, and the
  /// back arrow would happily re-open the page the user just left.
  NavigationHistoryState replaceCurrent(NavigationSnapshot snapshot) {
    if (snapshot == current) {
      return this;
    }
    final next = entries.toList(growable: false)..[index] = snapshot;
    return NavigationHistoryState(
      entries: List<NavigationSnapshot>.unmodifiable(next),
      index: index,
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

  void record({
    required RobyneTab tab,
    String? playlistId,
    String? discoverCollectionKey,
  }) {
    state = state.push(
      NavigationSnapshot(
        tab: tab,
        playlistId: playlistId,
        discoverCollectionKey: discoverCollectionKey,
      ),
    );
  }

  /// Rewrites the current entry instead of appending a new one.
  void replaceCurrent({
    required RobyneTab tab,
    String? playlistId,
    String? discoverCollectionKey,
  }) {
    state = state.replaceCurrent(
      NavigationSnapshot(
        tab: tab,
        playlistId: playlistId,
        discoverCollectionKey: discoverCollectionKey,
      ),
    );
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
