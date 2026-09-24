import 'dart:ui';

/// Component-level tokens: the surfaces that give a skin its identity.
///
/// Semantic tokens (`ThemeTokens`) describe *what a role means* — "brand
/// colour", "text primary". They deliberately stop there so a skin can never
/// break the UI. But a music player's recognisable look lives in specific
/// surfaces: the navigation gradient, the active lyric line, the hover state
/// of a card. Those have no home in the semantic layer, so without this file
/// they end up hard-coded in widgets and every skin looks the same.
///
/// Adding a token here is the supported way to make a new surface skinnable.
/// Every value still has a baseline, so a skin that omits them all renders
/// exactly as before.
class ThemeComponents {
  const ThemeComponents({
    required this.navBar,
    required this.playerBar,
    required this.lyric,
    required this.card,
    required this.list,
    required this.motion,
  });

  /// Baseline matching the pre-existing look, so skins that omit every
  /// component token are unaffected.
  const ThemeComponents.baseline()
    : navBar = const ThemeNavBarComponents.baseline(),
      playerBar = const ThemePlayerBarComponents.baseline(),
      lyric = const ThemeLyricComponents.baseline(),
      card = const ThemeCardComponents.baseline(),
      list = const ThemeListComponents.baseline(),
      motion = const ThemeMotionComponents.baseline();

  final ThemeNavBarComponents navBar;
  final ThemePlayerBarComponents playerBar;
  final ThemeLyricComponents lyric;
  final ThemeCardComponents card;
  final ThemeListComponents list;
  final ThemeMotionComponents motion;

  ThemeComponents copyWith({
    ThemeNavBarComponents? navBar,
    ThemePlayerBarComponents? playerBar,
    ThemeLyricComponents? lyric,
    ThemeCardComponents? card,
    ThemeListComponents? list,
    ThemeMotionComponents? motion,
  }) {
    return ThemeComponents(
      navBar: navBar ?? this.navBar,
      playerBar: playerBar ?? this.playerBar,
      lyric: lyric ?? this.lyric,
      card: card ?? this.card,
      list: list ?? this.list,
      motion: motion ?? this.motion,
    );
  }

  static ThemeComponents lerp(ThemeComponents a, ThemeComponents b, double t) {
    return ThemeComponents(
      navBar: ThemeNavBarComponents.lerp(a.navBar, b.navBar, t),
      playerBar: ThemePlayerBarComponents.lerp(a.playerBar, b.playerBar, t),
      lyric: ThemeLyricComponents.lerp(a.lyric, b.lyric, t),
      card: ThemeCardComponents.lerp(a.card, b.card, t),
      list: ThemeListComponents.lerp(a.list, b.list, t),
      motion: t < 0.5 ? a.motion : b.motion,
    );
  }
}

/// A multi-stop gradient, or a flat colour when a skin prefers one.
///
/// Gradients are how most music players establish their brand; a pure-colour
/// token cannot express them. A skin may supply either a single `color` or a
/// list of `stops`, and both render correctly.
class ThemeGradient {
  const ThemeGradient({required this.stops});

  /// A single-colour gradient (renders flat).
  ///
  /// Not `const`: the colour comes from the skin at runtime.
  ThemeGradient.solid(Color color)
    : stops = <ThemeGradientStop>[ThemeGradientStop(color: color, offset: 0)];

  /// No gradient at all: the surface falls back to its semantic colour.
  static const ThemeGradient none = ThemeGradient(stops: <ThemeGradientStop>[]);

  final List<ThemeGradientStop> stops;

  bool get isEmpty => stops.isEmpty;

  /// A single solid colour, for surfaces that cannot paint a gradient.
  Color? get solidColor {
    if (stops.isEmpty) {
      return null;
    }
    final first = stops.first.color;
    for (final stop in stops) {
      if (stop.color != first) {
        return null;
      }
    }
    return first;
  }

  static ThemeGradient? lerp(ThemeGradient? a, ThemeGradient? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    final from = a ?? ThemeGradient.none;
    final to = b ?? ThemeGradient.none;
    if (from.isEmpty || to.isEmpty) {
      return t < 0.5 ? from : to;
    }
    // Cross-fade the shorter list against the longer one so switching skins
    // never produces a null gradient mid-animation.
    final count = from.stops.length > to.stops.length
        ? from.stops.length
        : to.stops.length;
    final stops = <ThemeGradientStop>[];
    for (var index = 0; index < count; index += 1) {
      final left = from.stops[index % from.stops.length];
      final right = to.stops[index % to.stops.length];
      stops.add(ThemeGradientStop.lerp(left, right, t));
    }
    return ThemeGradient(stops: stops);
  }
}

/// Sentinel distinguishing "field absent" from "field explicitly null".
const Object _sentinel = Object();

/// One colour stop in a [ThemeGradient].
class ThemeGradientStop {
  const ThemeGradientStop({required this.color, required this.offset});

  final Color color;

