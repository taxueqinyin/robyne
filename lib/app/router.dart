import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../core/debug/ime_trace.dart';
import '../core/layout/window_size_class.dart';
import '../core/theme/infrastructure/token_resolver.dart';
import '../core/theme/application/theme_providers.dart';
import '../core/theme/domain/theme_materials.dart';
import '../core/theme/domain/theme_regions.dart';
import '../core/theme/domain/theme_navigation.dart';
import '../core/theme/domain/theme_icons.dart';
import '../core/theme/domain/theme_strings.dart';
import '../core/theme/domain/theme_tokens.dart';
import '../core/theme/presentation/theme_backdrop.dart' show ThemeBackdrop;
import '../core/theme/presentation/theme_asset_image.dart';
import '../core/theme/presentation/theme_ambient.dart';
import '../core/theme/presentation/theme_icon.dart';
import '../core/theme/presentation/theme_material.dart';
import '../features/player/presentation/artwork_view.dart';
import '../features/discover/presentation/discover_page.dart';
import '../features/discover/presentation/xuan_home_page.dart';
import '../features/lyrics/application/desktop_lyric_window_controller.dart';
import '../features/lyrics/application/lyrics_providers.dart';
import '../features/lyrics/domain/lyric_document.dart';
import '../features/player/presentation/player_bar.dart';
import '../features/player/domain/playback_item.dart';
import '../features/player/presentation/now_playing_page.dart';
import '../features/player/presentation/queue_page.dart';
import '../features/downloads/application/download_providers.dart';
import '../features/downloads/domain/download_task.dart';
import '../features/downloads/presentation/downloads_page.dart';
import '../features/library/application/library_providers.dart';
import '../features/player/application/player_providers.dart'
    show
        PlayerControllerState,
        playerControllerProvider,
        playerSnapshotsProvider,
        queuePanelVisibleProvider,
        nowPlayingImmersiveProvider,
        capsuleModeProvider;
import '../features/player/presentation/capsule_player_bar.dart';
import '../features/player/presentation/capsule_playlist_panel.dart';
import '../features/player/application/capsule_window.dart';
import 'main_window_controller.dart';
import '../features/playlists/presentation/playlists_page.dart';
import '../features/playlists/application/playlist_providers.dart';
import '../features/playlists/domain/music_playlist.dart';
import '../features/playlists/infrastructure/playlist_repository.dart';
import '../features/plugin/presentation/plugin_page.dart';
import '../features/library/presentation/library_page.dart';
import '../features/plugin/application/plugin_controller.dart';
import '../features/plugin/domain/plugin_definition.dart';
import '../features/search/presentation/search_page.dart';
import '../features/search/application/search_controller.dart' as search_state;
import '../features/settings/application/settings_providers.dart';
import '../features/settings/application/shortcut_runtime.dart';
import '../features/settings/domain/lyric_settings.dart';
import '../features/settings/domain/shortcut_action.dart';
import '../features/settings/domain/shortcut_settings.dart';
import '../features/settings/presentation/settings_page.dart';
import '../shared/widgets/window_control_button.dart';
import '../shared/widgets/search_field_with_history.dart';
import 'desktop_tray_controller.dart';
import 'navigation.dart';

export 'navigation.dart'
    show
        NavigationHistoryNotifier,
        NavigationHistoryState,
        NavigationSnapshot,
        RobyneTab,
        SelectedTabNotifier,
        navigationHistoryProvider,
        selectedTabProvider;

