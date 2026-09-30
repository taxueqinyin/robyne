import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../../../app/main_window_state.dart';
import 'capsule_window_state.dart';

/// Geometry of the collapsed "capsule" mini layout.
///
/// The shell sizes the OS window from these numbers, and the bar composes
/// itself from the same constants, so the window and its content cannot drift
/// apart the way they did when the shell still filled a full-screen Scaffold.
abstract final class CapsuleWindow {
  /// Width of the capsule bar itself.
  ///
  /// Wide enough for the cover, a full song title and artist, and the five
  /// hover controls plus the close button inside the surface. Narrower bars
  /// truncated the title before it filled the available space.
  static const double barWidth = 380;

  /// Height of the capsule bar's rounded surface.
  static const double barHeight = 56;

  /// Diameter of the circular artwork. It is intentionally taller than the
  /// bar so it protrudes above and below the surface.
  static const double artworkSize = 68;

  /// How far the artwork rises above the bar's top edge.
  ///
  /// The circle no longer reaches the bar's bottom edge — it keeps
  /// [artworkBottomClearance] clear of it — so the protrusion is the leftover
  /// height plus that clearance.
  static const double artworkProtrusion =
      artworkSize - barHeight + artworkBottomClearance;

  /// Distance between the artwork's left edge and the bar's left edge.
  ///
  /// The cover used to be jammed against the left edge; pushed further in so
  /// it sits inside the pill rather than hanging off its corner.
  static const double artworkInset = 16;

  /// Space between the artwork and the info/control area.
  ///
  /// The previous 6dp read as a chasm next to the title; the cover sits close
  /// enough to the text now that the two read as one block.
  static const double artworkGap = 10;

  /// Clearance between the artwork's bottom edge and the bar's bottom edge.
  ///
  /// The circle is nudged up off the bar's baseline so it reads as hovering
  /// inside the pill's left end instead of being clipped by its lower edge.
  static const double artworkBottomClearance = 4;

  /// Trailing padding inside the bar.
  static const double barPaddingTrailing = 12;

  /// Diameter of the close button. It sits *inside* the bar's trailing edge,
  /// not floating outside it, so the window has no chrome the pointer has to
  /// leave the surface to reach.
  static const double closeButtonSize = 26;

  /// Gap between the close button and the bar's trailing edge.
  static const double closeButtonGap = 6;

  /// Width of the area that swaps between song info and transport controls.
  ///
  /// Derived from the other constants so widening the bar always widens this
  /// area: a literal here silently stopped tracking [barWidth], which is how
  /// the title ended up with less room than the bar actually had.
  ///
  /// Both states occupy the same box so hovering never resizes the bar.
  static const double middleWidth =
      barWidth -
      artworkInset -
      artworkSize -
      artworkGap -
      closeButtonSize -
      closeButtonGap -
      barPaddingTrailing;

  /// Size of the like / skip / queue buttons; play is slightly larger.
  static const double sideButtonSize = 34;
  static const double playButtonSize = 40;

  /// Height of the playlist panel the trailing button unfolds.
  static const double panelHeight = 300;

  /// Gap between the panel and the bar.
  ///
  /// Zero: the panel butts straight against the bar's bottom edge. The cover
  /// now protrudes upward only, which is what frees the space below the bar
  /// for the panel to meet it without overlapping the artwork.
  static const double panelGap = 0;

  /// Outer margins the shell leaves around the capsule content.
  static const double windowMarginHorizontal = 8;
  static const double windowMarginVertical = 8;

  /// Vertical offset of the bar inside the capsule's stack: the headroom the
  /// artwork needs to protrude above the surface.
  static const double barTop = artworkProtrusion;

  /// Vertical offset of the artwork.
  ///
  /// Flush with the top of the stack. Its bottom therefore sits
  /// [artworkBottomClearance] above the bar's bottom edge, leaving the gap
  /// the cover was asked for.
  static const double artworkTop = 0;