  /// Normalised position, 0..1. Values outside the range are clamped by the
  /// parser, since Skia rejects them and the whole frame would be lost.
  final double offset;

  static ThemeGradientStop lerp(
    ThemeGradientStop a,
    ThemeGradientStop b,
    double t,
  ) {
    return ThemeGradientStop(
      color: Color.lerp(a.color, b.color, t) ?? a.color,
      offset: (a.offset + (b.offset - a.offset) * t).clamp(0.0, 1.0),
    );
  }
}

/// Primary navigation surface.
class ThemeNavBarComponents {
  const ThemeNavBarComponents({
    required this.background,
    required this.gradient,
    required this.selectedItem,
    required this.selectedIndicator,
  });

  const ThemeNavBarComponents.baseline()
    : background = const Color(0x00000000),
      gradient = ThemeGradient.none,
      selectedItem = const Color(0xFF2F6FED),
      selectedIndicator = const Color(0x1F2F6FED);

  /// Fully transparent means "use the semantic background token".
  final Color background;

  /// Painted over [background] when non-empty — the QQ-music-style look.
  final ThemeGradient gradient;

  final Color selectedItem;
  final Color selectedIndicator;

  ThemeNavBarComponents copyWith({
    Color? background,
    Object? gradient = _sentinel,
    Color? selectedItem,
    Color? selectedIndicator,
  }) {
    return ThemeNavBarComponents(
      background: background ?? this.background,
      gradient: identical(gradient, _sentinel)
          ? this.gradient
          : (gradient as ThemeGradient?) ?? ThemeGradient.none,
      selectedItem: selectedItem ?? this.selectedItem,
      selectedIndicator: selectedIndicator ?? this.selectedIndicator,
    );
  }

  static ThemeNavBarComponents lerp(
    ThemeNavBarComponents a,
    ThemeNavBarComponents b,
    double t,
  ) {
    return ThemeNavBarComponents(
      background: Color.lerp(a.background, b.background, t) ?? a.background,
      gradient: ThemeGradient.lerp(a.gradient, b.gradient, t) ?? a.gradient,
      selectedItem:
          Color.lerp(a.selectedItem, b.selectedItem, t) ?? a.selectedItem,
      selectedIndicator:
          Color.lerp(a.selectedIndicator, b.selectedIndicator, t) ??
          a.selectedIndicator,
    );
  }
}

/// Playback transport surface.
class ThemePlayerBarComponents {
  const ThemePlayerBarComponents({
    required this.background,
    required this.gradient,
    required this.progressTrack,
    required this.progressActive,
  });

  const ThemePlayerBarComponents.baseline()
    : background = const Color(0x00000000),
      gradient = ThemeGradient.none,
      progressTrack = const Color(0x1A000000),
      progressActive = const Color(0xFF2F6FED);

  final Color background;
  final ThemeGradient gradient;
  final Color progressTrack;
  final Color progressActive;

  ThemePlayerBarComponents copyWith({
    Color? background,
    Object? gradient = _sentinel,
    Color? progressTrack,
    Color? progressActive,
  }) {
    return ThemePlayerBarComponents(
      background: background ?? this.background,
      gradient: identical(gradient, _sentinel)
          ? this.gradient
          : (gradient as ThemeGradient?) ?? ThemeGradient.none,
      progressTrack: progressTrack ?? this.progressTrack,
      progressActive: progressActive ?? this.progressActive,
    );
  }

  static ThemePlayerBarComponents lerp(
    ThemePlayerBarComponents a,
    ThemePlayerBarComponents b,
    double t,
  ) {
    return ThemePlayerBarComponents(
      background: Color.lerp(a.background, b.background, t) ?? a.background,
      gradient: ThemeGradient.lerp(a.gradient, b.gradient, t) ?? a.gradient,
      progressTrack:
          Color.lerp(a.progressTrack, b.progressTrack, t) ?? a.progressTrack,
      progressActive:
          Color.lerp(a.progressActive, b.progressActive, t) ?? a.progressActive,
    );
  }
}

/// Lyric text states — a signature surface for any music player.
class ThemeLyricComponents {
  const ThemeLyricComponents({
    required this.activeLine,
    required this.inactiveLine,
    required this.activeBackground,
  });

  const ThemeLyricComponents.baseline()
    : activeLine = const Color(0xFF2F6FED),
      inactiveLine = const Color(0xFF4A4F57),
      activeBackground = const Color(0x00000000);

  final Color activeLine;
  final Color inactiveLine;

  /// Highlight behind the current line; transparent disables it.
  final Color activeBackground;

  ThemeLyricComponents copyWith({
    Color? activeLine,
    Color? inactiveLine,
    Color? activeBackground,
  }) {
    return ThemeLyricComponents(
      activeLine: activeLine ?? this.activeLine,
      inactiveLine: inactiveLine ?? this.inactiveLine,
      activeBackground: activeBackground ?? this.activeBackground,
    );
  }