/// True when the running platform provides the desktop-only integrations
/// (`desktop_multi_window`, window_manager) used by the desktop lyric window.
bool get isDesktopPlatform {
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

class RobyneShell extends ConsumerStatefulWidget {
  const RobyneShell({super.key});

  @override
  ConsumerState<RobyneShell> createState() => _RobyneShellState();
}

class _RobyneShellState extends ConsumerState<RobyneShell> {
  final ShortcutTracker _shortcutTracker = ShortcutTracker();
  RobyneTab? _previousTab;
  final Set<RobyneTab> _mountedTabs = <RobyneTab>{};
  bool _restoringHistory = false;
  bool _wasCapsule = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalShortcut);
    // Desktop-only: `desktop_multi_window` has no Android/iOS implementation.
    if (isDesktopPlatform) {
      unawaited(_registerDesktopLyricControlHandler());
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalShortcut);
    // Leaving the app while collapsed must not persist the capsule's small
    // bounds as the shell's saved geometry, but the capsule's own spot is
    // worth keeping.
    if (_wasCapsule) {
      unawaited(rememberCapsulePosition());
    }
    if (isDesktopPlatform) {
      unawaited(desktopLyricControlChannel.setMethodCallHandler(null));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DesktopLyricPayload>(currentDesktopLyricPayloadProvider, (
      previous,
      next,
    ) {
      unawaited(ref.read(desktopLyricWindowControllerProvider).sync(next));
    });
    final sizeClass = WindowSizeClass.of(context);
    final mediaSize = MediaQuery.sizeOf(context);
    _watchNavigation(ref);
    // D6 is about the shell's shape, not about "large enough to be pretty".
    // A medium-width *desktop window* can afford a compact rail, but an
    // 800x360 landscape phone cannot: its height is already carrying the
    // player and bottom nav. Keeping those cases distinct is what prevents
    // the historical ADR-001 regression from coming back.
    final isDesktopShell =
        sizeClass.width == WindowWidthClass.expanded ||
        (sizeClass.width == WindowWidthClass.medium &&
            !sizeClass.isCompactHeight);
    final layout = ref.watch(activeThemePackageProvider).layout;

    // D6: the arrangement comes from the skin per form factor, D7: the
    // application resolves it against the concrete viewport.
    final arrangement = isDesktopShell
        ? layout.desktop.arrangement
        : layout.mobile.arrangement;
    final plan = RobyneShellPlan.resolve(
      arrangement: arrangement,
      width: mediaSize.width,
      height: mediaSize.height,
    );
    final settings = ref.watch(settingsControllerProvider).value;
    final sidebarWidth = settings?.sidebarWidth;
    // The design docks the queue on desktop (it is part of the flagship's
    // three-column composition) and keeps it behind the player-bar toggle on
    // a phone, where it would cover the content. An explicit user toggle wins
    // in either shape.
    final queueOverride = ref.watch(queuePanelVisibleProvider);
    final queueRequested = queueOverride ?? isDesktopShell;
    final immersive = ref.watch(nowPlayingImmersiveProvider);
    final capsule = ref.watch(capsuleModeProvider);
    final capsuleQueueOpen = ref.watch(capsuleQueueOpenProvider);
    // Window resizing is a side effect, so it hangs off provider changes
    // rather than off `build`: entering the capsule shrinks the OS window,
    // leaving restores it, and toggling the playlist grows it downward.
    ref.listen<bool>(capsuleModeProvider, (previous, next) {
      if (next) {
        unawaited(captureFullShellWindowSize());
        // Stop the geometry watcher from writing the capsule's small bounds
        // as the shell's normal geometry while the capsule is open.
        ref.read(mainWindowControllerProvider).suspend();
        // A drag ends without a Dart callback, so the capsule's spot is
        // polled while it is open. Closing the app while collapsed otherwise
        // lost the position entirely.
        startCapsulePositionSampling();
        unawaited(applyCapsuleWindowSize(playlistOpen: capsuleQueueOpen));
      } else {
        unawaited(restoreFullShellWindow());
        stopCapsulePositionSampling();
        ref.read(mainWindowControllerProvider).resume();
      }
    });
    // The playlist toggle changes the capsule's height, so the OS window must
    // follow the layout rather than clipping the panel or leaving dead space.
    ref.listen<bool>(capsuleQueueOpenProvider, (previous, next) {
      if (ref.read(capsuleModeProvider)) {
        unawaited(applyCapsuleWindowSize(playlistOpen: next));
      }
    });
    final history = ref.watch(navigationHistoryProvider);
    final showWindowControls =
        !kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST');

    // The capsule is a *replacement* layout, not an overlay: collapsing the
    // window must retire the rail, top bar, player bar and page tree rather
    // than painting a bar on top of a shell that keeps laying itself out
    // behind it. Returning here keeps the collapsed window cheap and makes
    // "close" a plain restore of what the shell would have built anyway.
    if (capsule) {
      _wasCapsule = true;
      return Scaffold(
        // No `ThemeBackdrop` and no scaffold colour: the capsule is an
        // irregular shape over the desktop, so painting the shell's own
        // background here is what produced the black rectangle around it.
        backgroundColor: Colors.transparent,
        body: SafeArea(
          // `SafeArea` adds its own insets on top of the padding below, so
          // the capsule's content needs the sum to fit the window it asked
          // for. Bottom insets are left out because the capsule is
          // bottom-anchored by design and the playlist grows into that space.
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CapsuleWindow.windowMarginHorizontal,
              vertical: CapsuleWindow.windowMarginVertical / 2,
            ),
            child: Column(
              children: <Widget>[
                // Top-aligned so the bar stays put and the playlist grows
                // downward out of it, rather than the bar being pushed up.
                const CapsulePlayerBar(),
                if (capsuleQueueOpen) ...<Widget>[
                  SizedBox(height: CapsuleWindow.panelGap),
                  // `Flexible` rather than a bare child: the OS resize is
                  // async, so for one or two frames the panel is laid out
                  // inside the *old* small window. An unconstrained 300dp
                  // child overflows those frames — which is exactly the
                  // flash of overflow the toggle used to show before the
                  // window caught up.
                  const Flexible(
                    child: CapsulePlaylistPanel(
                      key: Key('capsule-playlist-panel'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // The cover-driven wash sits *behind* the tab stack, so it tints the
    // content region without becoming one more thing pages must know about.
    // `ThemeAmbient` renders nothing when the skin switches it off.
    //
    // The content material wraps the wash so a skin can frost or tint the
    // whole content plane, not just the chrome around it.
    final contentTokens = RobyneTheme.of(context).tokens;
    Widget content = ThemeAmbient(
      artworkUrl: ref.watch(currentPlaybackItemProvider)?.artworkUrl,
      child: _buildTabStack(),
    );
    if (!contentTokens.materials.content.isTransparent) {
      content = MaterialSurface(
        material: contentTokens.materials.content,
        tokens: contentTokens,
        scaleToFill: true,
        child: content,
      );
    }
    final dockedQueue =
        queueRequested && !plan.queueOverlay && plan.queueSideExtent > 0;
    // The mockups compose the content column as `content | queue`, with the
    // player bar spanning both. Keeping the queue outside this column is how
    // the transport row lost the width it needs: a 1280dp window minus a
    // 232dp rail minus a 308dp queue leaves the bar 740dp, and it then has to
    // drop its desktop-only controls. The skin asked for a 0.24 queue *of the
    // viewport*; the plan already budgeted for it, so the bar below gets
    // exactly what the arrangement promised it.
    final workingRow = Row(
      children: <Widget>[
        if (dockedQueue && plan.queueSlot == RobyneSlot.left)
          _QueuePanel(width: plan.queueSideExtent),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              content,
              if (plan.queueOverlay && queueRequested)
                Align(
                  alignment: plan.queueOverlaySlot == RobyneSlot.left
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Material(
                    elevation: 8,
                    child: SizedBox(
                      width: plan.queueOverlayWidth,
                      child: QueuePage(),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (dockedQueue && plan.queueSlot != RobyneSlot.left)
          _QueuePanel(width: plan.queueSideExtent),
      ],
    );

    // The plan owns every dimension: the skin said "top bar at 6%", the plan
    // decided that is 54dp in this window, and the chrome takes exactly that.
    // Hardcoding a height here is how D4 gets silently undone.
    final contentColumn = Column(
      key: const Key('shell-content'),
      children: <Widget>[
        if (plan.topBarVisible)
          SizedBox(
            height: plan.topExtent,
            child: _TopBar(
              width: mediaSize.width,
              canGoBack: history.canGoBack,
              canGoForward: history.canGoForward,
              onBack: _goBack,
              onForward: _goForward,
              // The frameless window owns its title bar: on a real desktop
              // session the controls are ours. Tests pass `false` through a
              // widget-tree default so pumping the shell does not need a
              // window plugin.
              showWindowControls: showWindowControls && !immersive,
            ),
          ),
        Expanded(child: workingRow),
        SizedBox(
          height: plan.playerBarHeight,
          child: PlayerBar(
            compactHeight: plan.playerMini,
            onOpenNowPlaying: () {
              ref.read(nowPlayingImmersiveProvider.notifier).open();
            },
          ),
        ),
      ],
    );

    final Widget body;
    final navPlacement = plan.navSlot;
    switch (navPlacement) {
      case RobyneSlot.left:
        body = Row(
          children: <Widget>[
            _SideNav(
              key: const Key('shell-nav-left'),
              width: sidebarWidth ?? plan.leftExtent,
              iconOnly: plan.navIconOnly,
              edge: _SideNavEdge.right,
              onWidthChanged: (width) => unawaited(
                ref
                    .read(settingsControllerProvider.notifier)
                    .setSidebarWidth(width),
              ),
            ),
            Expanded(child: contentColumn),
          ],
        );
      case RobyneSlot.right:
        body = Row(
          children: <Widget>[
            Expanded(child: contentColumn),
            _SideNav(
              key: const Key('shell-nav-right'),
              width: sidebarWidth ?? plan.rightExtent,
              iconOnly: plan.navIconOnly,
              edge: _SideNavEdge.left,
              onWidthChanged: (width) => unawaited(
                ref
                    .read(settingsControllerProvider.notifier)
                    .setSidebarWidth(width),
              ),
            ),
          ],
        );
      case RobyneSlot.bottom:
        body = SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              Expanded(child: contentColumn),
              SizedBox(
                height: plan.navBarBottomHeight,
                child: _CompactTabBar(compactHeight: plan.navIconOnly),
              ),
            ],
          ),
        );
      default:
        // No nav region at all: an odd but survivable skin state. Content
        // stays reachable through shortcuts and the now-playing surface.
        body = contentColumn;
    }

    return Scaffold(
      body: ThemeBackdrop(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            body,
            if (immersive)
              Material(
                key: const Key('now-playing-immersive'),
                child: NowPlayingPage(
                  immersive: true,
                  showWindowControls: showWindowControls,
                  onClose: () =>
                      ref.read(nowPlayingImmersiveProvider.notifier).close(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabStack() {
    final selectedTab = ref.watch(selectedTabProvider);
    final motion = ref.watch(activeThemeMotionProvider);
    final previousTab = _previousTab;
    final forward = previousTab == null
        ? true
        : selectedTab.index >= previousTab.index;
    _previousTab = selectedTab;
    // The first page is the app's initial content, not a transition into a
    // different destination. Later first visits still need an entrance
    // animation even though their State is created only when selected.
    final animateSelection = _mountedTabs.isNotEmpty;
    _mountedTabs.add(selectedTab);
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          for (final tab in RobyneTab.values)
            if (_mountedTabs.contains(tab))
              Offstage(
                offstage: selectedTab != tab,
                child: TickerMode(
                  enabled: selectedTab == tab,
                  child: _TabTransition(
                    key: ValueKey<RobyneTab>(tab),
                    animate: animateSelection && selectedTab == tab,
                    fromRight: forward,
                    duration: motion.medium,
                    curve: motion.curve.toCurve,
                    child: _TabContent(tab: tab),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  void _watchNavigation(WidgetRef ref) {
    ref.listen<RobyneTab>(selectedTabProvider, (previous, next) {
      if (_restoringHistory || previous == null || previous == next) {
        return;
      }
      _previousTab = previous;
      ref
          .read(navigationHistoryProvider.notifier)
          .record(
            tab: next,
            playlistId: next == RobyneTab.playlists
                ? ref.read(selectedPlaylistIdProvider)
                : null,
          );
    });
    ref.listen<String?>(selectedPlaylistIdProvider, (previous, next) {
      if (_restoringHistory ||
          previous == next ||
          ref.read(selectedTabProvider) != RobyneTab.playlists) {
        return;
      }
      ref
          .read(navigationHistoryProvider.notifier)
          .record(tab: RobyneTab.playlists, playlistId: next);
    });
  }

  void _goBack() {
    final history = ref.read(navigationHistoryProvider);
    if (!history.canGoBack) {
      return;
    }
    ref.read(navigationHistoryProvider.notifier).back();
    _restoreSnapshot(ref.read(navigationHistoryProvider).current);
  }

  void _goForward() {
    final history = ref.read(navigationHistoryProvider);
    if (!history.canGoForward) {
      return;
    }
    ref.read(navigationHistoryProvider.notifier).forward();
    _restoreSnapshot(ref.read(navigationHistoryProvider).current);
  }

  void _restoreSnapshot(NavigationSnapshot snapshot) {
    _restoringHistory = true;
    try {
      if (snapshot.tab == RobyneTab.playlists) {
        final playlistId = snapshot.playlistId;
        final playlists = ref.read(selectedPlaylistIdProvider.notifier);
        if (playlistId == null) {
          playlists.showLiked();
        } else if (playlistId == overviewPlaylistId) {
          playlists.showOverview();
        } else {
          playlists.select(playlistId);
        }
      }
      ref.read(selectedTabProvider.notifier).select(snapshot.tab);
    } finally {
      _restoringHistory = false;
    }
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
      RobyneTab.discover => const _DiscoverSurface(),
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

/// Fades and slides one kept-alive tab when it becomes the active page.
///
/// The shell keeps every visited tab mounted, so this animation must live
/// inside the tab rather than around an `AnimatedSwitcher`: replacing the
/// child would discard scroll positions, search drafts and discovery state.
class _TabTransition extends StatefulWidget {
  const _TabTransition({
    super.key,
    required this.animate,
    required this.fromRight,
    required this.duration,
    required this.curve,
    required this.child,
  });

  /// True while this tab is the visible destination.
  final bool animate;

  /// Direction of the destination change.
  final bool fromRight;

  final Duration duration;
  final Curve curve;
  final Widget child;

  @override
  State<_TabTransition> createState() => _TabTransitionState();
}

class _TabTransitionState extends State<_TabTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.animate ? 0 : 1,
    );
    if (widget.animate) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _TabTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (!oldWidget.animate && widget.animate) {
      _controller.forward(from: 0);
    } else if (oldWidget.animate && !widget.animate) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = CurvedAnimation(parent: _controller, curve: widget.curve);
    return FadeTransition(
      opacity: progress,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(widget.fromRight ? 0.04 : -0.04, 0),
          end: Offset.zero,
        ).animate(progress),
        child: widget.child,
      ),
    );
  }
}

/// The discovery destination.
///
/// The flagship home is the first screen; the pre-existing plugin browser is
/// kept one level down so rankings and hot-playlist tags remain available
/// without competing with the design's hero and recommendation rails.
class _DiscoverSurface extends ConsumerWidget {
  const _DiscoverSurface();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final showBrowser = ref.watch(discoverBrowserProvider);
    if (showBrowser) {
      return Stack(
        children: <Widget>[
          const Positioned.fill(child: DiscoverPage()),
          Positioned(
            top: 12,
            left: 12,
            child: IconButton.filledTonal(
              tooltip: strings.resolve(ThemeStringKey.discoverBack),
              onPressed: () =>
                  ref.read(discoverBrowserProvider.notifier).close(),
              icon: const ThemeIconView(
                slot: ThemeIconKey.back,
                fallback: Icons.arrow_back,
              ),
            ),
          ),
        ],
      );
    }
    return Stack(
      children: <Widget>[
        const Positioned.fill(child: XuanHomePage()),
        // No floating button: the design has no such control, and the
        // extended FAB covered the recommendation shelf on a 1280 window.
        // The entry lives in the home header beside the search field, which
        // is where the mockups put page-level actions.
      ],
    );
  }
}

/// One destination in the [RobyneRegion.navBar] region.
///
/// Nav entries live here rather than in the widgets so every nav surface
/// (side rail, bottom strip, icon rail) renders from the same list.
///
/// The label is a [ThemeStringKey], not a string: the rail is chrome, and a
/// skin that calls the library `内容库` must be able to say so. Call sites pass
/// the entry to [_NavLabel], which reads the slot from the active skin.
class _NavEntry {
  const _NavEntry(
    this.tab,
    this.icon,
    this.selectedIcon,
    this.labelKey,
    this.iconKey,
  );

  final RobyneTab tab;
  final IconData icon;
  final IconData selectedIcon;
  final ThemeStringKey labelKey;

  /// Which skin icon slot replaces this entry's glyphs.
  final ThemeIconKey iconKey;
}

/// Maps a destination to its skin-facing navigation id.
///
/// Kept as a switch rather than a lookup table so adding a [RobyneTab] fails
/// the analyzer here instead of silently falling through to "never hidden".
ThemeNavEntry _navKeyFor(RobyneTab tab) {
  return switch (tab) {
    RobyneTab.search => ThemeNavEntry.search,
    RobyneTab.discover => ThemeNavEntry.discover,
    RobyneTab.library => ThemeNavEntry.library,
    RobyneTab.nowPlaying => ThemeNavEntry.nowPlaying,
    RobyneTab.playlists => ThemeNavEntry.playlists,
    RobyneTab.downloads => ThemeNavEntry.downloads,
    RobyneTab.plugins => ThemeNavEntry.plugins,
    RobyneTab.settings => ThemeNavEntry.settings,
    RobyneTab.queue => throw ArgumentError(
      'queue is a surface, not a navigation entry',
    ),
  };
}

/// One navigation glyph, resolved from the active skin's `icons`.
///
/// The counterpart of [_NavLabel]: a skin that redraws `library` changes it in
/// the rail, the icon rail and the phone tab strip at once. The built-in
/// [IconData] stays the fallback, so a skin can restyle a glyph but never
/// remove the control it labels.
class _NavIcon extends ConsumerWidget {
  const _NavIcon({
    required this.entry,
    required this.selected,
    required this.color,
    this.size,
  });

  final _NavEntry entry;
  final bool selected;
  final Color color;

  /// Explicit size, or null to use the skin's declared rail icon size.
  final double? size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A null [size] means "the skin decides": the declared rail icon size,
    // falling back to the design's 22dp. Surfaces that must be smaller than
    // the rail (the phone's compact bar) pass an explicit size instead.
    final resolved =
        size ?? ref.watch(activeThemeContentMetricsProvider).navIconSize;
    return ThemeIconView(
      slot: entry.iconKey,
      fallback: selected ? entry.selectedIcon : entry.icon,
      size: resolved,
      color: color,
      active: selected,
    );
  }
}

/// A navigation label, resolved from the active skin's `strings`.
///
/// Every nav surface renders its text through this widget, so a skin that
/// renames a destination renames it in the rail, the icon rail and the phone
/// tab strip at once — the three surfaces cannot drift apart.
class _NavLabel extends ConsumerWidget {
  const _NavLabel({required this.entry, required this.style, this.textAlign});

  final _NavEntry entry;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text(
      ref.watch(activeThemeStringsProvider).resolve(entry.labelKey),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: style,
    );
  }
}

/// Primary destinations in the sidebar, in display order.
///
/// The flagship design groups navigation by intent instead of listing every
/// route with equal weight: browse, collections, personal library, then
/// secondary tools at the foot of the rail. Search is a top-bar action, and
/// the queue/now-playing surfaces have their own persistent regions.
const List<_NavEntry> _navEntries = <_NavEntry>[
  _NavEntry(
    RobyneTab.search,
    Icons.search_outlined,
    Icons.search,
    ThemeStringKey.navSearch,
    ThemeIconKey.search,
  ),
  _NavEntry(
    RobyneTab.discover,
    Icons.explore_outlined,
    Icons.explore,
    ThemeStringKey.navDiscover,
    ThemeIconKey.discover,
  ),
  _NavEntry(
    RobyneTab.library,
    Icons.library_music_outlined,
    Icons.library_music,
    ThemeStringKey.navLibrary,
    ThemeIconKey.library,
  ),
  _NavEntry(
    RobyneTab.nowPlaying,
    Icons.album_outlined,
    Icons.album,
    ThemeStringKey.navNowPlaying,
    ThemeIconKey.nowPlaying,
  ),
  _NavEntry(
    RobyneTab.playlists,
    Icons.favorite_border,
    Icons.favorite,
    ThemeStringKey.navLiked,
    ThemeIconKey.playlists,
  ),
  _NavEntry(
    RobyneTab.downloads,
    Icons.download_outlined,
    Icons.download,
    ThemeStringKey.navDownloads,
    ThemeIconKey.downloads,
  ),
];

/// Destinations that belong in the sidebar's secondary section.
const List<_NavEntry> _secondaryNavEntries = <_NavEntry>[
  _NavEntry(
    RobyneTab.plugins,
    Icons.extension_outlined,
    Icons.extension,
    ThemeStringKey.navPlugins,
    ThemeIconKey.plugins,
  ),
  _NavEntry(
    RobyneTab.settings,
    Icons.settings_outlined,
    Icons.settings,
    ThemeStringKey.navSettings,
    ThemeIconKey.settings,
  ),
];

/// Every destination the shell can navigate to, primary and secondary.
///
/// This is the *catalog*; [_compactNavEntries] and [_navEntries] are the
/// per-surface selections from it. The phone overflow needs the full set so a
/// destination is never simply absent because no surface chose to list it.
const List<_NavEntry> _allNavEntries = <_NavEntry>[
  ..._navEntries,
  ..._secondaryNavEntries,
];

/// The small set of first-class destinations on a phone's bottom bar.
///
/// The mockup deliberately keeps the phone bar short and reachable; the rest
/// of the app remains available from those destinations and the settings
/// surface rather than by scrolling nine equal tabs.
const List<_NavEntry> _compactNavEntries = <_NavEntry>[
  _NavEntry(
    RobyneTab.discover,
    Icons.explore_outlined,
    Icons.explore,
    ThemeStringKey.tabDiscover,
    ThemeIconKey.discover,
  ),
  _NavEntry(
    RobyneTab.library,
    Icons.library_music_outlined,
    Icons.library_music,
    ThemeStringKey.tabLibrary,
    ThemeIconKey.library,
  ),
  // Material has no filled search glyph, so both states share one icon and
  // the tab shows selection with colour alone.
  _NavEntry(
    RobyneTab.search,
    Icons.search,
    Icons.search,
    ThemeStringKey.tabSearch,
    ThemeIconKey.search,
  ),
  _NavEntry(
    RobyneTab.playlists,
    Icons.favorite_border,
    Icons.favorite,
    ThemeStringKey.navLiked,
    ThemeIconKey.playlists,
  ),
];

/// Paints a skin-declared surface: the component colour/gradient when the skin
/// only speaks the old vocabulary, plus everything its material adds — blur,
/// blend layers, stroke, glow and shimmer.
///
/// The fallback colour is what a skin without a material gets, so this is the
/// one place shell chrome switches from "flat fill" to "painted material".
class _GradientSurface extends StatelessWidget {
  const _GradientSurface({
    required this.material,
    required this.gradient,
    required this.fallback,
    required this.tokens,
    required this.child,
  });

  final ThemeMaterial material;
  final ThemeGradient gradient;
  final Color fallback;
  final ThemeTokens tokens;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // `resolveSurfaceMaterial` folds in the pre-material `effects.blur` /
    // `effects.glassOpacity` tokens and the component gradient, so this one
    // call covers all three generations of skin declarations.
    final effectiveMaterial = resolveSurfaceMaterial(
      material: material,
      tokens: tokens,
      fallbackColor: gradient.isEmpty ? fallback : null,
      fallbackGradient: gradient,
      applyLegacyEffects: true,
    );
    return MaterialSurface(
      material: effectiveMaterial,
      tokens: tokens,
      scaleToFill: true,
      child: child,
    );
  }
}

/// The [RobyneRegion.topBar] region: global search plus a queue toggle.
///
/// Search is the app's primary action, so it lives in chrome rather than
/// inside a page; the keyword is shared with [SearchPage] through
/// `searchControllerProvider`.
class _TopBar extends ConsumerStatefulWidget {
  const _TopBar({
    required this.width,
    required this.showWindowControls,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
  });

  final double width;

  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;

  /// Window buttons belong to `window_manager`, which only the main window
  /// initialises. The old shell never had them, so they stay opt-in.
  final bool showWindowControls;

  @override
  ConsumerState<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<_TopBar> {
  late final TextEditingController _keyword;
  late final FocusNode _keywordFocus;

  @override
  void initState() {
    super.initState();
    _keyword = TextEditingController(
      text:
          ref.read(search_state.searchControllerProvider).value?.keyword ?? '',
    );
    _keywordFocus = FocusNode();
    attachImeTextControllerTrace(_keyword, 'topbar.keyword');
  }

  @override
  void dispose() {
    _keywordFocus.dispose();
    _keyword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final plugins =
        ref.watch(pluginControllerProvider).value ?? const <PluginDefinition>[];
    // Below a full desktop width the rail plus window controls leave the
    // search pill too little room; cap it so the row never overflows.
    final compactSearch = widget.width < 1000;
    return _GradientSurface(
      material: tokens.materials.topBar,
      gradient: tokens.components.navBar.gradient,
      fallback: colors.backgroundElevated,
      tokens: tokens,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.borderSubtle)),
        ),
        // The native title bar is hidden, so this bar has to carry the window
        // drag that the OS used to provide. The drag layer sits *behind* the
        // controls: `DragToMoveArea` only claims the pointer where nothing
        // above it handles the gesture, so the search field, the arrows and the
        // window buttons keep working.
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (widget.showWindowControls)
              const Positioned.fill(
                child: DragToMoveArea(child: SizedBox.expand()),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                widget.showWindowControls ? 136 : 16,
                0,
              ),
              child: Row(
                children: <Widget>[
                  // The design's top bar leads with a history pair. The shell
                  // records every destination change, including playlist views,
                  // so both arrows move through real state instead of being
                  // decoration.
                  _TopBarArrow(
                    key: const Key('topbar-back'),
                    slot: ThemeIconKey.back,
                    fallback: Icons.chevron_left,
                    colors: colors,
                    enabled: widget.canGoBack,
                    onPressed: widget.canGoBack ? widget.onBack : null,
                  ),
                  _TopBarArrow(
                    key: const Key('topbar-forward'),
                    slot: ThemeIconKey.skipNext,
                    fallback: Icons.chevron_right,
                    colors: colors,
                    enabled: widget.canGoForward,
                    onPressed: widget.canGoForward ? widget.onForward : null,
                  ),
                  const SizedBox(width: 4),
                  // The design's search field is a 430dp pill with a `Ctrl K`
                  // affordance on the right, not a field that grows without a
                  // bound. `Flexible` keeps that cap on wide windows while
                  // allowing the field to shrink beside the window controls on
                  // a narrow desktop rail.
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: compactSearch ? 280 : 360,
                      ),
                      // The remembered searches now live in a dropdown on the
                      // field itself: the suggestion has to appear while the
                      // user is typing, which a section further down the
                      // results page never managed to do.
                      child: SearchFieldWithHistory(
                        controller: _keyword,
                        focusNode: _keywordFocus,
                        onSubmit: (keyword) => _search(plugins),
                        // The design's field is a translucent pill on the bar,
                        // not an opaque card: it reads as chrome rather than as a
                        // field floating over the page.
                        fillColor: colors.textPrimary.withValues(alpha: 0.055),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        prefix: IconButton(
                          key: const Key('topbar-search-submit'),
                          tooltip: ref
                              .watch(activeThemeStringsProvider)
                              .resolve(ThemeStringKey.searchAction),
                          onPressed: () => _search(plugins),
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          icon: ThemeIconView(
                            slot: ThemeIconKey.search,
                            fallback: Icons.search,
                            size: 18,
                            color: colors.textMuted,
                          ),
                        ),
                        suffix: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _CtrlKHint(colors: colors, tokens: tokens),
                        ),
                        suffixConstraints: const BoxConstraints(
                          minHeight: 0,
                          minWidth: 0,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            if (widget.showWindowControls)
              const Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                child: Center(child: _WindowControls()),
              ),
          ],
        ),
      ),
    );
  }

  void _search(List<PluginDefinition> plugins) {
    ref.read(selectedTabProvider.notifier).select(RobyneTab.search);
    ref
        .read(search_state.searchControllerProvider.notifier)
        .updateKeyword(_keyword.text);
    unawaited(
      ref.read(search_state.searchControllerProvider.notifier).search(plugins),
    );
  }
}

/// The frameless window's own title-bar buttons.
///
/// Hiding the native title bar does not remove the window: these call the same
/// OS operations (minimise, maximise/restore, close) through `window_manager`,
/// so Snap layouts, the taskbar preview and Alt+F4 all keep working. The close
/// button paints its hover red, which is the one affordance users read as
/// "this leaves the app".
class _WindowControls extends ConsumerWidget {
  const _WindowControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        WindowControlButton(
          key: const Key('titlebar-capsule'),
          // A wide rectangle, so the capsule entry cannot be mistaken for
          // maximise: `crop_din` is square and read as "another maximise".
          icon: Icons.crop_landscape,
          tooltip: strings.resolve(ThemeStringKey.playerCapsuleEnter),
          onPressed: () {
            ref.read(capsuleModeProvider.notifier).enter();
            ref.read(capsuleQueueOpenProvider.notifier).close();
          },
        ),
        WindowControlButton(
          icon: Icons.horizontal_rule,
          tooltip: '最小化',
          onPressed: () => unawaited(windowManager.minimize()),
        ),
        WindowControlButton(
          icon: Icons.crop_square,
          tooltip: '最大化',
          onPressed: () => unawaited(_toggleMaximize()),
        ),
        WindowControlButton(
          icon: Icons.close,
          tooltip: '关闭',
          destructive: true,
          onPressed: () => unawaited(
            ref.read(desktopTrayControllerProvider).onTitleBarClose(),
          ),
        ),
      ],
    );
  }

  static Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
      return;
    }
    await windowManager.maximize();
  }
}

/// One of the top bar's chevron buttons. They read as navigation affordances
/// and stay dim while the shell has nothing to move between — a 30dp circle
/// is the design's footprint, and the glyph inherits the theme foreground.
class _TopBarArrow extends StatelessWidget {
  const _TopBarArrow({
    super.key,
    required this.slot,
    required this.fallback,
    required this.colors,
    required this.enabled,
    required this.onPressed,
  });

  final ThemeIconKey slot;
  final IconData fallback;
  final ThemeColors colors;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = enabled ? colors.textSecondary : colors.textDisabled;
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 17,
        visualDensity: VisualDensity.compact,
        splashRadius: 14,
        icon: ThemeIconView(
          slot: slot,
          fallback: fallback,
          size: 17,
          color: foreground,
        ),
        color: foreground,
        onPressed: enabled ? onPressed : null,
      ),
    );
  }
}

