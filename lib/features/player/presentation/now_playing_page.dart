import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui show ImageFilter;
import 'dart:ui' show ImageFilter;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart'
    show GestureBinding, PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../app/desktop_tray_controller.dart';
import '../../../core/debug/ime_trace.dart';
import '../../../core/layout/window_size_class.dart';
import '../../../core/theme/application/theme_providers.dart';
import '../../../core/theme/domain/theme_strings.dart';
import '../../../core/theme/domain/theme_icons.dart';
import '../../../core/theme/domain/theme_now_playing.dart';
import '../../../core/theme/domain/theme_tokens.dart';
import '../../../core/theme/infrastructure/token_resolver.dart';
import '../../../core/theme/presentation/theme_icon.dart';
import '../../../core/theme/presentation/theme_ambient.dart';
import '../../../shared/widgets/search_action_button.dart';
import '../../../shared/widgets/horizontal_wheel_scroll.dart';
import '../../../shared/widgets/song_actions_menu.dart';
import '../../../shared/widgets/window_control_button.dart';
import '../../lyrics/application/lyrics_providers.dart';
import '../../downloads/application/download_providers.dart';
import '../../playlists/application/playlist_providers.dart';
import '../../playlists/infrastructure/playlist_repository.dart';
import '../../plugin/application/plugin_controller.dart';
import '../../plugin/domain/plugin_definition.dart';
import '../../settings/application/settings_providers.dart';
import '../application/player_providers.dart';
import '../domain/playback_item.dart';
import 'artwork_view.dart';
import 'progress_slider.dart';

const _lyricsSystemEnabled = true;

/// Keep the cover and lyric geometry at its existing height above the controls.
const double _transportReserve =
    _transportBandHeight * 2 + _transportBarPadding;

/// Narrow windows stack the song actions above the transport.
const double _compactTransportReserve = _transportReserve + 52 + 8;

const double _transportBandHeight = 40;
const double _transportProgressHeight = 20;
const double _transportCompactBreakpoint = 720;

/// Bottom inset the floating transport keeps from the window edge.
const double _transportBarPadding = 6;

/// Widest the song's identity block on the left of the transport is allowed to
/// get. The reference keeps the title/artist caption compact so the transport
/// stays centred rather than being shoved right by a long title.
const double _songInfoWidth = 220;

/// Share of its column's height the cover asks for.
///
/// Trimmed to 90% of the previous extent: the cover was reading as slightly
/// oversized next to the text column, and the composition gains breathing room
/// at both ends when it shrinks.
const double _artworkScale = 0.9;

/// Share of [availableHeight] the cover is allowed to occupy.
///
/// The page centres on the available content box, which already excludes the
/// transport reserve; sizing the cover from that same box is what makes it sit
/// on the page's own optical centre instead of running up toward the title bar.
const double _artworkHeightRatio = 0.52;

/// Hard ceiling for the cover in dp.
///
/// On a very tall window the ratio alone would hand the cover most of the
/// screen and push the text column into a sliver; the reference keeps the
/// artwork at a sleeve-like size however much room it has.
const double _artworkMaxExtent = 520;

/// How tall the text column is relative to the cover.
///
/// Above 1 the column runs past the cover at both ends, which is what
/// makes the two read as a centred pair: the gap above the text equals the gap
/// below it, and both are measured from the cover's own edges. The reference
/// gives its lyric column considerably more vertical room than its artwork —
/// 1.2x the cover, stretched by another 1.2x.
const double _textBlockScale = 1.44;

/// Keeps the lyric pane scrollable while suppressing the transient scrollbar.
///
/// Auto-following the active line calls `jumpTo`, and Material's scrollbar
/// animates in for even programmatic jumps. The lyrics are a reading surface,
/// not a scrollable document chrome; wheel drag and touch still work.
class _NoScrollbarScrollBehavior extends MaterialScrollBehavior {
  const _NoScrollbarScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class NowPlayingPage extends ConsumerWidget {
  const NowPlayingPage({
    super.key,
    this.immersive = false,
    this.onClose,
    this.showWindowControls = false,
  });

  /// True when this page is covering the whole shell as an immersive layer.
  ///
  /// The immersive variant owns its close affordance and never pushes a
  /// route, so opening and closing it does not disturb the shell's tab.
  final bool immersive;
  final VoidCallback? onClose;
  final bool showWindowControls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sizeClass = WindowSizeClass.of(context);
    final desktopWindowControls =
        showWindowControls && !sizeClass.isCompactWidth;
    final item = ref.watch(
      playerControllerProvider.select((value) => value.value?.currentItem),
    );
    final strings = ref.watch(activeThemeStringsProvider);
    // The player owns its own brightness when the skin asks for it (QQ Music's
    // light player inside a dark app). Overriding the theme extension here —
    // rather than threading a tokens argument through every child — is what
    // makes the lyric pane, the menus and the dialogs agree with the surface
    // without each one having to know about the inversion.
    final playerTokens = ref.watch(nowPlayingTokensProvider);
    final playerThemeData = ref.watch(nowPlayingThemeDataProvider);
    final body = item == null
        ? Center(
            child: Text(strings.resolve(ThemeStringKey.playerNothingPlaying)),
          )
        : _PlayerContent(item: item, immersive: immersive);
    // The page is the song-action surface, and the lyric pane nests its own
    // detector inside it. Because the inner gesture detector wins on the
    // pixels it covers, the layering is exactly "song features everywhere,
    // lyric features inside the lyric region" — the split the user asked for,
    // with no hit-test bookkeeping.
    final content = item == null
        ? body
        : SongContextMenuRegion(
            item: item,
            headerKey: ThemeStringKey.nowPlayingSongMenu,
            child: body,
          );
    if (!immersive) {
      return Theme(data: playerThemeData, child: content);
    }
    final tokens = playerTokens;
    final layout = ref.watch(activeThemeNowPlayingLayoutProvider);
    final chrome = _ImmersivePlayerChrome(
      showWindowControls: desktopWindowControls,
      onClose: onClose,
      onCloseWindow: () async {
        await ref.read(desktopTrayControllerProvider).onTitleBarClose();
      },
      bottomBarBuilder: item == null
          ? null
          : (onPopupChanged) => _NowPlayingTransportBar(
              item: item,
              onClose: onClose,
              onPopupChanged: onPopupChanged,
            ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: _NowPlayingBackdrop(
              item: item,
              layout: layout,
              tokens: tokens,
            ),
          ),
          Positioned.fill(child: SafeArea(top: false, child: content)),
          // The queue is drawn *inside* the immersive layer, not by the shell:
          // the shell's docked panel sits behind this overlay, so toggling it
          // from here used to write state that the user could never see, which
          // is why the button looked dead.
          if (item != null)
            _NowPlayingQueuePanel(tokens: playerTokens, strings: strings),
        ],
      ),
    );
    return Theme(data: playerThemeData, child: chrome);
  }
}

/// The queue, drawn inside the immersive player.
///
/// Slides in over the page when the transport's queue button is pressed. It
/// owns a per-row remove button as well as the row's right-click menu, because
/// "remove this track from the playlist" is the one action a queue is
/// constantly asked for and hiding it behind a menu makes it feel missing.
class _NowPlayingQueuePanel extends ConsumerWidget {
  const _NowPlayingQueuePanel({required this.tokens, required this.strings});

  final ThemeTokens tokens;
  final ThemeStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(nowPlayingQueueOpenProvider);
    final state =
        ref.watch(playerControllerProvider).value ??
        const PlayerControllerState();
    final motion = tokens.components.motion;
    final colors = tokens.color;
    // A queue with nothing in it has nothing to show, so the panel stays shut
    // rather than opening an empty sheet over the song.
    final showing = open && state.queue.isNotEmpty;

