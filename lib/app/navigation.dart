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