/// The `Ctrl K` chip the design draws at the search field's trailing edge.
///
/// Decorative, but part of the pill's silhouette: a field that can't hint its
/// shortcut reads as a plain box. The widget keeps its own padding so the
/// TextField's suffix slot does not stretch it.
class _CtrlKHint extends StatelessWidget {
  const _CtrlKHint({required this.colors, required this.tokens});

  final ThemeColors colors;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: colors.borderStrong),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        'Ctrl K',
        style: TextStyle(fontSize: 10.5, height: 1.2, color: colors.textMuted),
      ),
    );
  }
}

/// The [RobyneRegion.navBar] region on its side slot: a branded rail.
///
/// It is deliberately not [NavigationRail]: the rail owns its own width and
/// cannot be told to be 260dp wide or 64dp wide by a ratio. It collapses to
/// icons when the plan says so, which is the D7 step 2 degradation.
class _SideNav extends ConsumerStatefulWidget {
  const _SideNav({
    super.key,
    required this.width,
    required this.iconOnly,
    required this.edge,
    required this.onWidthChanged,
  });

  final double width;

  /// True when the plan has run out of room for labels.
  final bool iconOnly;

  /// Which edge touches the content column.
  final _SideNavEdge edge;

  /// Called while the user drags the rail's inner edge.
  final ValueChanged<double> onWidthChanged;