  /// Total height of the capsule's stack.
  ///
  /// The taller of the bar's extent and the artwork's, so a future change to
  /// either constant cannot silently crop the circle.
  static const double stackHeight =
      (barTop + barHeight) > (artworkTop + artworkSize)
      ? barTop + barHeight
      : artworkTop + artworkSize;

  /// OS window width in capsule mode.
  static double get windowWidth =>
      barWidth + windowMarginHorizontal * 2;

  /// OS window height in capsule mode, with or without the playlist open.
  static double windowHeight({required bool playlistOpen}) =>
      windowMarginVertical * 2 +
      stackHeight +
      (playlistOpen ? panelGap + panelHeight : 0);
}

/// Whether this process may resize the main window.
///
/// `window_manager` only works on the desktop main window; widget tests run
/// without the plugin and must never depend on OS state.
bool get canControlCapsuleWindow {
  if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
    return false;
  }
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}

/// Where the capsule was last seen, in memory only.
///
/// Dragging the capsule fires no "drag finished" event, so the capsule's spot
/// has to be sampled while it is open. The persisted copy is what the *next*
/// launch reads; this is what the current session uses, so that collapsing,
/// restoring and collapsing again returns to the capsule's home instead of
/// reopening wherever the shell happened to be standing.
Offset? _capsulePosition;

/// Whether the capsule has already been moved to its remembered spot since
/// the last collapse.
///
/// Only the entry resize may place the window. A later playlist toggle is a
/// height change, not a relocation, so it must not undo wherever the user has
/// dragged the capsule to in the meantime.
bool _capsulePlaced = false;

/// How often the capsule's spot is sampled while it is open.
///
/// Window drags finish without a reliable Dart callback on Windows, so the
/// position is polled rather than observed. Two seconds matches the shell's
/// own geometry reconciliation cadence.
const Duration _capsuleSampleInterval = Duration(seconds: 2);

/// Timer behind [sampleCapsulePosition]; null while the shell is expanded.
Timer? _capsuleSampleTimer;

/// Starts sampling the capsule's spot so a drag is remembered even if the app
/// is then closed without ever restoring the shell.
///
/// [restoreFullShellWindow] also saves the position, so the timer exists for
/// the paths that never reach it — closing the app while collapsed, or a
/// crash. Sampling is memory-only; the write happens on the way out.
void startCapsulePositionSampling() {
  if (!canControlCapsuleWindow || _capsuleSampleTimer != null) {
    return;
  }
  _capsuleSampleTimer = Timer.periodic(_capsuleSampleInterval, (_) {
    unawaited(sampleCapsulePosition());
  });
}

/// Stops sampling and flushes the capsule's last known spot to storage.
void stopCapsulePositionSampling() {
  _capsuleSampleTimer?.cancel();
  _capsuleSampleTimer = null;
}

/// Remembers where the capsule is standing, so the next collapse reopens in
/// the same spot.
///
/// Separated from [restoreFullShellWindow] because leaving the app while
/// collapsed needs the position saved but no shell to restore into.
Future<void> rememberCapsulePosition() async {
  if (!canControlCapsuleWindow) {
    return;
  }
  try {
    final bounds = await windowManager.getBounds();
    if (bounds.width > 0 && bounds.height > 0) {
      _capsulePosition = bounds.topLeft;
      await CapsuleWindowStateStore().save(
        CapsuleWindowState(position: bounds.topLeft),
      );
    }
  } catch (_) {
    // Position memory is best-effort.
  }
}

/// Samples the capsule's spot for the current session only.
///
/// Called on a timer while the capsule is open, because a drag produces no
/// completion callback to hook. Persisting on every tick would hammer shared
/// preferences for a value nobody reads until the next launch, so this keeps
/// it in memory and [rememberCapsulePosition] writes it out on the way out.
Future<void> sampleCapsulePosition() async {
  if (!canControlCapsuleWindow) {
    return;
  }
  try {
    final bounds = await windowManager.getBounds();
    if (bounds.width > 0 && bounds.height > 0) {
      _capsulePosition = bounds.topLeft;
    }
  } catch (_) {
    // Sampling is best-effort.
  }
}