    return IgnorePointer(
      ignoring: !showing,
      child: AnimatedOpacity(
        key: const Key('now-playing-queue-panel'),
        opacity: showing ? 1 : 0,
        duration: motion.short,
        curve: motion.curve.toCurve,
        child: Stack(
          children: <Widget>[
            // Click-away scrim, kept light so the artwork still reads through.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    ref.read(nowPlayingQueueOpenProvider.notifier).close(),
                child: ColoredBox(
                  color: colors.backgroundOverlay.withValues(alpha: 0.18),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: colors.backgroundElevated,
                child: SizedBox(
                  width: 340,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                strings.resolve(ThemeStringKey.queueTitle),
                                style: TextStyle(
                                  fontSize:
                                      tokens.typography.resolvedListPrimarySize,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: strings.resolve(
                                ThemeStringKey.queueCollapse,
                              ),
                              iconSize: 18,
                              color: colors.textMuted,
                              onPressed: () => ref
                                  .read(nowPlayingQueueOpenProvider.notifier)
                                  .close(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: colors.borderSubtle),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: state.queue.length,
                          itemBuilder: (context, index) {
                            final entry = state.queue[index];
                            final active = entry.id == state.currentItem?.id;
                            return SongContextMenuRegion(
                              item: entry,
                              inQueue: true,
                              child: Material(
                                color: active
                                    ? colors.surfaceSelected
                                    : Colors.transparent,
                                child: InkWell(
                                  onTap: () => ref
                                      .read(playerControllerProvider.notifier)
                                      .playItem(entry),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      4,
                                      2,
                                      4,
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        ArtworkView(
                                          artworkUrl: entry.artworkUrl,
                                          size: 34,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                entry.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: tokens
                                                      .typography
                                                      .resolvedListPrimarySize,
                                                  fontWeight: active
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                                  color: colors.textPrimary,
                                                ),
                                              ),
                                              if (entry.artist != null)
                                                Text(
                                                  entry.artist!,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: colors.textMuted,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        // The per-track remove control the
                                        // queue has always needed.
                                        IconButton(
                                          key: ValueKey<String>(
                                            'queue-remove-${entry.id}',
                                          ),
                                          tooltip: strings.resolve(
                                            ThemeStringKey.actionRemove,
                                          ),
                                          iconSize: 16,
                                          color: colors.textMuted,
                                          onPressed: () => ref
                                              .read(
                                                playerControllerProvider
                                                    .notifier,
                                              )
                                              .removeFromQueue(entry.id),
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Owns the immersive player's auto-hiding chrome.
///
/// QQ Music's player shows its transport only while the pointer is in the
/// window and fades it out otherwise, so the artwork and lyrics own the
/// screen. That is the behaviour here: the top window controls and the bottom
/// transport fade together, and the page keeps a persistent close affordance
/// on touch where there is no hover to reveal them.
class _ImmersivePlayerChrome extends ConsumerStatefulWidget {
  const _ImmersivePlayerChrome({
    required this.showWindowControls,
    required this.onClose,
    required this.onCloseWindow,
    required this.child,
    this.bottomBarBuilder,
  });

  final bool showWindowControls;
  final VoidCallback? onClose;
  final Future<void> Function() onCloseWindow;

  /// The transport row. Fades with the window controls.
  final Widget Function(ValueChanged<bool> onPopupChanged)? bottomBarBuilder;

  final Widget child;

  @override
  ConsumerState<_ImmersivePlayerChrome> createState() =>
      _ImmersivePlayerChromeState();
}

class _ImmersivePlayerChromeState
    extends ConsumerState<_ImmersivePlayerChrome> {
  Timer? _hideTimer;

  /// True while the pointer is inside any chrome band.
  ///
  /// The hide used to be a pure timer: it started on `initState` and kept
  /// running even when the pointer was resting on a button, so a user who
  /// paused before clicking watched the button fade out and then clicked
  /// nothing. Hovering a band now suppresses the hide entirely — the chrome
  /// hides when the pointer *leaves the bands*, never while it is being aimed.
  /// The count is what keeps "over a button" from meaning "anywhere in the
  /// window": the bands are the top controls and the bottom transport only.
  bool _hovered = false;
  int _bands = 0;
  bool _visible = true;
  bool _popupOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.showWindowControls) {
      _scheduleHide();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(activeThemeStringsProvider);
    final bottomBar = widget.bottomBarBuilder?.call(_setPopupOpen);
    if (!widget.showWindowControls) {
      // Touch has no hover state, so the phone's close control is a
      // persistent part of the layout rather than part of the auto-hiding
      // desktop chrome: hiding it is what stranded the user in this surface.
      // The transport is persistent for the same reason — a phone has no
      // pointer to reveal it — but it is the same widget, so the two form
      // factors cannot drift apart.
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          widget.child,
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 40,
                child: IconButton(
                  key: const Key('now-playing-close'),
                  tooltip: strings.resolve(ThemeStringKey.nowPlayingClose),
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                ),
              ),
            ),
          ),
          if (bottomBar != null)
            Positioned(left: 0, right: 0, bottom: 0, child: bottomBar),
        ],
      );
    }
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    // Hover is tracked per *chrome band*, not per page. Wrapping the whole
    // page made the pointer anywhere in the window count as "aiming at a
    // control", so the chrome never hid at all — the opposite of the request.
    // Each band reports entry/exit independently and the gate below is the
    // union, so the chrome stays up while the pointer is over either one.
    //
    // The band must not swallow the pointer: a default `MouseRegion` is
    // opaque, so it claimed the whole top strip before the drag region behind
    // it was ever hit-tested — that is what left the title bar dead to
    // dragging. `opaque: false` plus a translucent hit test keeps the
    // enter/exit reporting while letting the drag layer win where no control
    // is under the pointer.
    Widget band({required Widget child}) {
      return MouseRegion(
        opaque: false,
        hitTestBehavior: HitTestBehavior.translucent,
        onEnter: (_) => _enterBand(),
        onHover: (_) => _show(),
        onExit: (_) => _exitBand(),
        child: child,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: band(
            child: Stack(
              children: <Widget>[
                // The window controls own the top-right corner, but the rest
                // of the strip belongs to the title bar. `DragToMoveArea` wins
                // the gesture arena as soon as the pointer moves, even when a
                // button below already accepted the press — the translucent
                // `GestureDetector` lost that race, so the top strip was dead
                // to dragging. Buttons keep working because a simple tap
                // resolves before the pan recogniser is ready to claim.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 56,
                  child: DragToMoveArea(
                    key: const Key('now-playing-drag-region'),
                    child: const SizedBox.expand(),
                  ),
                ),
                IgnorePointer(
                  ignoring: !_visible,
                  child: AnimatedOpacity(
                    key: const Key('now-playing-window-controls'),
                    opacity: _visible ? 1 : 0,
                    duration: tokens.components.motion.short,
                    curve: tokens.components.motion.curve.toCurve,
                    child: SafeArea(
                      bottom: false,
                      child: SizedBox(
                        height: 40,
                        child: Row(
                          children: <Widget>[
                            if (widget.onClose != null)
                              IconButton(
                                key: const Key('now-playing-close'),
                                tooltip: strings.resolve(
                                  ThemeStringKey.nowPlayingClose,
                                ),
                                color: colors.textSecondary,
                                onPressed: widget.onClose,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 20,
                                ),
                              ),
                            const Spacer(),
                            WindowControlButton(
                              key: const Key('now-playing-window-minimize'),
                              icon: Icons.horizontal_rule,
                              tooltip: strings.resolve(
                                ThemeStringKey.windowMinimize,
                              ),
                              onPressed: () =>
                                  unawaited(windowManager.minimize()),
                            ),
                            WindowControlButton(
                              key: const Key('now-playing-window-maximize'),
                              icon: Icons.crop_square,
                              tooltip: strings.resolve(
                                ThemeStringKey.windowMaximize,
                              ),
                              onPressed: () => unawaited(_toggleMaximize()),
                            ),
                            WindowControlButton(
                              key: const Key('now-playing-window-close'),
                              icon: Icons.close,
                              tooltip: strings.resolve(
                                ThemeStringKey.windowClose,
                              ),
                              destructive: true,
                              onPressed: () =>
                                  unawaited(widget.onCloseWindow()),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (bottomBar != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: band(
              child: IgnorePointer(
                ignoring: !_visible,
                child: AnimatedOpacity(
                  key: const Key('now-playing-transport'),
                  opacity: _visible ? 1 : 0,
                  duration: tokens.components.motion.short,
                  curve: tokens.components.motion.curve.toCurve,
                  child: bottomBar,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _show() {
    _hideTimer?.cancel();
    if (!_visible && mounted) {
      setState(() => _visible = true);
    }
    _scheduleHide();
  }

  void _setPopupOpen(bool open) {
    _popupOpen = open;
    _show();
  }

  void _enterBand() {
    _bands += 1;
    _hovered = true;
    _show();
  }

  void _exitBand() {
    _bands = (_bands - 1).clamp(0, 2);
    if (_bands == 0) {
      _hovered = false;
    }
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    // The pointer is resting on the chrome: it is being aimed at a button,
    // and hiding underneath it is what made a hesitant click miss. Hold the
    // chrome until the pointer leaves.
    if (_hovered || _popupOpen) {
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 1), _hide);
  }

  void _hide() {
    _hideTimer = null;
    if (mounted && _visible) {
      setState(() => _visible = false);
    }
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
      return;
    }
    await windowManager.maximize();
  }
}

/// The full-window player's background.
///
/// Three modes, all skin-declared:
///
/// * `blurredCover` — the old look: blurred artwork behind a colour wash.
/// * `artworkGradient` — a diagonal gradient sampled from the artwork's
///   dominant colour into the skin background, which is the "light, tinted"
///   look of the reference screenshot.
/// * `plain` — skin background only.
class _NowPlayingBackdrop extends ConsumerWidget {
  const _NowPlayingBackdrop({
    required this.item,
    required this.layout,
    required this.tokens,
  });

  final PlaybackItem? item;
  final ThemeNowPlayingLayout layout;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = item?.artworkUrl;
    switch (layout.background) {
      case ThemeNowPlayingBackground.artworkGradient:
        final palette = url == null || url.isEmpty
            ? null
            : ref.watch(artworkPaletteProvider(url)).value;
        final base = tokens.color.backgroundBase;
        final strength = layout.artworkGradientStrength.clamp(0.0, 1.0);
        // The reference wash is the cover's own colours, not one flat tint: a
        // blurred copy of the artwork supplies the detail and the two dominant
        // colours supply the direction. Layering them is what makes the page
        // feel like it grew out of the song rather than out of a swatch.
        final primary = palette?.primary ?? base;
        final secondary = palette?.secondary ?? primary;

        // Legibility stays the application's decision (design spec §3.4 rule
        // 3): a near-black cover must not turn a light player dark, so every
        // colour is pulled toward the skin's surface by [strength].
        // Legibility stays the application's decision (design spec §3.4 rule
        // 3): a near-black cover must not turn a light player dark, so the
        // wash is resolved *inside* the gradient rather than layered over it —
        // each stop is the cover colour pulled toward the surface, and the
        // blurred artwork underneath keeps the blend from reading as plastic.
        Color wash(Color colour, double mix) =>
            Color.lerp(base, colour, (strength * mix).clamp(0.0, 1.0)) ?? base;

        final gradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            wash(primary, 0.85),
            wash(secondary, 0.70),
            wash(primary, 0.55),
          ],
          stops: const <double>[0, 0.55, 1],
        );

        Widget? blurredCover;
        if (url != null && url.isNotEmpty) {
          blurredCover = Positioned.fill(
            child: ImageFiltered(
              // A wide, low-sigma blur reads as light on the page; a tight
              // high-sigma one reads as a hidden photograph, which is what the
              // reference deliberately avoids.
              imageFilter: ui.ImageFilter.blur(sigmaX: 72, sigmaY: 72),
              child: Opacity(
                opacity: (strength * 0.55).clamp(0.0, 0.65),
                child: ArtworkView(
                  artworkUrl: url,
                  size: MediaQuery.sizeOf(context).longestSide,
                ),
              ),
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
            ?blurredCover,
            // A legibility wash used to sit on top at ~85% alpha, which is
            // what made the two-colour blend invisible: the gradient was
            // painted and then almost entirely covered by the base colour.
            // Pulling the wash into the gradient stops the two from fighting.
          ],
        );
      case ThemeNowPlayingBackground.blurredCover:
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: tokens.color.backgroundBase),
            if (url != null)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: tokens.effects.blur.clamp(1, 40),
                    sigmaY: tokens.effects.blur.clamp(1, 40),
                  ),
                  child: ArtworkView(
                    artworkUrl: url,
                    size: MediaQuery.sizeOf(context).longestSide,
                  ),
                ),
              ),
            Positioned.fill(
              child: ColoredBox(
                color: tokens.color.backgroundBase.withValues(alpha: 0.72),
              ),
            ),
          ],
        );
      case ThemeNowPlayingBackground.plain:
        return ColoredBox(color: tokens.color.backgroundBase);
    }
  }
}

class _PlayerContent extends ConsumerWidget {
  const _PlayerContent({required this.item, this.immersive = false});

  final PlaybackItem item;

  /// True when this is the full-window player. The design drops the per-track
  /// actions there (spec §4.3: "不出现第二套播放按钮") and gives the artwork a
  /// progress line instead, so the immersive variant is not just a bigger
  /// copy of the destination page.
  final bool immersive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final playlists = ref.watch(playlistControllerProvider).value;
    final layout = ref.watch(activeThemeNowPlayingLayoutProvider);
    final favorite =
        playlists
            ?.where((playlist) => playlist.id == PlaylistRepository.favoritesId)
            .any(
              (playlist) => playlist.items.any(
                (playlistItem) => playlistItem.id == item.id,
              ),
            ) ??
        false;

    final sizeClass = WindowSizeClass.of(context);
    final padding = sizeClass.isCompactWidth ? 12.0 : 24.0;

    // The transport floats over the bottom of the window, so the composition
    // reserves its height instead of letting the cover slide underneath it.
    // QQ Music's player is a tight centred lockup; a 300dp cover floating in a
    // 900dp window reads as an empty page, so the artwork is sized against the
    // *available* height as well as the width.
    final reservedBottom = !immersive
        ? 0.0
        : MediaQuery.sizeOf(context).width < _transportCompactBreakpoint
        ? _compactTransportReserve
        : _transportReserve;
    final availableHeight =
        (MediaQuery.sizeOf(context).height - reservedBottom - padding * 2)
            .clamp(160.0, double.infinity);

    // The reference design does not hug the leading edge: artwork *and* copy
    // sit inboard of it. That is one knob (`contentInset`, a fraction of the
    // width) rather than a pixel guess, so the same skin reads the same at
    // 900dp and at 2560dp.
    final contentInset = artworkInsetFor(context, layout);

    // The 340dp art column was fixed: on a 400dp-wide phone the content area
    // is ~336dp, so art + divider + lyrics overflowed and the lyrics pane was
    // pushed off-screen entirely. Every extent is now derived from the
    // viewport. See ADR-001 decision D4.
    // The cover owns roughly half the content height — enough to read as the
    // page's subject, small enough to leave the lyrics their room. Deriving it
    // from [availableHeight] (which already excludes the transport reserve)
    // keeps it inside the page's centring frame instead of the full window.
    final artSize =
        sizeClass.clampDimension(
          availableHeight * _artworkHeightRatio,
          maxRatio: 0.52,
          maxExtent: _artworkMaxExtent,
        ) *
        _artworkScale;
    final artworkBlock = _NowPlayingArtwork(item: item, artworkSize: artSize);
    final infoBlock = _NowPlayingInfo(
      item: item,
      favorite: favorite,
      artworkSize: artSize,
      withArtwork:
          layout.infoPlacement == ThemeNowPlayingInfoPlacement.underArtwork,
      immersive: immersive,
    );
    // `aboveLyrics` moves the title/artist lockup to head the text column,
    // which is what the reference screenshot does; `underArtwork` keeps it
    // captioned to the cover, which is what the pre-existing skins do.
    final artworkOnly =
        layout.infoPlacement == ThemeNowPlayingInfoPlacement.aboveLyrics
        ? artworkBlock
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              artworkBlock,
              const SizedBox(height: 16),
              infoBlock,
            ],
          );

    if (sizeClass.isCompactWidth) {
      // Compact width: the two panes cannot share the axis, so they become
      // tabs. This is the Material list-detail pattern; stacking them would
      // give each pane ~80dp of height on a landscape phone.
      return DefaultTabController(
        length: 2,
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            children: <Widget>[
              TabBar(
                tabs: <Tab>[
                  Tab(
                    icon: const Icon(Icons.album_outlined),
                    text: strings.resolve(ThemeStringKey.nowPlayingTabNow),
                  ),
                  Tab(
                    icon: const Icon(Icons.lyrics_outlined),
                    text: strings.resolve(ThemeStringKey.nowPlayingTabLyrics),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          artworkOnly,
                          if (layout.infoPlacement ==
                              ThemeNowPlayingInfoPlacement.aboveLyrics) ...[
                            const SizedBox(height: 16),
                            infoBlock,
                          ],
                        ],
                      ),
                    ),
                    _lyricsSystemEnabled
                        ? _LyricsPane(item: item)
                        : const _LyricsDisabledPane(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Compact *height* with a non-compact width (landscape phone): keep both
    // panes side by side but shrink the art so the lyrics keep usable height.
    final artColumnWidth = artSize + (sizeClass.isCompactHeight ? 16 : 24);

    // The text column is centred on the cover's own centre line rather than
    // pinned under the top edge. Giving it a definite height makes that
    // symmetry explicit: the gap above the title, the gap below the last
    // lyric, and the two gaps between the block and the cover are all equal.
    //
    // Skins that caption the cover instead (`underArtwork`) have no info in
    // this column, so for them the lyrics keep the full available height: the
    // reference ratio would otherwise shrink a pane that is already the only
    // thing in it.
    final textBlockHeight =
        (layout.infoPlacement == ThemeNowPlayingInfoPlacement.aboveLyrics
                ? artSize * _textBlockScale
                : availableHeight)
            .clamp(0.0, availableHeight);

    // Two panes share the width. Both are allowed to scroll internally, but
    // neither is wrapped in an outer scroll view: the lyrics pane is itself a
    // viewport, and nesting it under an unbounded axis is what produced the
    // compact-height overflow this layout used to have.
    //
    // The skin decides whether the artwork column leads or trails, whether the
    // divider is drawn, and how far the artwork is inset from its edge. The
    // lyrics region also gets its own right-click menu, because the user asked
    // for lyric actions to be reachable from the lyric surface itself.
    final artworkColumn = Padding(
      padding: EdgeInsets.only(left: layout.artworkOnRight ? 0 : contentInset),
      child: SizedBox(
        width: artColumnWidth,
        // The cover is centred in the *content* box, not in the window: the
        // transport reserve at the bottom is not part of the composition, so
        // centring across the full height pushed the artwork up and left the
        // page reading top-heavy.
        //
        // Not scrollable. Making it scrollable let the cover be dragged up and
        // down, and the scroll gesture then won over the window's own drag
        // gesture, which is what stopped the page from being draggable. The
        // cover is already sized so it always fits; it does not need to scroll.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          // The transport moved to the auto-hiding bottom bar, so the
          // artwork block is now only the cover: that is what makes the
          // page read as immersive instead of as a form.
          children: <Widget>[artworkOnly],
        ),
      ),
    );
    final lyricsColumn = _LyricMenuRegion(
      item: item,
      child: Padding(
        // The divider is gone and both panes are inside the same inset, so the
        // page reads as one centred composition rather than two columns.
        padding: EdgeInsets.only(
          left: contentInset * 0.5,
          right: layout.artworkOnRight ? contentInset : contentInset * 0.5,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: availableHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                height: textBlockHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // `aboveLyrics` is the reference composition: the title
                    // and artist introduce the reading column, and the artwork
                    // stands alone.
                    if (layout.infoPlacement ==
                        ThemeNowPlayingInfoPlacement.aboveLyrics) ...<Widget>[
                      infoBlock,
                      const SizedBox(height: 16),
                    ],
                    Expanded(
                      child: _lyricsSystemEnabled
                          ? _LyricsPane(item: item)
                          : const _LyricsDisabledPane(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final panes = layout.artworkOnRight
        ? <Widget>[
            Expanded(child: lyricsColumn),
            if (layout.showDivider) const VerticalDivider(width: 48),
            artworkColumn,
          ]
        : <Widget>[
            artworkColumn,
            if (layout.showDivider) const VerticalDivider(width: 48),
            Expanded(child: lyricsColumn),
          ];
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: panes,
      ),
    );
  }
}

/// Cover art plus title/artist/actions, shared by every layout variant.
double artworkInsetFor(BuildContext context, ThemeNowPlayingLayout layout) {
  // The inset is a share of the viewport, then capped so a very wide window
  // does not push the artwork a metre away from the edge.
  final width = MediaQuery.sizeOf(context).width;
  return (width * layout.contentInset).clamp(0.0, 220.0);
}

/// Just the cover. Kept separate from [_NowPlayingInfo] so a skin can place
/// the title/artist lockup above the lyrics while leaving the artwork where it
/// is, which is the reference screenshot's composition.
class _NowPlayingArtwork extends StatelessWidget {
  const _NowPlayingArtwork({required this.item, required this.artworkSize});

  final PlaybackItem item;
  final double artworkSize;

  @override
  Widget build(BuildContext context) {
    return ArtworkView(artworkUrl: item.artworkUrl, size: artworkSize);
  }
}

/// Title, artist and the per-track actions.
class _NowPlayingInfo extends ConsumerWidget {
  const _NowPlayingInfo({
    required this.item,
    required this.favorite,
    required this.artworkSize,
    required this.withArtwork,
    this.immersive = false,
  });

  final PlaybackItem item;
  final bool favorite;

  /// Reserved space so the info block lines up with the reference regardless of
  /// whether the artwork is drawn above it.
  final double artworkSize;

  /// True when the artwork is rendered by this widget's caller above the info.
  final bool withArtwork;
  final bool immersive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final layout = ref.watch(activeThemeNowPlayingLayoutProvider);
    // A centred artwork implies centred copy; otherwise the skin's declared
    // alignment wins. `immersive` no longer forces centring, because that was
    // the hard-coded look this model replaces.
    final alignment = layout.centered
        ? CrossAxisAlignment.center
        : switch (layout.metadataAlignment) {
            ThemeNowPlayingAlignment.start => CrossAxisAlignment.start,
            ThemeNowPlayingAlignment.center => CrossAxisAlignment.center,
            ThemeNowPlayingAlignment.end => CrossAxisAlignment.end,
          };
    final textAlign = layout.centered
        ? TextAlign.center
        : switch (layout.metadataAlignment) {
            ThemeNowPlayingAlignment.start => TextAlign.start,
            ThemeNowPlayingAlignment.center => TextAlign.center,
            ThemeNowPlayingAlignment.end => TextAlign.end,
          };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: <Widget>[
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: tokens.typography.resolvedSectionTitleSize,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          // The mockup's caption is artist over album; the platform is a
          // routing detail that does not belong in the artwork lockup.
          layout.centered
              ? <String?>[item.artist, item.album]
                    .whereType<String>()
                    .where((value) => value.isNotEmpty)
                    .join(' / ')
              : <String?>[item.artist, item.album, item.platform]
                    .whereType<String>()
                    .where((value) => value.isNotEmpty)
                    .join(' - '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: immersive
                ? tokens.typography.resolvedLabelSize
                : tokens.typography.resolvedListSecondarySize,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Song actions on the left, a centred transport, and utilities on the right.
class _NowPlayingTransportBar extends ConsumerWidget {
  const _NowPlayingTransportBar({
    required this.item,
    required this.onPopupChanged,
    this.onClose,
  });

  final PlaybackItem item;
  final VoidCallback? onClose;
  final ValueChanged<bool> onPopupChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final palette = item.artworkUrl == null || item.artworkUrl!.isEmpty
        ? null
        : ref.watch(artworkPaletteProvider(item.artworkUrl!)).value;
    final accent = palette?.primary ?? colors.brandBase;
    final accentInk = palette?.onColor ?? colors.onBrand;
    final state = ref.watch(playerControllerProvider).value;
    final progress = ref.watch(playbackProgressProvider);
    final volume = (state?.volume ?? 100).clamp(0, 100).toDouble();
    final queueOpen = ref.watch(nowPlayingQueueOpenProvider);
    final timeStyle = TextStyle(
      fontSize: 10,
      color: colors.textMuted,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );

    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < _transportCompactBreakpoint;
          final horizontalPadding = compact ? 12.0 : 24.0;
          final availableWidth = constraints.maxWidth - horizontalPadding * 2;
          final centerWidth = compact
              ? availableWidth
              : (constraints.maxWidth * 0.34).clamp(300.0, 460.0);
          final songActions = _NowPlayingSongActions(
            item: item,
            onClose: onClose,
            onPopupChanged: onPopupChanged,
          );
          final utilities = Row(
            key: const Key('now-playing-utilities'),
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              _NowPlayingQualityChip(
                quality: ref
                    .watch(playerSnapshotsProvider)
                    .value
                    ?.currentSource
                    ?.quality,
              ),
              const SizedBox(width: 8),
              _NowPlayingLyricsButton(accent: accent),
              const SizedBox(width: 8),
              _TransportButton(
                key: const Key('now-playing-queue'),
                icon: Icons.queue_music_outlined,
                slot: ThemeIconKey.queue,
                tooltip: strings.resolve(ThemeStringKey.playerQueue),
                color: queueOpen ? accent : colors.textSecondary,
                hoverColor: accent,
                onPressed: () =>
                    ref.read(nowPlayingQueueOpenProvider.notifier).toggle(),
              ),
            ],
          );
          final center = SizedBox(
            key: const Key('now-playing-center-controls'),
            width: centerWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: centerWidth >= 300 ? 16 : 8,
                  children: <Widget>[
                    if (centerWidth >= 260)
                      _TransportButton(
                        key: const Key('now-playing-mode'),
                        icon: _modeIcon(state?.playbackMode),
                        tooltip: _modeLabel(strings, state?.playbackMode),
                        color: colors.textSecondary,
                        hoverColor: accent,
                        onPressed: () => ref
                            .read(playerControllerProvider.notifier)
                            .setPlaybackMode(_nextMode(state?.playbackMode)),
                      ),
                    _TransportButton(
                      icon: Icons.skip_previous,
                      slot: ThemeIconKey.skipPrevious,
                      tooltip: strings.resolve(ThemeStringKey.playerPrevious),
                      color: colors.textPrimary,
                      hoverColor: accent,
                      onPressed: state?.queue.isEmpty ?? true
                          ? null
                          : () => ref
                                .read(playerControllerProvider.notifier)
                                .playPrevious(),
                    ),
                    SizedBox(
                      width: _transportBandHeight,
                      height: _transportBandHeight,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 32,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.all(
                              Radius.circular(tokens.radius.full),
                            ),
                          ),
                          child: IconButton(
                            key: const Key('now-playing-play'),
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(40, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            tooltip: strings.resolve(
                              progress.playing
                                  ? ThemeStringKey.playerPause
                                  : ThemeStringKey.playerPlay,
                            ),
                            onPressed: progress.playing
                                ? () => ref
                                      .read(playerControllerProvider.notifier)
                                      .pause()
                                : () => ref
                                      .read(playerControllerProvider.notifier)
                                      .resumeOrPlayCurrent(),
                            icon: Icon(
                              progress.playing ? Icons.pause : Icons.play_arrow,
                              size: 22,
                              color: accentInk,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _TransportButton(
                      icon: Icons.skip_next,
                      slot: ThemeIconKey.skipNext,
                      tooltip: strings.resolve(ThemeStringKey.playerNext),
                      color: colors.textPrimary,
                      hoverColor: accent,
                      onPressed: state?.queue.isEmpty ?? true
                          ? null
                          : () => ref
                                .read(playerControllerProvider.notifier)
                                .playNext(),
                    ),
                    _NowPlayingVolumeButton(
                      value: volume,
                      accent: accent,
                      onPopupChanged: onPopupChanged,
                    ),
                  ],
                ),
                SizedBox(
                  height: _transportProgressHeight,
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 32,
                        child: Text(
                          _formatElapsed(progress.position),
                          textAlign: TextAlign.right,
                          style: timeStyle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ProgressSlider(
                          key: const Key('now-playing-progress'),
                          value: progress.position.inMilliseconds.toDouble(),
                          max: progress.max,
                          trackHeight: 3,
                          thumbRadius: 5,
                          overlayRadius: 8,
                          activeColor: accent,
                          inactiveColor: colors.borderDefault,
                          onChangeEnd: progress.duration > Duration.zero
                              ? (value) => ref
                                    .read(playerControllerProvider.notifier)
                                    .seek(Duration(milliseconds: value.round()))
                              : null,
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 32,
                        child: Text(
                          _formatTotalDuration(progress.duration),
                          style: timeStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          return Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              12,
              horizontalPadding,
              _transportBarPadding,
            ),
            child: compact
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(child: songActions),
                          const SizedBox(width: 8),
                          utilities,
                        ],
                      ),
                      const SizedBox(height: 8),
                      center,
                    ],
                  )
                : Row(
                    children: <Widget>[
                      Expanded(child: songActions),
                      center,
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: utilities,
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _NowPlayingSongActions extends ConsumerWidget {
  const _NowPlayingSongActions({
    required this.item,
    required this.onClose,
    required this.onPopupChanged,
  });

  final PlaybackItem item;
  final VoidCallback? onClose;
  final ValueChanged<bool> onPopupChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final colors = RobyneTheme.of(context).tokens.color;
    final favorite =
        ref
            .watch(playlistControllerProvider)
            .value
            ?.where((playlist) => playlist.id == PlaylistRepository.favoritesId)
            .any(
              (playlist) =>
                  playlist.items.any((candidate) => candidate.id == item.id),
            ) ??
        false;
    final artist = item.artist?.trim();

    return Row(
      key: const Key('now-playing-song-actions'),
      children: <Widget>[
        _TransportButton(
          key: const Key('now-playing-transport-home'),
          icon: Icons.fullscreen_exit,
          iconSize: 26,
          tooltip: strings.resolve(ThemeStringKey.nowPlayingClose),
          color: colors.textSecondary,
          onPressed: onClose,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _songInfoWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text.rich(
                  key: const Key('now-playing-song-info'),
                  TextSpan(
                    text: item.title,
                    children: <InlineSpan>[
                      if (artist != null && artist.isNotEmpty)
                        TextSpan(
                          text: ' - $artist',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      key: const Key('now-playing-like'),
                      tooltip: strings.resolve(
                        favorite
                            ? ThemeStringKey.playerRemoveFromLiked
                            : ThemeStringKey.playerAddToLiked,
                      ),
                      padding: EdgeInsets.zero,
                      style: ButtonStyle(
                        minimumSize: const WidgetStatePropertyAll(
                          Size.square(28),
                        ),
                        maximumSize: const WidgetStatePropertyAll(
                          Size.square(28),
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor:
                            WidgetStateProperty.resolveWith<Color?>((states) {
                              return favorite ||
                                      states.contains(WidgetState.hovered)
                                  ? colors.danger
                                  : colors.textSecondary;
                            }),
                        overlayColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                      ),
                      onPressed: () => ref
                          .read(playlistControllerProvider.notifier)
                          .toggleFavorite(item),
                      icon: Icon(
                        favorite ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _NowPlayingMenu(item: item, onPopupChanged: onPopupChanged),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Uses the existing preview/commit volume commands without rebuilding the
/// whole transport or persisting every slider drag frame.
class _NowPlayingVolumeButton extends ConsumerStatefulWidget {
  const _NowPlayingVolumeButton({
    required this.value,
    required this.accent,
    required this.onPopupChanged,
  });

  final double value;
  final Color accent;
  final ValueChanged<bool> onPopupChanged;

  @override
  ConsumerState<_NowPlayingVolumeButton> createState() =>
      _NowPlayingVolumeButtonState();
}

class _NowPlayingVolumeButtonState
    extends ConsumerState<_NowPlayingVolumeButton> {
  final MenuController _controller = MenuController();
  double? _dragValue;
  double? _wheelTarget;
  bool _open = false;

  double get _value =>
      (_dragValue ?? _wheelTarget ?? widget.value).clamp(0, 100).toDouble();

  @override
  void didUpdateWidget(covariant _NowPlayingVolumeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _wheelTarget = null;
    }
  }

  void _preview(double value) {
    setState(() => _dragValue = value);
    ref.read(playerControllerProvider.notifier).previewVolume(value);
  }

  void _commit(double value) {
    final normalized = value.clamp(0, 100).toDouble();
    setState(() {
      _dragValue = null;
      _wheelTarget = normalized;
    });
    unawaited(
      ref.read(playerControllerProvider.notifier).setVolume(normalized),
    );
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final scroll = event as PointerScrollEvent;
      _commit(_value - scroll.scrollDelta.dy.sign * 5);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);

    return MenuAnchor(
      controller: _controller,
      alignmentOffset: const Offset(-12, -236),
      style: MenuStyle(
        alignment: Alignment.topLeft,
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        ),
        backgroundColor: WidgetStatePropertyAll(colors.backgroundElevated),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radius.md),
            side: BorderSide(color: colors.borderSubtle),
          ),
        ),
      ),
      onOpen: () {
        setState(() => _open = true);
        widget.onPopupChanged(true);
      },
      onClose: () {
        setState(() => _open = false);
        widget.onPopupChanged(false);
      },
      menuChildren: <Widget>[
        SizedBox(
          key: const Key('now-playing-volume-popover'),
          width: 48,
          height: 204,
          child: Listener(
            onPointerSignal: _onPointerSignal,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        activeTrackColor: widget.accent,
                        inactiveTrackColor: colors.borderDefault,
                        thumbColor: widget.accent,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 5,
                        ),
                      ),
                      child: Slider(
                        key: const Key('now-playing-volume-slider'),
                        value: _value,
                        max: 100,
                        onChanged: _preview,
                        onChangeEnd: _commit,
                      ),
                    ),
                  ),
                ),
                Text(
                  '${_value.round()}%',
                  key: const Key('now-playing-volume-percent'),
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, child) => Listener(
        onPointerSignal: _onPointerSignal,
        child: _TransportButton(
          key: const Key('now-playing-volume-button'),
          icon: _value == 0
              ? Icons.volume_off_outlined
              : Icons.volume_up_outlined,
          slot: ThemeIconKey.volume,
          tooltip: strings.resolve(ThemeStringKey.playerVolume),
          color: _open ? widget.accent : colors.textSecondary,
          hoverColor: widget.accent,
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
    );
  }
}

/// The transport's audio-quality pill: `HQ` or the lossless marker.
///
/// Mirrors the shell player bar's chip without its popover: the quality is a
/// property of the source already resolved by the player, so the pill is a
/// status indicator rather than a control. Coloured with the accent when the
/// source is lossless so "better than standard" reads at a glance.
class _NowPlayingQualityChip extends ConsumerWidget {
  const _NowPlayingQualityChip({required this.quality});

  final String? quality;

  static bool _isLossless(String? quality) {
    if (quality == null) {
      return false;
    }
    final normalized = quality.toLowerCase();
    return normalized.contains('lossless') ||
        normalized.contains('flac') ||
        normalized.contains('ape') ||
        normalized.contains('wav') ||
        normalized.contains('hi-res') ||
        normalized.contains('hires') ||
        normalized.contains('sq') ||
        normalized.contains('无损');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);
    final lossless = _isLossless(quality);
    final label = lossless
        ? strings.resolve(ThemeStringKey.qualityLossless)
        : 'HQ';
    return Tooltip(
      message: quality == null
          ? strings.resolve(ThemeStringKey.qualityUnknown)
          : strings
                .resolve(ThemeStringKey.qualityTooltip)
                .replaceAll('{quality}', quality!),
      child: Container(
        key: const Key('now-playing-quality'),
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: lossless ? colors.accentBase : Colors.transparent,
          borderRadius: BorderRadius.all(Radius.circular(tokens.radius.sm)),
          border: Border.all(color: colors.borderDefault),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: lossless ? colors.onAccent : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// The transport's desktop-lyric toggle, reusing the shell bar's action.
class _NowPlayingLyricsButton extends ConsumerWidget {
  const _NowPlayingLyricsButton({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = RobyneTheme.of(context).tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);
    final enabled =
        ref
            .watch(settingsControllerProvider)
            .value
            ?.lyricSettings
            .desktopLyricsEnabled ??
        false;
    return _TransportButton(
      key: const Key('now-playing-desktop-lyrics'),
      icon: Icons.lyrics_outlined,
      slot: ThemeIconKey.lyric,
      tooltip: enabled
          ? strings.resolve(ThemeStringKey.playerHideDesktopLyric)
          : strings.resolve(ThemeStringKey.playerShowDesktopLyric),
      color: enabled ? accent : colors.textSecondary,
      hoverColor: accent,
      onPressed: () => ref
          .read(settingsControllerProvider.notifier)
          .toggleDesktopLyricsEnabled(),
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
    this.slot,
    this.hoverColor,
    this.iconSize = 20,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;
  final ThemeIconKey? slot;
  final double iconSize;

  /// Colour the glyph takes while the pointer is over it.
  ///
  /// Reference players keep the transport as neutral line icons and let them
  /// pick up the song's accent only on hover, so the row stays quiet at rest
  /// and the interaction is what carries the colour. Null keeps [color].
  final Color? hoverColor;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      // Every control in the transport rides the same band, so the button's
      // own 48dp touch target is pinned to it. Left at the default, the target
      // would overflow the band and push the two rows apart again.
      constraints: const BoxConstraints.tightFor(
        width: _transportBandHeight,
        height: _transportBandHeight,
      ),
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size.square(_transportBandHeight),
        ),
        maximumSize: const WidgetStatePropertyAll(
          Size.square(_transportBandHeight),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return hoverColor ?? color;
          }
          return color;
        }),
        overlayColor: const WidgetStatePropertyAll<Color?>(Colors.transparent),
      ),
      padding: EdgeInsets.zero,
      icon: slot == null
          ? Icon(icon, size: iconSize)
          : ThemeIconView(slot: slot!, fallback: icon, size: iconSize),
    );
  }
}

String _formatElapsed(Duration position) {
  final minutes = position.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = position.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _formatTotalDuration(Duration duration) => _formatElapsed(duration);

IconData _modeIcon(PlaybackMode? mode) {
  return switch (mode) {
    PlaybackMode.random => Icons.shuffle,
    PlaybackMode.allLoop => Icons.repeat,
    PlaybackMode.singleLoop => Icons.repeat_one,
    _ => Icons.format_list_numbered,
  };
}

PlaybackMode _nextMode(PlaybackMode? mode) {
  return switch (mode) {
    PlaybackMode.random => PlaybackMode.allLoop,
    PlaybackMode.allLoop => PlaybackMode.singleLoop,
    PlaybackMode.singleLoop => PlaybackMode.sequence,
    _ => PlaybackMode.random,
  };
}

String _modeLabel(ThemeStrings strings, PlaybackMode? mode) {
  return strings.resolve(switch (mode) {
    PlaybackMode.random => ThemeStringKey.modeRandom,
    PlaybackMode.allLoop => ThemeStringKey.modeAllLoop,
    PlaybackMode.singleLoop => ThemeStringKey.modeSingleLoop,
    _ => ThemeStringKey.modeSequence,
  });
}

class _NowPlayingMenu extends ConsumerWidget {
  const _NowPlayingMenu({required this.item, this.onPopupChanged});

  final PlaybackItem item;
  final ValueChanged<bool>? onPopupChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    // The `…` button keeps one entry point, but the sheet is layered: song
    // actions first, then lyric actions, matching the two right-click
    // surfaces the page now exposes.
    return PopupMenuButton<String>(
      key: const Key('now-playing-more'),
      tooltip: strings.resolve(ThemeStringKey.playerMore),
      icon: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: RobyneTheme.of(context).tokens.color.textSecondary,
          ),
        ),
        child: const Icon(Icons.more_horiz, size: 16),
      ),
      // Same band and same 20dp glyph as its neighbours, so the overflow menu
      // does not stand a head taller than the rest of the transport.
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(28),
        maximumSize: const Size.square(28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onOpened: () => onPopupChanged?.call(true),
      onCanceled: () => onPopupChanged?.call(false),
      onSelected: (value) async {
        onPopupChanged?.call(false);
        if (value.startsWith('lyric:')) {
          await runLyricAction(context, ref, item, value.substring(6));
          return;
        }
        switch (value) {
          case 'addPlaylist':
            await showDialog<void>(
              context: context,
              builder: (context) => SongAddToPlaylistDialog(item: item),
            );
          case 'like':
            await ref
                .read(playlistControllerProvider.notifier)
                .toggleFavorite(item);
          case 'download':
            await ref
                .read(downloadControllerProvider.notifier)
                .startDownload(item);
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: _MenuHeader(
            strings.resolve(ThemeStringKey.nowPlayingSongMenu),
          ),
        ),
        PopupMenuItem<String>(
          value: 'like',
          child: ListTile(
            leading: const Icon(Icons.favorite_border),
            title: Text(strings.resolve(ThemeStringKey.playerAddToLiked)),
          ),
        ),
        PopupMenuItem<String>(
          value: 'addPlaylist',
          child: ListTile(
            leading: const Icon(Icons.playlist_add),
            title: Text(strings.resolve(ThemeStringKey.playerAddToPlaylist)),
          ),
        ),
        PopupMenuItem<String>(
          value: 'download',
          child: ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(strings.resolve(ThemeStringKey.actionDownload)),
          ),
        ),
        if (_lyricsSystemEnabled) ...<PopupMenuEntry<String>>[
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            enabled: false,
            child: _MenuHeader(
              strings.resolve(ThemeStringKey.nowPlayingLyricMenu),
            ),
          ),
          PopupMenuItem<String>(
            value: 'lyric:search',
            child: ListTile(
              leading: const Icon(Icons.manage_search),
              title: Text(strings.resolve(ThemeStringKey.playerSearchLyric)),
            ),
          ),
          PopupMenuItem<String>(
            value: 'lyric:local',
            child: ListTile(
              leading: const Icon(Icons.file_open),
              title: Text(strings.resolve(ThemeStringKey.playerLinkLocalLyric)),
            ),
          ),
          PopupMenuItem<String>(
            value: 'lyric:offset',
            enabled: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            height: 124,
            child: _LyricOffsetMenuPanel(item: item),
          ),
          PopupMenuItem<String>(
            value: 'lyric:clear',
            child: ListTile(
              leading: const Icon(Icons.link_off),
              title: Text(strings.resolve(ThemeStringKey.playerClearLyricLink)),
            ),
          ),
        ],
      ],
    );
  }

  /// Applies one lyric action. Shared by the menu button and the lyric-region
  /// right-click menu so both surfaces stay in sync.
  static Future<void> runLyricAction(
    BuildContext context,
    WidgetRef ref,
    PlaybackItem item,
    String action,
  ) async {
    switch (action) {
      case 'search':
        await showDialog<void>(
          context: context,
          builder: (context) => _LyricSearchDialog(item: item),
        );
      case 'local':
        final path = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const <String>['lrc', 'txt'],
        );
        final filePath = path?.files.single.path;
        if (filePath != null) {
          await ref
              .read(lyricRepositoryProvider)
              .associateLocalFile(item, filePath);
          ref.invalidate(storedCurrentLyricsProvider);
        }
      case 'offset':
        // The slider is only interactive inside the layer, so nothing to do
        // here.
        break;
      case 'clear':
        await ref.read(lyricRepositoryProvider).clearAssociation(item);
        ref.read(lyricLiveOffsetProvider(item.id).notifier).setOffset(null);
        ref.invalidate(storedCurrentLyricsProvider);
    }
  }
}

/// Right-click region for the lyric surface.
///
/// The user asked for lyric features to be reachable from the lyric region
/// itself, separate from the song features that live on the rest of the page.
/// This wraps the lyric pane and shows the lyric-only menu.
class _LyricMenuRegion extends ConsumerWidget {
  const _LyricMenuRegion({required this.item, required this.child});

  final PlaybackItem item;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) async {
        // The page-wide song menu wraps this region, so without claiming the
        // gesture first, both menus open. Whoever wins the flag shows; the
        // loser stays shut.
        if (!beginSongMenu()) {
          return;
        }
        await _showLyricMenu(context, ref, details.globalPosition);
      },
      child: child,
    );
  }

  Future<void> _showLyricMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
  ) async {
    final strings = ref.read(activeThemeStringsProvider);
    try {
      final selected = await showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx,
          position.dy,
          position.dx,
          position.dy,
        ),
        items: <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            enabled: false,
            child: _MenuHeader(
              strings.resolve(ThemeStringKey.nowPlayingLyricMenu),
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'search',
            child: ListTile(
              leading: const Icon(Icons.manage_search),
              title: Text(strings.resolve(ThemeStringKey.playerSearchLyric)),
            ),
          ),
          PopupMenuItem<String>(
            value: 'local',
            child: ListTile(
              leading: const Icon(Icons.file_open),
              title: Text(strings.resolve(ThemeStringKey.playerLinkLocalLyric)),
            ),
          ),
          PopupMenuItem<String>(
            value: 'offset',
            enabled: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            height: 124,
            child: _LyricOffsetMenuPanel(item: item),
          ),
          PopupMenuItem<String>(
            value: 'clear',
            child: ListTile(
              leading: const Icon(Icons.link_off),
              title: Text(strings.resolve(ThemeStringKey.playerClearLyricLink)),
            ),
          ),
        ],
      );
      if (!context.mounted || selected == null) {
        return;
      }
      await _NowPlayingMenu.runLyricAction(context, ref, item, selected);
    } finally {
      endSongMenu();
    }
  }
}

class _MenuHeader extends StatelessWidget {
  const _MenuHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: RobyneTheme.of(context).tokens.color.textMuted,
      ),
    );
  }
}

class _LyricsDisabledPane extends ConsumerWidget {
  const _LyricsDisabledPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    return Center(
      child: Text(
        strings.resolve(ThemeStringKey.playerLyricsDisabled),
        style: TextStyle(
          fontSize: RobyneTheme.of(
            context,
          ).tokens.typography.resolvedListPrimarySize,
          color: RobyneTheme.of(context).tokens.color.textMuted,
        ),
      ),
    );
  }
}

class _LyricsPane extends ConsumerStatefulWidget {
  const _LyricsPane({required this.item});

  final PlaybackItem item;

  @override
  ConsumerState<_LyricsPane> createState() => _LyricsPaneState();
}

/// Softens the top and bottom of the lyric viewport.
///
/// The reference lets lyrics run off the edge of the reading column instead of
/// slicing them against a hard line: the text dissolves into the artwork
/// backdrop, which is what makes the pane read as a scroll through the song
/// rather than a clipped list. The fade is one lyric line deep, so it scales
/// with the pane instead of being a fixed pixel height.
class _LyricEdgeFade extends StatelessWidget {
  const _LyricEdgeFade({required this.child});

  static const _fadeExtent = _LyricsPaneState._lyricLineExtent;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Stops are fractions of the viewport, so the band has to be resolved
        // against the real height. A very short pane would otherwise let the
        // two fades cross over each other.
        final fade = constraints.maxHeight.isFinite
            ? (_fadeExtent / constraints.maxHeight).clamp(0.0, 0.45)
            : 0.15;
        return ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const <Color>[
              Color(0x00FFFFFF),
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: <double>[0, fade, 1 - fade, 1],
          ).createShader(rect),
          // `dstIn` keeps the text's own colours and applies only the
          // gradient's alpha, which is the difference between fading the
          // lyrics out and tinting them white.
          blendMode: BlendMode.dstIn,
          child: child,
        );
      },
    );
  }
}

/// The active line's ink: the page's own background colour, darkened.
///
/// Starting from the wash rather than from a second palette colour is the point:
/// the line then reads as the same material as the page, just denser — like ink
/// on tinted paper — instead of as an unrelated swatch sitting on top of it.
/// Darkening that shared hue is what makes it legible without introducing a
/// colour the composition does not already have.
Color _lyricInk(Color background) {
  final hsl = HSLColor.fromColor(background);
  return hsl
      .withLightness((hsl.lightness * 0.42).clamp(0.0, 0.32))
      .withSaturation(hsl.saturation.clamp(0.35, 0.8).toDouble())
      .toColor();
}

/// The page colour the lyrics sit on, resolved with the backdrop's own mix.
///
/// The dominant wash stop is `primary` at 0.85 of the gradient strength, so
/// that is the colour the lyrics have to relate to. Duplicating the mix here
/// keeps the ink tied to what is actually painted behind it.
Color _washedBackground(
  ArtworkPalette palette,
  ThemeTokens tokens,
  ThemeNowPlayingLayout layout,
) {
  final base = tokens.color.backgroundBase;
  final strength = layout.artworkGradientStrength.clamp(0.0, 1.0);
  return Color.lerp(base, palette.primary, strength * 0.85) ?? base;
}

/// The active lyric line: the darkened wash colour, with a faint bloom behind it.
///
/// The glow is a blurred copy of the line laid underneath, not a `Shadow`.
/// `TextStyle.shadows` draws a shadow per glyph, so on a dense CJK line each
/// character's halo merges with its neighbours' and the result reads as a
/// rounded rectangle around the line rather than as light coming off the words.
/// Blurring the whole line at once spreads one halo around the whole shape,
/// which keeps the words' silhouette instead of boxing them.
///
/// The bloom is the ink's own colour at low alpha. Brighter or differently-hued
/// variants were tried and both failed: lifting the lightness washed it out to
/// near-white haze, and mixing in the cover's second colour added a hue the
/// composition never had.
class _GlowingLine extends StatelessWidget {
  const _GlowingLine({required this.text, required this.ink});

  final String text;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    return Stack(
      children: <Widget>[
        // One blurred pass only. Two passes at different sigmas spread the
        // glyph by two different amounts, and the resulting stack of outlines
        // read as some characters being a different size from their
        // neighbours. A single halo keeps the silhouette unambiguous.
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: style.copyWith(color: ink.withValues(alpha: 0.5)),
          ),
        ),
        // A light shadow on the ink itself thickens the edge just enough to
        // keep the dark glyph from being swallowed by its own glow.
        Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: style.copyWith(
            color: ink,
            shadows: <Shadow>[
              Shadow(color: ink.withValues(alpha: 0.55), blurRadius: 1.5),
            ],
          ),
        ),
      ],
    );
  }
}

class _LyricsPaneState extends ConsumerState<_LyricsPane> {
  static const _lyricLineExtent = 56.0;