  static const double minWidth = 56;
  static const double maxWidth = 280;

  @override
  ConsumerState<_SideNav> createState() => _SideNavState();
}

enum _SideNavEdge { left, right }

class _SideNavState extends ConsumerState<_SideNav> {
  bool _resizeActive = false;
  late double _liveWidth;

  @override
  void initState() {
    super.initState();
    _liveWidth = widget.width;
  }

  @override
  void didUpdateWidget(covariant _SideNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_resizeActive && oldWidget.width != widget.width) {
      _liveWidth = widget.width;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final width = _liveWidth;
    final iconOnly = widget.iconOnly;
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final comp = tokens.components.navBar;
    final selected = ref.watch(selectedTabProvider);
    final navigation = ref.watch(activeThemeNavigationProvider);
    final strings = ref.watch(activeThemeStringsProvider);
    // Keep one rail rhythm instead of stacking labels under glyphs at an
    // in-between width. The rail either has room for a normal row or it is
    // deliberately icon-only.
    // The rail is allowed to become a true capsule when the user drags it
    // below the label threshold. Its floor keeps the 32dp targets from
    // crowding, while the ceiling leaves the content column usable.
    final labelBesideIcon = width >= 168;
    final showLabel = !iconOnly && labelBesideIcon;
    final compactRail = !showLabel;
    // The rail is the desktop surface, so it reads the desktop declarations.
    final shown = <_NavEntry>[
      for (final entry in _navEntries)
        if (!navigation.isHidden(
          _navKeyFor(entry.tab),
          RobyneFormFactor.desktop,
        ))
          entry,
    ];
    final visible = navigation.applyOrder(
      shown,
      RobyneFormFactor.desktop,
      (nav) => _navKeyFor(nav.tab),
    );

    // The design decorates three rail rows with a count: how many tracks are
    // in the local library, how many liked songs there are, and how many
    // active downloads. They are chrome (the data is already on screen in the
    // page), so the rail reads the same providers the pages do.
    String? countFor(_NavEntry entry) {
      if (!showLabel || !labelBesideIcon) {
        return null;
      }
      final themeKey = switch (entry.tab) {
        RobyneTab.library => ThemeStringKey.railLibraryCount,
        RobyneTab.playlists => ThemeStringKey.railLikedCount,
        RobyneTab.downloads => ThemeStringKey.railDownloadsCount,
        RobyneTab.plugins => ThemeStringKey.railPluginsCount,
        _ => null,
      };
      if (themeKey == null) {
        return null;
      }
      final count = switch (entry.tab) {
        RobyneTab.library => ref.watch(localMusicLibraryProvider).value?.length,
        RobyneTab.playlists =>
          ref
              .watch(playlistControllerProvider)
              .value
              ?.where((playlist) => playlist.isFavorites)
              .expand((playlist) => playlist.items)
              .length,
        RobyneTab.downloads =>
          ref
              .watch(downloadControllerProvider)
              .value
              ?.where((task) => task.status != DownloadStatus.completed)
              .length,
        RobyneTab.plugins => ref.watch(pluginControllerProvider).value?.length,
        _ => null,
      };
      if (count == null || count <= 0) {
        return null;
      }
      return strings.resolve(themeKey).replaceAll('{count}', '$count');
    }

    final effectiveWidth = _liveWidth.clamp(
      _SideNav.minWidth,
      _SideNav.maxWidth,
    );
    return SizedBox(
      width: effectiveWidth,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _GradientSurface(
            material: tokens.materials.navBar,
            gradient: comp.gradient,
            fallback: comp.background.a > 0
                ? comp.background
                : colors.backgroundElevated,
            tokens: tokens,
            child: Container(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: colors.borderSubtle)),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _SideNavBrand(compact: compactRail),
                    if (labelBesideIcon && comp.showProfile)
                      _SideNavProfile(tokens: tokens),
                    SizedBox(height: compactRail ? 4 : 10),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: <Widget>[
                            if (compactRail)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Divider(
                                  height: 1,
                                  color: colors.borderSubtle,
                                ),
                              ),
                            if (compactRail) const SizedBox(height: 8),
                            for (final entry in visible)
                              _NavItem(
                                entry: entry,
                                selected:
                                    entry.tab == selected &&
                                    (entry.tab != RobyneTab.playlists ||
                                        ref.watch(selectedPlaylistIdProvider) ==
                                            null),
                                showLabel: showLabel,
                                labelBesideIcon: labelBesideIcon,
                                tokens: tokens,
                                onTap: () {
                                  // The rail row means "liked songs", which is the
                                  // null selection state of the playlists page.
                                  // The overview lives below in the playlist
                                  // group, where the user's playlists are listed.
                                  if (entry.tab == RobyneTab.playlists) {
                                    ref
                                        .read(
                                          selectedPlaylistIdProvider.notifier,
                                        )
                                        .showLiked();
                                  }
                                  ref
                                      .read(selectedTabProvider.notifier)
                                      .select(entry.tab);
                                },
                                trailing: countFor(entry) == null
                                    ? null
                                    : _NavBadge(
                                        label: countFor(entry)!,
                                        colors: colors,
                                        accented: entry.tab == selected,
                                      ),
                              ),
                            if (labelBesideIcon) ...<Widget>[
                              const SizedBox(height: 14),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                child: Divider(
                                  height: 1,
                                  color: colors.borderSubtle,
                                ),
                              ),
                              const SizedBox(height: 18),
                              _SideNavSectionLabel(
                                label: strings.resolve(
                                  ThemeStringKey.navSectionPlaylists,
                                ),
                                tokens: tokens,
                                onOpen: () {
                                  ref
                                      .read(selectedPlaylistIdProvider.notifier)
                                      .showOverview();
                                  ref
                                      .read(selectedTabProvider.notifier)
                                      .select(RobyneTab.playlists);
                                },
                              ),
                              const SizedBox(height: 6),
                              _SideNavPlaylistGroup(
                                onOpenPlaylist: (id) {
                                  ref
                                      .read(selectedPlaylistIdProvider.notifier)
                                      .select(id);
                                  ref
                                      .read(selectedTabProvider.notifier)
                                      .select(RobyneTab.playlists);
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (compactRail) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Divider(height: 1, color: colors.borderSubtle),
                      ),
                      const SizedBox(height: 5),
                    ],
                    if (labelBesideIcon) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
                        child: Row(
                          children: <Widget>[
                            Text(
                              strings.resolve(ThemeStringKey.navSectionTools),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                                color: colors.textDisabled,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: colors.borderSubtle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    for (final entry in navigation.applyOrder(
                      _secondaryNavEntries,
                      RobyneFormFactor.desktop,
                      (nav) => _navKeyFor(nav.tab),
                    ))
                      _NavItem(
                        entry: entry,
                        selected:
                            entry.tab == selected &&
                            (entry.tab != RobyneTab.playlists ||
                                ref.watch(selectedPlaylistIdProvider) == null),
                        showLabel: showLabel,
                        labelBesideIcon: labelBesideIcon,
                        tokens: tokens,
                        onTap: () => ref
                            .read(selectedTabProvider.notifier)
                            .select(entry.tab),
                      ),
                    SizedBox(height: compactRail ? 3 : 8),
                    if (labelBesideIcon)
                      _SideNavFooter(
                        label: strings.resolve(ThemeStringKey.navFooter),
                        version: strings.resolve(
                          ThemeStringKey.navFooterVersion,
                        ),
                        tokens: tokens,
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: widget.edge == _SideNavEdge.left ? 0 : null,
            right: widget.edge == _SideNavEdge.right ? 0 : null,
            width: 8,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                key: const Key('sidebar-resize-handle'),
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) {
                  setState(() => _resizeActive = true);
                },
                onHorizontalDragUpdate: (details) {
                  if (!mounted) {
                    return;
                  }
                  final delta = widget.edge == _SideNavEdge.right
                      ? details.delta.dx
                      : -details.delta.dx;
                  final next = (_liveWidth + delta).clamp(
                    _SideNav.minWidth,
                    _SideNav.maxWidth,
                  );
                  setState(() => _liveWidth = next.toDouble());
                },
                onHorizontalDragEnd: (_) {
                  if (mounted) {
                    setState(() => _resizeActive = false);
                  }
                  widget.onWidthChanged(_liveWidth);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  color: _resizeActive
                      ? colors.brandBase.withValues(alpha: 0.65)
                      : Colors.transparent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Brand lockup at the top of the rail.
class _SideNavFooter extends ConsumerWidget {
  const _SideNavFooter({
    required this.label,
    required this.version,
    required this.tokens,
  });

  final String label;
  final String version;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = tokens.color;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 2),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      child: Row(
        children: <Widget>[
          ThemeIconView(
            slot: ThemeIconKey.nowPlaying,
            fallback: Icons.album_outlined,
            size: 15,
            color: colors.brandBase,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
            ),
          ),
          Text(
            version,
            style: TextStyle(fontSize: 11, color: colors.textDisabled),
          ),
        ],
      ),
    );
  }
}

/// Brand lockup at the top of the rail.
class _SideNavBrand extends ConsumerWidget {
  const _SideNavBrand({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final assets = ref.watch(activeThemePackageProvider).assets;
    final logoSize = ref.watch(activeThemeContentMetricsProvider).logoSize;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 0 : 18,
        compact ? 12 : 18,
        compact ? 0 : 16,
        compact ? 8 : 14,
      ),
      child: Row(
        mainAxisAlignment: compact
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radius.sm),
            child: SizedBox(
              width: logoSize,
              height: logoSize,
              child: ThemeAssetImage(
                asset: assets.logo,
                fallback: Container(
                  color: colors.brandBase,
                  child: Icon(
                    Icons.graphic_eq,
                    size: 16,
                    color: colors.onBrand,
                  ),
                ),
              ),
            ),
          ),
          if (!compact) ...<Widget>[
            const SizedBox(width: 10),
            Text(
              ref
                  .watch(activeThemeStringsProvider)
                  .resolve(ThemeStringKey.railBrand),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// User identity block from the mockup: avatar, name, and a level badge.
///
/// The profile is a normal skin surface; a future account feature can replace
/// the static values without changing the shell contract.
class _SideNavProfile extends ConsumerWidget {
  const _SideNavProfile({required this.tokens});

  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = tokens.color;
    final assets = ref.watch(activeThemePackageProvider).assets;
    final strings = ref.watch(activeThemeStringsProvider);
    final avatarSize = ref.watch(activeThemeContentMetricsProvider).avatarSize;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Row(
        children: <Widget>[
          ClipOval(
            child: SizedBox(
              width: avatarSize,
              height: avatarSize,
              child: ThemeAssetImage(
                asset: assets.avatar,
                fallback: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[colors.brandBase, colors.accentBase],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: 20,
                    color: colors.onBrand,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  // A real account feature will own this; until then the skin
                  // supplies the placeholder the design was drawn with, which
                  // keeps the neutral default usable for every other skin.
                  strings.resolve(ThemeStringKey.railProfileName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  strings.resolve(ThemeStringKey.railProfileSubtitle),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNavSectionLabel extends StatelessWidget {
  const _SideNavSectionLabel({
    required this.label,
    required this.tokens,
    required this.onOpen,
  });

  final String label;
  final ThemeTokens tokens;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tokens.color.textMuted,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: tokens.color.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A pill count at the end of a rail row (`1248`, `86`, the download and
/// plugin badges). The design renders these as quiet chips, not alerts: the
/// colour stays neutral unless the row is selected, so the count never
/// competes with the row's own state.
class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.label, required this.colors, this.accented});

  final String label;
  final ThemeColors colors;
  final bool? accented;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final selected = accented ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: selected
            ? colors.brandBase.withValues(alpha: 0.20)
            : colors.surfaceBase.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(tokens.radius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          color: selected ? colors.brandHover : colors.textMuted,
        ),
      ),
    );
  }
}

/// The user's playlists, as colour-coded rows in the rail.
///
/// Bound to the same repository that drives `PlaylistsPage`, so creating or
/// deleting a playlist is reflected here without a second source of truth.
/// Rows carry the design's colour marker, derived from the playlist id so a
/// given playlist keeps its colour across restarts.
class _SideNavPlaylistGroup extends ConsumerWidget {
  const _SideNavPlaylistGroup({required this.onOpenPlaylist});

  final ValueChanged<String> onOpenPlaylist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    // The favourites playlist has its own entry in the nav, so the rail list
    // shows the user's own playlists only.
    final playlists =
        ref
            .watch(playlistControllerProvider)
            .value
            ?.where((playlist) => !playlist.isFavorites)
            .toList(growable: false) ??
        const <MusicPlaylist>[];
    final selectedPlaylistId = ref.watch(selectedPlaylistIdProvider);
    if (playlists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Text(
          ref
              .watch(activeThemeStringsProvider)
              .resolve(ThemeStringKey.navPlaylistsEmpty),
          style: TextStyle(fontSize: 11, color: tokens.color.textMuted),
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (final playlist in playlists)
          Builder(
            builder: (context) {
              final selected = playlist.id == selectedPlaylistId;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                child: Material(
                  color: selected
                      ? tokens.components.navBar.selectedIndicatorFill
                      : Colors.transparent,
                  borderRadius: BorderRadius.all(
                    Radius.circular(tokens.radius.md),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.all(
                      Radius.circular(tokens.radius.md),
                    ),
                    hoverColor: selected
                        ? Colors.transparent
                        : tokens.color.surfaceHover.withValues(alpha: 0.45),
                    focusColor: selected
                        ? Colors.transparent
                        : tokens.color.surfaceHover.withValues(alpha: 0.45),
                    splashColor: Colors.transparent,
                    highlightColor: selected
                        ? Colors.transparent
                        : tokens.color.surfaceHover.withValues(alpha: 0.30),
                    onTap: () => onOpenPlaylist(playlist.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _playlistAccent(playlist.id),
                              borderRadius: BorderRadius.circular(
                                tokens.radius.full,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              playlist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: selected
                                    ? tokens.components.navBar.selectedItem
                                    : tokens.color.textSecondary,
                              ),
                            ),
                          ),
                          if (selected)
                            Container(
                              width: 2,
                              height: 16,
                              decoration: BoxDecoration(
                                color:
                                    tokens.components.navBar.selectedIndicator,
                                borderRadius: BorderRadius.circular(
                                  tokens.radius.full,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  /// A stable colour per playlist id.
  ///
  /// Hashing rather than randomising means the rail does not reshuffle its
  /// colours every launch, and no colour needs to be persisted.
  static Color _playlistAccent(String id) {
    const palette = <Color>[
      Color(0xFF63D8C3),
      Color(0xFFE7B35A),
      Color(0xFFF07178),
      Color(0xFF9CBF76),
      Color(0xFF6FA8FF),
      Color(0xFFB78CFF),
    ];
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return palette[hash % palette.length];
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.entry,
    required this.selected,
    required this.showLabel,
    required this.labelBesideIcon,
    required this.tokens,
    required this.onTap,
    this.trailing,
  });

  final _NavEntry entry;
  final bool selected;
  final bool showLabel;
  final bool labelBesideIcon;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  /// Optional trailing count, e.g. the design's `1248` on 内容库.
  ///
  /// Skin-declared strings own the format so a skin can drop it entirely.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = tokens.color;
    final foreground = selected
        ? tokens.components.navBar.selectedItem
        : colors.textSecondary;
    final comp = tokens.components.navBar;
    final rowWash = selected
        ? comp.selectedIndicatorFill
        : const Color(0x00000000);
    final indicator = selected
        ? comp.selectedIndicator
        : const Color(0x00000000);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: rowWash,
        borderRadius: BorderRadius.all(Radius.circular(tokens.radius.md)),
        child: Container(
          decoration: selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.all(
                    Radius.circular(tokens.radius.md),
                  ),
                  border: Border(right: BorderSide(color: indicator, width: 2)),
                )
              : null,
          child: InkWell(
            borderRadius: BorderRadius.all(Radius.circular(tokens.radius.md)),
            onTap: onTap,
            // A selected destination owns its visual state. The default
            // Material hover overlay used to sit on top of the selected fill,
            // so moving the pointer away appeared to "unselect" the row.
            hoverColor: selected
                ? Colors.transparent
                : colors.surfaceHover.withValues(alpha: 0.55),
            focusColor: selected
                ? Colors.transparent
                : colors.surfaceHover.withValues(alpha: 0.55),
            splashColor: Colors.transparent,
            highlightColor: selected
                ? Colors.transparent
                : colors.surfaceHover.withValues(alpha: 0.40),
            child: labelBesideIcon
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: <Widget>[
                        _NavIcon(
                          entry: entry,
                          selected: selected,
                          size: 22,
                          color: foreground,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _NavLabel(
                            entry: entry,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        ?trailing,
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _NavIcon(
                          entry: entry,
                          selected: selected,
                          size: 22,
                          color: foreground,
                        ),
                        if (showLabel) ...<Widget>[
                          const SizedBox(height: 2),
                          _NavLabel(
                            entry: entry,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Compact (phone) navigation: a scrollable bottom tab bar.
///
/// Nine tabs do not fit on a phone screen, so the bar scrolls horizontally.
/// The phone overflow entry: opens a sheet listing every destination the tab
/// bar does not show.
///
/// A phone bar fits four or five entries, so the rest need *somewhere* to go.
/// This is the second-level entry point the skin asks for via
/// `ThemeOverflowSlot.moreTab`, and it is what keeps plugin import reachable on
/// a phone instead of merely present in the tab list.
class _MoreTab extends ConsumerWidget {
  const _MoreTab({
    super.key,
    required this.entries,
    required this.compactHeight,
    required this.iconSize,
  });

  final List<_NavEntry> entries;
  final bool compactHeight;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);
    return InkWell(
      onTap: () => _openSheet(context, ref),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          ThemeIconView(
            slot: ThemeIconKey.more,
            fallback: Icons.more_horiz,
            size: iconSize,
            color: colors.textSecondary,
          ),
          if (!compactHeight) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              strings.resolve(ThemeStringKey.navMore),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      // The sheet is content-sized by default, which on a landscape phone is
      // more than the viewport can hold. Capping it keeps the header, handle
      // and at least one action visible without changing the portrait look.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Consumer(
            builder: (sheetContext, sheetRef, _) {
              final sheetTokens = RobyneTheme.of(sheetContext).tokens;
              final sheetColors = sheetTokens.color;
              final sheetStrings = sheetRef.watch(activeThemeStringsProvider);
              final selected = sheetRef.watch(selectedTabProvider);
              // A short viewport (landscape phone) cannot carry the full
              // sheet, so the column scrolls instead of overflowing. The
              // portrait layout is unchanged: everything still fits at 400x800.
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          sheetStrings.resolve(ThemeStringKey.navMore),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: sheetColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    for (final entry in entries)
                      ListTile(
                        leading: _NavIcon(
                          entry: entry,
                          selected: entry.tab == selected,
                          size: 24,
                          color: entry.tab == selected
                              ? sheetColors.brandBase
                              : sheetColors.textSecondary,
                        ),
                        title: Text(
                          sheetStrings.resolve(entry.labelKey),
                          style: TextStyle(
                            color: entry.tab == selected
                                ? sheetColors.brandBase
                                : sheetColors.textPrimary,
                            fontWeight: entry.tab == selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        selected: entry.tab == selected,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          sheetRef
                              .read(selectedTabProvider.notifier)
                              .select(entry.tab);
                        },
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _CompactTabBar extends ConsumerWidget {
  const _CompactTabBar({required this.compactHeight});

  /// True when the window is short (landscape phone).
  ///
  /// The bar drops its text labels and shrinks so the content column keeps a
  /// usable share of a ~360dp tall window.
  final bool compactHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final comp = tokens.components.navBar;
    final selected = ref.watch(selectedTabProvider);
    final navigation = ref.watch(activeThemeNavigationProvider);
    final visible = <_NavEntry>[
      for (final entry in _compactNavEntries)
        if (!navigation.isHidden(
          _navKeyFor(entry.tab),
          RobyneFormFactor.mobile,
        ))
          entry,
    ];
    final ordered = navigation.applyOrder(
      visible,
      RobyneFormFactor.mobile,
      (nav) => _navKeyFor(nav.tab),
    );
    final iconSize = compactHeight ? 20.0 : 22.0;
    final overflow = navigation.overflowFor(RobyneFormFactor.mobile);
    // Every destination the phone bar does not show. `settings` is always
    // there: it is the only route back to the appearance panel.
    final rest = navigation.applyOrder(
      <_NavEntry>[
        for (final entry in _allNavEntries)
          if (!ordered.any((nav) => nav.tab == entry.tab) ||
              entry.tab == RobyneTab.settings)
            entry,
      ],
      RobyneFormFactor.mobile,
      (nav) => _navKeyFor(nav.tab),
    );
    final showMore =
        overflow == ThemeOverflowSlot.moreTab &&
        rest.any((entry) => entry.tab != RobyneTab.settings);

    return SafeArea(
      top: false,
      child: SizedBox(
        key: const Key('shell-nav-bottom'),
        child: _GradientSurface(
          material: tokens.materials.navBar,
          gradient: comp.gradient,
          fallback: comp.background.a > 0
              ? comp.background
              : colors.backgroundElevated,
          tokens: tokens,
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.borderSubtle)),
            ),
            child: Row(
              children: <Widget>[
                for (final entry in ordered)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final isSelected = entry.tab == selected;
                        final foreground = isSelected
                            ? comp.selectedItem
                            : colors.textSecondary;
                        return InkWell(
                          onTap: () {
                            if (entry.tab == RobyneTab.playlists) {
                              ref
                                  .read(selectedPlaylistIdProvider.notifier)
                                  .showLiked();
                            }
                            ref
                                .read(selectedTabProvider.notifier)
                                .select(entry.tab);
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              _NavIcon(
                                entry: entry,
                                selected: isSelected,
                                size: iconSize,
                                color: foreground,
                              ),
                              if (!compactHeight) ...<Widget>[
                                const SizedBox(height: 2),
                                _NavLabel(
                                  entry: entry,
                                  style: TextStyle(
                                    color: foreground,
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                if (showMore)
                  Expanded(
                    child: _MoreTab(
                      key: const Key('shell-nav-more'),
                      entries: rest,
                      compactHeight: compactHeight,
                      iconSize: iconSize,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The [RobyneRegion.queue] region, docked beside the content.
///
/// This is the flagship "当前播放" panel from the design: a compact
/// now-playing header, a queue/liked split, and the real playback queue. It
/// is intentionally not [QueuePage]; the full queue/history surface remains
/// reachable from navigation, while this panel stays glanceable.
class _QueuePanel extends ConsumerStatefulWidget {
  const _QueuePanel({required this.width});

  final double width;

  @override
  ConsumerState<_QueuePanel> createState() => _QueuePanelState();
}

class _QueuePanelState extends ConsumerState<_QueuePanel> {
  bool _showLiked = false;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);
    final state =
        ref.watch(playerControllerProvider).value ??
        const PlayerControllerState();
    final current = state.currentItem;
    final items = _showLiked
        ? ref
                  .watch(playlistControllerProvider)
                  .value
                  ?.where(
                    (playlist) => playlist.id == PlaylistRepository.favoritesId,
                  )
                  .expand((playlist) => playlist.items)
                  .toList(growable: false) ??
              const <PlaybackItem>[]
        : state.queue;

    return SizedBox(
      width: widget.width,
      child: MaterialSurface(
        material: resolveSurfaceMaterial(
          material: tokens.materials.queue,
          tokens: tokens,
          fallbackColor: colors.backgroundElevated,
        ),
        tokens: tokens,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: colors.borderSubtle)),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 10, 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            strings.resolve(ThemeStringKey.queueTitle),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            strings
                                .resolve(ThemeStringKey.queueCount)
                                .replaceAll('{count}', '${state.queue.length}'),
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('player-queue-close'),
                      tooltip: strings.resolve(ThemeStringKey.queueCollapse),
                      icon: const Icon(Icons.close, size: 18),
                      color: colors.textMuted,
                      onPressed: () => ref
                          .read(queuePanelVisibleProvider.notifier)
                          .setVisible(false),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: <Widget>[
                    _QueueTab(
                      label: strings.resolve(ThemeStringKey.queueTabQueue),
                      selected: !_showLiked,
                      onTap: () => setState(() => _showLiked = false),
                    ),
                    const SizedBox(width: 6),
                    _QueueTab(
                      label: strings.resolve(ThemeStringKey.queueTabLiked),
                      selected: _showLiked,
                      onTap: () => setState(() => _showLiked = true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          _showLiked
                              ? strings.resolve(ThemeStringKey.queueLikedEmpty)
                              : strings.resolve(ThemeStringKey.queueEmpty),
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final active = item.id == current?.id;
                          return _QueueRow(
                            item: item,
                            active: active,
                            onTap: () => ref
                                .read(playerControllerProvider.notifier)
                                .playItem(item),
                          );
                        },
                      ),
              ),
              Divider(height: 1, color: colors.borderSubtle),
              InkWell(
                onTap: state.queue.isEmpty
                    ? null
                    : () => ref
                          .read(playerControllerProvider.notifier)
                          .clearQueue(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.delete_sweep_outlined,
                        size: 16,
                        color: colors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        strings.resolve(ThemeStringKey.queueClear),
                        style: TextStyle(fontSize: 12, color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueTab extends StatelessWidget {
  const _QueueTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? colors.brandBase.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(tokens.radius.sm),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? colors.brandBase : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final PlaybackItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final accent = _queueAccent(item.id);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? colors.surfaceSelected.withValues(alpha: 0.55)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(tokens.radius.sm),
        ),
        child: Row(
          children: <Widget>[
            // Real cover first, the id-derived gradient only as a bed: the
            // docked panel used to paint the gradient unconditionally, which
            // is why the queue showed coloured squares while the same track
            // had its artwork everywhere else. `ArtworkView` shares the one
            // artwork cache, so a cover the detail panel already fetched
            // costs nothing here.
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    accent,
                    Color.alphaBlend(
                      colors.backgroundBase.withValues(alpha: 0.55),
                      accent,
                    ),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(tokens.radius.sm),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radius.sm),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (item.artworkUrl != null)
                      ArtworkView(
                        artworkUrl: item.artworkUrl,
                        fit: BoxFit.cover,
                        expand: true,
                      ),
                    if (active)
                      Center(
                        child: Icon(
                          Icons.equalizer,
                          size: 16,
                          color: colors.textPrimary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? colors.brandBase : colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.artist ?? item.platform ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: colors.textMuted),
                  ),
                ],
              ),
            ),
            if (item.duration != null)
              Text(
                _formatQueueDuration(item.duration!),
                style: TextStyle(fontSize: 10, color: colors.textMuted),
              ),
          ],
        ),
      ),
    );
  }

  static Color _queueAccent(String id) {
    const palette = <Color>[
      Color(0xFF63D8C3),
      Color(0xFF6FA8FF),
      Color(0xFFB78CFF),
      Color(0xFFE7B35A),
      Color(0xFFF07178),
      Color(0xFF9CBF76),
    ];
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return palette[hash % palette.length];
  }

  static String _formatQueueDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