/// The shell's window bounds the last time the capsule was entered.
///
/// Both the size *and* the position matter. `setSize` anchors the top-left
/// corner, so restoring only the size left the window wherever the user had
/// dragged the capsule to — the shell then "unfolded" down and to the right
/// of that point instead of going back where it came from.
///
/// `MainWindowStateStore` cannot be trusted here either: the geometry watcher
/// keeps reconciling while the capsule is open, so the small capsule bounds
/// get persisted as the shell's normal geometry.
Rect? _restoredBounds;

/// Remembers the shell's current window bounds before it collapses.
Future<void> captureFullShellWindowSize() async {
  if (!canControlCapsuleWindow) {
    return;
  }
  try {
    if (await windowManager.isMaximized()) {
      _restoredBounds = null;
      return;
    }
    final bounds = await windowManager.getBounds();
    if (bounds.width > 0 && bounds.height > 0) {
      _restoredBounds = bounds;
    }
  } catch (_) {
    _restoredBounds = null;
  }
}

/// Makes the capsule's window see-through so the desktop shows through it.
///
/// The capsule is an irregular shape — a pill with a cover jutting out of it —
/// so it cannot sit on an opaque rectangle without the rectangle's corners
/// showing as a black box around the bar.
///
/// The shell launches frameless-adjacent (`TitleBarStyle.hidden`), which still
/// paints a background; transparency only takes effect once the window is
/// genuinely frameless, so the capsule toggles that and puts it back on exit.
Future<void> setCapsuleWindowTransparent({required bool transparent}) async {
  if (!canControlCapsuleWindow) {
    return;
  }
  try {
    if (transparent) {
      await windowManager.setAsFrameless();
      await windowManager.setBackgroundColor(Colors.transparent);
    } else {
      // `setAsFrameless` has no inverse in `window_manager`: the plugin's
      // `is_frameless_` latch is cleared only by `setTitleBarStyle`, and it is
      // consulted by later calls that care about the frame (`HasShadow`,
      // fullscreen restore). Leaving it set kept the window flagged frameless
      // for the rest of the session.
      //
      // Restore the *same* style the shell launched with — `normal` would put
      // the OS title bar back next to the one the app already draws. This is
      // also the plugin's documented way to undo `setAsFrameless`.
      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
      await windowManager.setBackgroundColor(const Color(0xFF000000));
    }
  } catch (_) {
    // Transparency is cosmetic; a failure must not break the layout.
  }
}

/// Grows or shrinks the main window to the capsule's size.
///
/// The shell launches with a 400×360 minimum for the full layout; the capsule
/// is smaller by design, so the minimum is relaxed before resizing. `setSize`
/// anchors the top-left corner, which keeps the capsule where the user left it.
///
/// Toggling the playlist deliberately leaves the origin alone. The bar is the
/// top-aligned first child of the capsule's column, so a top-left-anchored
/// resize grows the panel *downward* out of a bar that has not moved — which
/// is the whole point. Re-running the remembered-spot lookup on every toggle
/// also fought the user's drag, snapping the capsule back to its stored home
/// the moment they opened the playlist somewhere else.
Future<void> applyCapsuleWindowSize({required bool playlistOpen}) async {
  if (!canControlCapsuleWindow) {
    return;
  }
  // One collapse at a time: an in-flight entry whose `setSize` has not landed
  // yet would otherwise be overtaken by a later one, leaving the window at a
  // size from the superseded call.
  if (_applying) {
    return;
  }
  _applying = true;
  try {
    await windowManager.setMinimumSize(const Size(0, 0));
    await setCapsuleWindowTransparent(transparent: true);
    // The capsule is a few hundred pixels on a desktop full of windows;
    // without this, clicking any other app hides it and it stops being a
    // mini player. The tray panel and the desktop lyric already pin
    // themselves for the same reason.
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSize(
      Size(
        CapsuleWindow.windowWidth,
        CapsuleWindow.windowHeight(playlistOpen: playlistOpen),
      ),
    );
    // Only the *entry* resize places the window, because `setSize` has just
    // anchored it at the shell's corner. Every later call is a playlist-driven
    // height change, and re-running the lookup there would undo whichever spot
    // the user dragged the capsule to.
    if (!_capsulePlaced) {
      _capsulePlaced = true;
      await _moveCapsuleToRememberedSpot(playlistOpen: playlistOpen);
    }
  } catch (_) {
    // A missing window binding must never take playback down with it.
  } finally {
    _applying = false;
  }
}