  final _scrollController = ScrollController();
  int _lastActiveIndex = -1;
  Duration? _lastDocumentOffset;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = ref.watch(currentLyricsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final strings = ref.watch(activeThemeStringsProvider);
    final activeIndex = ref.watch(activeLyricIndexProvider);
    // The active line takes the cover's *second* colour, not the one the
    // background washes with. The page is a gradient of `primary`, so anything
    // in that hue has no boundary against it no matter how bright it is; the
    // palette's runner-up is by definition a different hue, which is what
    // keeps the line legible while still being sampled from the artwork. Falls
    // back to the skin's own activeLine when there is no cover to sample.
    final artworkUrl = widget.item.artworkUrl;
    final palette = artworkUrl == null || artworkUrl.isEmpty
        ? null
        : ref.watch(artworkPaletteProvider(artworkUrl)).value;
    final layout = ref.watch(activeThemeNowPlayingLayoutProvider);
    // Without a cover there is no wash to relate to, so the skin keeps its own
    // word on the active line's colour.
    final fallback = tokens.components.lyric.activeLine;
    final background = palette == null
        ? null
        : _washedBackground(palette, tokens, layout);
    final activeColor = background == null ? fallback : _lyricInk(background);
    // The halo is the wash's own hue at full strength, so ink and glow are the
    // same material: the darkened glyph lights up in the colour of the page
    // behind it rather than in a second colour the composition never had.
    return lyrics.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
      data: (document) {
        if (document == null || document.lines.isEmpty) {
          return Center(
            child: Text(strings.resolve(ThemeStringKey.playerLyricsEmpty)),
          );
        }
        if (document.offset != _lastDocumentOffset) {
          _lastDocumentOffset = document.offset;
          _lastActiveIndex = -1;
        }
        if (activeIndex != _lastActiveIndex && activeIndex >= 0) {
          _lastActiveIndex = activeIndex;
          _scrollActiveLineIntoView(activeIndex);
        }
        return ExcludeSemantics(
          child: ScrollConfiguration(
            behavior: const _NoScrollbarScrollBehavior(),
            child: _LyricEdgeFade(
              child: ListView.builder(
                controller: _scrollController,
                itemExtent: _lyricLineExtent,
                // Clipping stays on. `Clip.none` let the bloom out, but it also
                // let glyphs paint past the edge-fade mask, where nothing
                // dims them — half-faded lines showed up at full strength
                // outside the fade. The padding below is what gives the bloom
                // room, so the mask can keep its clip.
                itemCount: document.lines.length,
                // Horizontal breathing room: the bloom spreads sideways out of
                // the glyphs, and a line as wide as the pane has that spread
                // clipped by the viewport instead of shown.
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemBuilder: (context, index) {
                  final line = document.lines[index];
                  final active = index == activeIndex;
                  return DefaultTextStyle(
                    style: TextStyle(
                      fontSize: active
                          ? tokens.typography.resolvedSectionTitleSize
                          : tokens.typography.resolvedListPrimarySize,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active
                          ? activeColor
                          : tokens.components.lyric.inactiveLine,
                    ),
                    child: Align(
                      // Centred, not left-aligned: the bloom spreads outward
                      // from the glyphs, so a line flush against the pane's
                      // edge has half its halo clipped by that edge. Centring
                      // gives the glow room on both sides.
                      alignment: Alignment.center,
                      child: active
                          ? _GlowingLine(
                              text: line.text.isEmpty ? '...' : line.text,
                              ink: activeColor,
                            )
                          : Text(
                              line.text.isEmpty ? '...' : line.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _scrollActiveLineIntoView(int activeIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      // The active line is read at the centre of the pane. Lines near the head
      // and tail of the song cannot be centred — there is not enough material
      // above or below them — so those rest against the ends of the range.
      final position = _scrollController.position;
      final centred =
          activeIndex * _lyricLineExtent -
          (position.viewportDimension - _lyricLineExtent) / 2;
      final target = centred.clamp(0, position.maxScrollExtent).toDouble();
      if ((target - position.pixels).abs() < 0.5) {
        return;
      }
      // A `jumpTo` teleports the whole column — the sung half visibly snaps,
      // which read as the pane "shaking" every line. The reference glides the
      // new line to centre over a fraction of a second, so the same motion is
      // legible instead of jarring.
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _LyricOffsetMenuPanel extends ConsumerStatefulWidget {
  const _LyricOffsetMenuPanel({required this.item});

  final PlaybackItem item;

  @override
  ConsumerState<_LyricOffsetMenuPanel> createState() =>
      _LyricOffsetMenuPanelState();
}

class _LyricOffsetMenuPanelState extends ConsumerState<_LyricOffsetMenuPanel> {
  double _offsetMs = 0;
  Duration? _queuedOffset;
  bool _persistingOffset = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      final offset = await ref
          .read(lyricRepositoryProvider)
          .offsetForItem(widget.item.id);
      if (mounted) {
        setState(() {
          _offsetMs = offset.inMilliseconds.toDouble();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);
    // The live offset is the source of truth once the user has touched the
    // dial. The menu rebuilds while it is open — a rebuild re-runs `initState`
    // semantics for the stored value, which would drag the dial back to the
    // value it had when the menu opened. Reading the live value here means a
    // drag sticks for as long as the menu is on screen.
    final live = ref.watch(lyricLiveOffsetProvider(widget.item.id));
    final currentMs = live?.inMilliseconds.toDouble() ?? _offsetMs;
    return SizedBox(
      width: RobyneDialogWidth.forContext(context, 280),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: _OffsetDial(
              offsetMs: currentMs,
              onOffsetChanged: _applyOffset,
              tokens: tokens,
              label: strings.resolve(ThemeStringKey.playerLyricOffset),
            ),
          ),
          Text(
            strings.resolve(ThemeStringKey.playerLyricOffsetHint),
            style: TextStyle(fontSize: 11, color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  void _applyOffset(double value) {
    final offset = Duration(milliseconds: value.round());
    setState(() {
      _offsetMs = value;
    });
    ref
        .read(lyricLiveOffsetProvider(widget.item.id).notifier)
        .setOffset(offset);
    _queuedOffset = offset;
    if (!_persistingOffset) {
      unawaited(_drainOffsetWrites());
    }
  }

  Future<void> _drainOffsetWrites() async {
    _persistingOffset = true;
    try {
      while (mounted && _queuedOffset != null) {
        final offset = _queuedOffset!;
        _queuedOffset = null;
        await ref.read(lyricRepositoryProvider).setOffset(widget.item, offset);
        ref.invalidate(storedCurrentLyricsProvider);
      }
    } finally {
      _persistingOffset = false;
      if (mounted && _queuedOffset != null) {
        unawaited(_drainOffsetWrites());
      }
    }
  }
}

/// The offset control as a rotary dial.
///
/// A slider at ±50s with 0.25s precision is 400 divisions: dragging it is a
/// blur, and the fine end is unreachable with a trackpad. A dial splits the two
/// the way a physical timing knob does — one full turn is 10 seconds, so a
/// flick covers the coarse range while a slow drag (or the wheel) lands on the
/// exact quarter-second. Five turns each way is the mechanical limit, matching
/// the ±50s clamp the repository already enforces.
class _OffsetDial extends StatefulWidget {
  const _OffsetDial({
    required this.offsetMs,
    required this.onOffsetChanged,
    required this.tokens,
    required this.label,
  });

  final double offsetMs;
  final void Function(double) onOffsetChanged;
  final ThemeTokens tokens;
  final String label;

  @override
  State<_OffsetDial> createState() => _OffsetDialState();
}

class _OffsetDialState extends State<_OffsetDial> {
  static const _msPerTurn = 10000.0;
  static const _maxTurns = 5.0;
  static const _wheelStep = 250.0;
  static const _step = 250.0;
  static const _size = 132.0;

  double _lastTurn = 0;

  /// The drag's own running total, before snapping.
  ///
  /// Quantising each step instead would compound its rounding: a 36-step sweep
  /// sheds a little under a quarter-second per step, so a full turn landed
  /// noticeably short of 10s. The raw total accumulates and only the value
  /// handed out is snapped, which keeps one turn equal to 10s exactly.
  double _accumulated = 0;

  /// Pointer position as a fraction of a turn, measured from 12 o'clock.
  static double _turnAt(Offset position) =>
      math.atan2(position.dx, -position.dy) / (2 * math.pi);

  /// Snaps to the 0.25s grid the control promises.
  ///
  /// A drag reports a continuous angle, so without this the offset lands on
  /// values like 3.71s — finer than the control can show, and finer than
  /// anyone can hear. Quantising here means drag, wheel and the displayed
  /// number always agree on the same grid.
  double _quantized(double value) => (value / _step).round() * _step;

  /// Applies the snapped value, clamped to the dial's mechanical range.
  void _emit(double value) {
    widget.onOffsetChanged(
      _quantized(value).clamp(-_msPerTurn * _maxTurns, _msPerTurn * _maxTurns),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.tokens.color;
    final normalized = (widget.offsetMs / _msPerTurn).clamp(
      -_maxTurns,
      _maxTurns,
    );
    final turns = normalized.truncate();
    // 12 o'clock is zero; positive rotation sweeps clockwise.
    final angle = normalized * 2 * math.pi;
    final center = Offset(_size / 2, _size / 2);

    return SizedBox(
      width: _size,
      height: _size,
      child: Listener(
        key: const Key('lyric-offset-dial'),
        onPointerSignal: (event) {
          if (event is! PointerScrollEvent) {
            return;
          }
          // Scroll down = earlier (negative), matching the slider it replaced.
          final direction = event.scrollDelta.dy > 0 ? -1.0 : 1.0;
          _accumulated = widget.offsetMs + direction * _wheelStep;
          _emit(_accumulated);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            _lastTurn = _turnAt(details.localPosition - center);
            _accumulated = widget.offsetMs;
          },
          onPanUpdate: (details) {
            // Turns accumulate rather than being read absolutely: a full
            // revolution has to land on 10s, not wrap back to zero, so the
            // pointer's angle is integrated as a delta. Reading it absolutely
            // would make 0s and 10s the same position and silently cap the
            // control at one turn.
            final turn = _turnAt(details.localPosition - center);
            // `atan2` wraps at ±pi; a drag across 12 o'clock is a small step,
            // not a jump of a whole turn.
            var delta = turn - _lastTurn;
            if (delta > 0.5) {
              delta -= 1;
            } else if (delta < -0.5) {
              delta += 1;
            }
            _lastTurn = turn;
            _accumulated += delta * _msPerTurn;
            _emit(_accumulated);
          },
          child: CustomPaint(
            painter: _OffsetDialPainter(
              angle: angle,
              track: colors.borderDefault,
              active: colors.brandBase,
              pointer: colors.textPrimary,
              ticks: colors.textMuted,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${(widget.offsetMs / 1000).toStringAsFixed(2)}s',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  // Multi-turn wraps look identical on the face, so the turn
                  // count is the only cue that 12s is not 2s.
                  if (turns != 0)
                    Text(
                      '${turns > 0 ? '+' : ''}$turns×',
                      style: TextStyle(fontSize: 9, color: colors.textMuted),
                    ),
                  Text(
                    widget.label,
                    style: TextStyle(fontSize: 10, color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OffsetDialPainter extends CustomPainter {
  const _OffsetDialPainter({
    required this.angle,
    required this.track,
    required this.active,
    required this.pointer,
    required this.ticks,
  });

  final double angle;
  final Color track;
  final Color active;
  final Color pointer;
  final Color ticks;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    // The traversed arc starts at 12 o'clock and sweeps to the pointer, so the
    // dial reads like a clock hand counting turns.
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = active;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      angle,
      false,
      activePaint,
    );

    // Four quadrant ticks give the eye an anchor for "where am I in the turn"
    // without reading the number.
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = ticks;
    for (var i = 0; i < 12; i++) {
      final tickAngle = i * math.pi / 6 - math.pi / 2;
      final outer = Offset(
        center.dx + math.cos(tickAngle) * radius,
        center.dy + math.sin(tickAngle) * radius,
      );
      final inner = Offset(
        center.dx + math.cos(tickAngle) * (radius - 5),
        center.dy + math.sin(tickAngle) * (radius - 5),
      );
      canvas.drawLine(outer, inner, tickPaint);
    }

    final pointerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = pointer;
    canvas.drawLine(
      center + Offset(math.sin(angle), -math.cos(angle)) * 14,
      center + Offset(math.sin(angle), -math.cos(angle)) * (radius - 8),
      pointerPaint,
    );
  }

  @override
  bool shouldRepaint(_OffsetDialPainter old) =>
      old.angle != angle ||
      old.track != track ||
      old.active != active ||
      old.pointer != pointer;
}

class _LyricSearchDialog extends ConsumerStatefulWidget {
  const _LyricSearchDialog({required this.item});

  final PlaybackItem item;

  @override
  ConsumerState<_LyricSearchDialog> createState() => _LyricSearchDialogState();
}

class _LyricSearchDialogState extends ConsumerState<_LyricSearchDialog> {
  late final TextEditingController _controller;
  bool _autoSearched = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.title);
    attachImeTextControllerTrace(_controller, 'lyrics.searchKeyword');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plugins =
        ref.watch(pluginControllerProvider).value ?? const <PluginDefinition>[];
    if (!_autoSearched && plugins.isNotEmpty) {
      _autoSearched = true;
      Future<void>.microtask(() {
        ref
            .read(lyricSearchControllerProvider.notifier)
            .search(_controller.text, plugins);
      });
    }
    final state =
        ref.watch(lyricSearchControllerProvider).value ??
        const LyricSearchState();
    final selected = state.selectedPluginResult;
    final strings = ref.watch(activeThemeStringsProvider);
    // The dialog opens over the cover-derived player, so its accent comes from
    // the same artwork the page does. A flat skin swatch here read as a
    // different, unrelated purple next to everything else on screen.
    final artworkUrl = widget.item.artworkUrl;
    final palette = artworkUrl == null || artworkUrl.isEmpty
        ? null
        : ref.watch(artworkPaletteProvider(artworkUrl)).value;

    return AlertDialog(
      title: Text(strings.resolve(ThemeStringKey.playerSearchLyricsTitle)),
      content: SizedBox(
        width: RobyneDialogWidth.forContext(context, 720),
        height: RobyneDialogWidth.heightForContext(context, 520),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      if (state.isSearching) {
                        return;
                      }
                      unawaited(
                        ref
                            .read(lyricSearchControllerProvider.notifier)
                            .search(_controller.text, plugins),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SearchActionButton(
                  isSearching: state.isSearching,
                  searchLabelKey: ThemeStringKey.playerSearchLyricAction,
                  stopLabelKey: ThemeStringKey.playerSearchLyricStop,
                  accentColor: palette?.primary,
                  accentInkColor: palette?.onColor,
                  onSearch: () => unawaited(
                    ref
                        .read(lyricSearchControllerProvider.notifier)
                        .search(_controller.text, plugins),
                  ),
                  onCancel: () =>
                      ref.read(lyricSearchControllerProvider.notifier).cancel(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: HorizontalWheelScroll(
                builder: (context, controller) => ListView.separated(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  itemCount: state.pluginResults.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final result = state.pluginResults[index];
                    return ChoiceChip(
                      selected: result.pluginId == selected?.pluginId,
                      label: Text(
                        result.isSearching
                            ? '${result.platform} ...'
                            : result.error != null
                            ? '${result.platform} !'
                            : '${result.platform} ${result.items.length}',
                      ),
                      onSelected: (_) => ref
                          .read(lyricSearchControllerProvider.notifier)
                          .selectPlugin(result.pluginId),
                    );
                  },
                ),
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: selected == null
                  ? Center(
                      child: Text(
                        strings.resolve(ThemeStringKey.playerLyricPluginsEmpty),
                      ),
                    )
                  : selected.isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : selected.error != null && selected.items.isEmpty
                  ? Center(
                      child: Text(
                        '${selected.error!.code}: ${selected.error!.message}',
                        style: TextStyle(
                          color: RobyneTheme.of(context).tokens.color.danger,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: selected.items.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final candidate = selected.items[index];
                        return ListTile(
                          title: Text(candidate.title),
                          subtitle: Text(
                            <String?>[
                                  candidate.artist,
                                  candidate.album,
                                  candidate.platform,
                                ]
                                .whereType<String>()
                                .where((value) => value.isNotEmpty)
                                .join(' - '),
                          ),
                          onTap: () async {
                            final error = await ref
                                .read(lyricSearchControllerProvider.notifier)
                                .associateCandidate(
                                  item: widget.item,
                                  candidate: candidate,
                                  plugins: plugins,
                                );
                            if (error == null && context.mounted) {
                              Navigator.of(context).pop();
                            } else if (error != null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${error.code}: ${error.message}',
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