  static ThemeLyricComponents lerp(
    ThemeLyricComponents a,
    ThemeLyricComponents b,
    double t,
  ) {
    return ThemeLyricComponents(
      activeLine: Color.lerp(a.activeLine, b.activeLine, t) ?? a.activeLine,
      inactiveLine:
          Color.lerp(a.inactiveLine, b.inactiveLine, t) ?? a.inactiveLine,
      activeBackground:
          Color.lerp(a.activeBackground, b.activeBackground, t) ??
          a.activeBackground,
    );
  }
}

/// Collection and content cards.
class ThemeCardComponents {
  const ThemeCardComponents({
    required this.surface,
    required this.hover,
    required this.selected,
  });

  const ThemeCardComponents.baseline()
    : surface = const Color(0xFFFFFFFF),
      hover = const Color(0x0A000000),
      selected = const Color(0x1F2F6FED);

  final Color surface;
  final Color hover;
  final Color selected;

  ThemeCardComponents copyWith({
    Color? surface,
    Color? hover,
    Color? selected,
  }) {
    return ThemeCardComponents(
      surface: surface ?? this.surface,
      hover: hover ?? this.hover,
      selected: selected ?? this.selected,
    );
  }

  static ThemeCardComponents lerp(
    ThemeCardComponents a,
    ThemeCardComponents b,
    double t,
  ) {
    return ThemeCardComponents(
      surface: Color.lerp(a.surface, b.surface, t) ?? a.surface,
      hover: Color.lerp(a.hover, b.hover, t) ?? a.hover,
      selected: Color.lerp(a.selected, b.selected, t) ?? a.selected,
    );
  }
}

/// Track rows in lists.
class ThemeListComponents {
  const ThemeListComponents({
    required this.itemSelected,
    required this.itemHover,
  });

  const ThemeListComponents.baseline()
    : itemSelected = const Color(0x1F2F6FED),
      itemHover = const Color(0x0A000000);

  final Color itemSelected;
  final Color itemHover;

  ThemeListComponents copyWith({Color? itemSelected, Color? itemHover}) {
    return ThemeListComponents(
      itemSelected: itemSelected ?? this.itemSelected,
      itemHover: itemHover ?? this.itemHover,
    );
  }

  static ThemeListComponents lerp(
    ThemeListComponents a,
    ThemeListComponents b,
    double t,
  ) {
    return ThemeListComponents(
      itemSelected:
          Color.lerp(a.itemSelected, b.itemSelected, t) ?? a.itemSelected,
      itemHover: Color.lerp(a.itemHover, b.itemHover, t) ?? a.itemHover,
    );
  }
}

/// Animation timing.
///
/// Not colour, but equally part of a skin's feel: a snappy skin and a languid
/// one differ in duration as much as in palette. Durations are not
/// interpolable, so lerping snaps at the midpoint.
class ThemeMotionComponents {
  const ThemeMotionComponents({
    required this.shortDurationMs,
    required this.mediumDurationMs,
    required this.curve,
  });

  const ThemeMotionComponents.baseline()
    : shortDurationMs = 150,
      mediumDurationMs = 300,
      curve = ThemeMotionCurve.standard;

  static const int minDurationMs = 0;
  static const int maxDurationMs = 2000;

  final int shortDurationMs;
  final int mediumDurationMs;
  final ThemeMotionCurve curve;

  Duration get short => Duration(milliseconds: shortDurationMs);
  Duration get medium => Duration(milliseconds: mediumDurationMs);

  ThemeMotionComponents copyWith({
    int? shortDurationMs,
    int? mediumDurationMs,
    ThemeMotionCurve? curve,
  }) {
    return ThemeMotionComponents(
      shortDurationMs: shortDurationMs ?? this.shortDurationMs,
      mediumDurationMs: mediumDurationMs ?? this.mediumDurationMs,
      curve: curve ?? this.curve,
    );
  }

  static ThemeMotionComponents lerp(
    ThemeMotionComponents a,
    ThemeMotionComponents b,
    double t,
  ) {
    return t < 0.5 ? a : b;
  }
}

/// Easing presets, so skins pick from known-good curves.
enum ThemeMotionCurve {
  standard,
  decelerate,
  accelerate,
  linear;

  /// Material easing equivalents.
  ///
  /// Returned as a control-point quadruple rather than a Flutter [Curve] so
  /// this domain file stays free of widget-library imports. Callers convert
  /// with [toCurve] below.
  (double, double, double, double) get controlPoints => switch (this) {
    ThemeMotionCurve.standard => (0.2, 0.0, 0.0, 1.0),
    ThemeMotionCurve.decelerate => (0.0, 0.0, 0.0, 1.0),
    ThemeMotionCurve.accelerate => (0.3, 0.0, 1.0, 1.0),
    ThemeMotionCurve.linear => (0.0, 0.0, 1.0, 1.0),
  };

  static ThemeMotionCurve fromName(String? name) {
    return values.firstWhere(
      (value) => value.name == name,
      orElse: () => ThemeMotionCurve.standard,
    );
  }
}