/// Whether [applyCapsuleWindowSize] owns the window right now.
bool _applying = false;

/// Places the capsule at its remembered position, inside the work area.
Future<void> _moveCapsuleToRememberedSpot({
  required bool playlistOpen,
}) async {
  // The live session's memory wins over the persisted one. Writing the
  // capsule's spot only on exit meant collapsing a second time in the same
  // session reopened at the shell's corner, because by then the persisted
  // value had been overwritten with the shell's own position.
  var position = _capsulePosition;
  if (position == null) {
    final saved = await CapsuleWindowStateStore().load();
    position = saved?.position;
  }
  if (position == null) {
    return;
  }
  final bounds = await windowManager.getBounds();
  final workArea = await _displayWorkAreaFor(bounds.topLeft);
  await windowManager.setPosition(
    capsuleBoundsAt(
      position: position,
      workArea: workArea,
      playlistOpen: playlistOpen,
    ).topLeft,
  );
}

/// The display work area containing [point], or the window's own bounds when
/// the display binding is unavailable.
Future<Rect> _displayWorkAreaFor(Offset point) async {
  try {
    final displays = await screenRetriever.getAllDisplays();
    for (final display in displays) {
      final area = _workAreaOf(display);
      if (area.contains(point)) {
        return area;
      }
    }
    final primary = _workAreaOf(await screenRetriever.getPrimaryDisplay());
    if (primary.width > 0 && primary.height > 0) {
      return primary;
    }
  } catch (_) {
    // Fall through to the window bounds below.
  }
  return await windowManager.getBounds();
}

/// The display's usable area, excluding system chrome such as the taskbar.
Rect _workAreaOf(Display display) {
  final position = display.visiblePosition ?? Offset.zero;
  final size = display.visibleSize ?? display.size;
  return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
}

