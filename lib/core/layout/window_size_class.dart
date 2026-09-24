import 'package:flutter/widgets.dart';

/// Material 3 window size classes, evaluated on **both** axes.
///
/// The width axis alone cannot describe a phone in landscape: an 800x360
/// window is a medium-width but compact-height surface, and treating it as
/// a desktop layout is what made covered content unreachable on Android.
///
/// See `docs/ADR-001-responsive-window-size-class.md`.
enum WindowWidthClass {
  /// < 600dp: phones in portrait, split-screen panes.
  compact,

  /// 600–839dp: tablets in portrait, phones in landscape, small desktop
  /// windows.
  medium,

  /// >= 840dp: tablets in landscape, most desktop windows.
  expanded,
}

/// Height classes follow the same three-step shape with P3 thresholds, since
/// the vertical budget has different headroom than the horizontal one.
enum WindowHeightClass {
  /// < 480dp: landscape phone. Chrome must collapse or the content cannot
  /// breathe.
  compact,

  /// 480–899dp: portrait phone, most laptop windows.
  medium,

  /// >= 900dp: desktop displays.
  expanded,
}

/// The resolved size class of the nearest usable viewport.
///
/// Read it instead of comparing `MediaQuery.sizeOf(context).width` against a
/// literal: every breakdown listed in the ADR comes from call sites each
/// inventing their own threshold.
class WindowSizeClass {
  const WindowSizeClass._({
    required this.width,
    required this.height,
    required this.size,
  });

  /// Material 3 width breakpoint between compact and medium.
  static const double compactWidthBreakpoint = 600;

  /// Material 3 width breakpoint between medium and expanded.
  static const double expandedWidthBreakpoint = 840;

  /// Material 3 height breakpoint between compact and medium.
  static const double compactHeightBreakpoint = 480;

  /// Material 3 height breakpoint between medium and expanded.
  static const double expandedHeightBreakpoint = 900;

  final WindowWidthClass width;
  final WindowHeightClass height;

  /// Raw logical pixel size the classes were derived from.
  final Size size;

  /// Resolves the class for the viewport [context] sits in.
  ///
  /// Falls back to the `MediaQuery` view when one is present; otherwise the
  /// physical window size is used. In widget tests either is injectable
  /// through `WidgetTester.view`.
  static WindowSizeClass of(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final size =
        mediaQuery?.size ??
        View.of(context).physicalSize / View.of(context).devicePixelRatio;
    return WindowSizeClass.fromSize(size);
  }

  /// Pure derivation, so the mapping stays unit-testable without a widget.
  static WindowSizeClass fromSize(Size size) {
    return WindowSizeClass._(
      width: _widthClass(size.width),
      height: _heightClass(size.height),
      size: size,
    );
  }

  static WindowWidthClass _widthClass(double width) {
    if (width < compactWidthBreakpoint) {
      return WindowWidthClass.compact;
    }
    if (width < expandedWidthBreakpoint) {
      return WindowWidthClass.medium;
    }
    return WindowWidthClass.expanded;
  }

  static WindowHeightClass _heightClass(double height) {
    if (height < compactHeightBreakpoint) {
      return WindowHeightClass.compact;
    }
    if (height < expandedHeightBreakpoint) {
      return WindowHeightClass.medium;
    }
    return WindowHeightClass.expanded;
  }

  /// True when the horizontal budget rules out a persistent side rail.
  bool get isCompactWidth => width == WindowWidthClass.compact;

  /// True when the vertical budget cannot absorb full-height chrome.
  ///
  /// A landscape phone lands here while reporting a medium width, which is
  /// exactly the combination that used to borrow the desktop shell.
  bool get isCompactHeight => height == WindowHeightClass.compact;

  /// Clamps a skin- or call-site-declared extent into the viewport.
  ///
  /// Absolute dimensions are how a desktop-tuned value silently eats a phone
  /// screen: `340` cover art inside a `336dp` column overflows by 4dp and
  /// pushes the lyrics pane off. Every fixed extent must pass through here.
  double clampDimension(double value, {required double maxRatio}) {
    final limit = size.shortestSide * maxRatio;
    return value < limit ? value : limit;
  }
}

/// Width available to a modal after the Material dialog gutters.
///
/// `AlertDialog` itself already caps itself; the overflow this guards against
/// comes from children declaring widths wider than the dialog, which then
/// propagate outward. See ADR-001 decision D4.
abstract final class RobyneDialogWidth {
  /// Largest width a dialog should ever ask for.
  static const double maxDialogWidth = 560;

  /// Resolves a safe content width for a dialog inside [context].
  ///
  /// [preferred] is the width the content "wants"; the result is never wider
  /// than the viewport minus margin, nor larger than [maxDialogWidth].
  static double forContext(BuildContext context, double preferred) {
    final size = MediaQuery.maybeOf(context)?.size ?? _viewSize(context);
    // AlertDialog insets itself by 40dp total (20 each side) and the surface
    // needs a little air on extremely narrow displays.
    const gutter = 68.0;
    final available = size.width - gutter;
    var resolved = preferred;
    if (resolved > available) {
      resolved = available;
    }
    if (resolved > maxDialogWidth) {
      resolved = maxDialogWidth;
    }
    return resolved < 0 ? 0 : resolved;
  }

  /// Height budget for a dialog that also declares one.
  static double heightForContext(BuildContext context, double preferred) {
    final size = MediaQuery.maybeOf(context)?.size ?? _viewSize(context);
    // The dialog keeps a frame around the content and the keyboard may take
    // the lower half, so cap at 80% rather than the full height.
    final available = size.height * 0.8;
    return preferred < available ? preferred : available;
  }

  static Size _viewSize(BuildContext context) {
    final view = View.of(context);
    return view.physicalSize / view.devicePixelRatio;
  }
}