/// Restores the shell's normal minimum, size and *position*.
///
/// Prefers the bounds captured on entry over the persisted state, because the
/// persisted state has usually been overwritten with the capsule's own bounds
/// by the time we get here. Restoring the position is what puts the window
/// back where the shell was, rather than wherever the capsule got dragged to.
///
/// Every step here is either a posture change or a single `setBounds`, and the
/// order is load-bearing so the window moves exactly once — see the comment
/// on the call below for why the minimum is restored only afterwards.
Future<void> restoreFullShellWindow() async {
  if (!canControlCapsuleWindow) {
    return;
  }
  // One active restore at a time. The capsule can be left from several paths
  // at once (its close button, the tray's "show", a second toggle), and two
  // concurrent restores meant two sequences of `setBounds` racing over the
  // same window: each read the bounds the other had just written, so the
  // shell settled somewhere neither of them asked for.
  if (_restoring) {
    return;
  }
  _restoring = true;
  try {
    // Remember where the capsule was standing *before* the window changes
    // shape, so the next collapse reopens in the same spot.
    final capsuleBounds = await windowManager.getBounds();
    if (capsuleBounds.width > 0 && capsuleBounds.height > 0) {
      _capsulePosition = capsuleBounds.topLeft;
      await CapsuleWindowStateStore().save(
        CapsuleWindowState(position: capsuleBounds.topLeft),
      );
    }
    stopCapsulePositionSampling();
    // The next collapse is a fresh placement, not a continuation.
    _capsulePlaced = false;

    final captured = _restoredBounds;
    _restoredBounds = null;
    final saved = await MainWindowStateStore().load();
    // A capsule-sized entry in the persisted state is contamination, not a
    // preference: the geometry watcher writes on a timer, so a save already
    // in flight when the capsule opened can land after `suspend()`. Such an
    // entry must be discarded rather than clamped up to the minimum, or
    // "close" restores a phone-sized window.
    final target = resolveShellRestoreBounds(
      captured: captured,
      savedSize: saved?.size,
      savedPosition: saved?.position,
    );
    final offset = target.hadRealOrigin
        ? Offset.zero
        : await _screenCenter(target.bounds.size);
    final bounds = target.bounds.shift(offset);
    // Order is what removes the stutter. Restoring the minimum *first* would
    // make Windows immediately grow the still-capsule-sized window up to that
    // minimum, and `setBounds` would then move it again to the real target —
    // two visible jumps per restore. Going straight to the target while the
    // relaxed (0,0) minimum is still in force means exactly one resize; the
    // minimum is reinstated afterwards, when it no longer describes a
    // constraint the current size violates.
    await setCapsuleWindowTransparent(transparent: false);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setBounds(bounds);
    await windowManager.setMinimumSize(MainWindowState.minimumSize);
  } catch (_) {
    try {
      await windowManager.setMinimumSize(MainWindowState.minimumSize);
    } catch (_) {}
  } finally {
    _restoring = false;
  }
}

/// Whether [restoreFullShellWindow] owns the window right now.
bool _restoring = false;

/// The bounds the shell returns to when the capsule closes.
///
/// Preference order: the bounds captured on entry, then the persisted
/// geometry, then the documented default. Each candidate is rejected outright
/// if it is smaller than the shell's minimum, because that size can only have
/// come from the capsule.
///
/// The rect's origin is `null`-free by necessity — `setBounds` needs both
/// halves — so [hadRealOrigin] reports whether the origin is a remembered
/// position or a placeholder that must be replaced by a centring offset.
///
/// Visible for testing: the contamination case is the regression that made
/// "close" restore a phone-sized window, and it cannot be reproduced without
/// a real OS window.
@visibleForTesting
({Rect bounds, bool hadRealOrigin}) resolveShellRestoreBounds({
  Rect? captured,
  Size? savedSize,
  Offset? savedPosition,
}) {
  bool usable(Size size) =>
      size.width >= MainWindowState.minimumSize.width &&
      size.height >= MainWindowState.minimumSize.height;

  if (captured != null && usable(captured.size)) {
    return (bounds: captured, hadRealOrigin: true);
  }
  if (savedSize != null &&
      usable(savedSize) &&
      savedPosition != null &&
      savedPosition.isFinite) {
    return (bounds: savedPosition & savedSize, hadRealOrigin: true);
  }
  return (
    bounds: Rect.fromLTWH(
      0,
      0,
      MainWindowState.defaultSize.width,
      MainWindowState.defaultSize.height,
    ),
    hadRealOrigin: false,
  );
}

/// Centre offset for [size] on the primary display, used when neither the
/// captured nor the persisted bounds carry a position.
///
/// Returns the *top-left* a rect of [size] must be shifted by to sit centred
/// on the display — not the centre point itself, which would park the
/// window's corner in the middle of the screen.
Future<Offset> _screenCenter(Size size) async {
  try {
    final bounds = await windowManager.getBounds();
    if (bounds.width > 0 && bounds.height > 0) {
      return bounds.center - Offset(size.width / 2, size.height / 2);
    }
  } catch (_) {
    // Fall through to a plain origin-centred rect.
  }
  return Offset.zero;
}
