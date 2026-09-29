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
    required this.ambient,
    required this.content,
  });

  /// Baseline matching the pre-existing look, so skins that omit every
  /// component token are unaffected.
  const ThemeComponents.baseline()
    : navBar = const ThemeNavBarComponents.baseline(),
      playerBar = const ThemePlayerBarComponents.baseline(),
      lyric = const ThemeLyricComponents.baseline(),
      card = const ThemeCardComponents.baseline(),
      list = const ThemeListComponents.baseline(),
      motion = const ThemeMotionComponents.baseline(),
      ambient = const ThemeAmbientComponents.baseline(),
      content = const ThemeContentMetrics.baseline();

  final ThemeNavBarComponents navBar;
  final ThemePlayerBarComponents playerBar;
  final ThemeLyricComponents lyric;
  final ThemeCardComponents card;
  final ThemeListComponents list;
  final ThemeMotionComponents motion;

  /// The cover-driven atmosphere painted behind content.
  final ThemeAmbientComponents ambient;

  /// Geometry of the content region: gutters, row rhythm, card sizing.
  final ThemeContentMetrics content;

  ThemeComponents copyWith({
    ThemeNavBarComponents? navBar,
    ThemePlayerBarComponents? playerBar,
    ThemeLyricComponents? lyric,
    ThemeCardComponents? card,
    ThemeListComponents? list,
    ThemeMotionComponents? motion,
    ThemeAmbientComponents? ambient,
    ThemeContentMetrics? content,
  }) {
    return ThemeComponents(
      navBar: navBar ?? this.navBar,
      playerBar: playerBar ?? this.playerBar,
      lyric: lyric ?? this.lyric,
      card: card ?? this.card,
      list: list ?? this.list,
      motion: motion ?? this.motion,
      ambient: ambient ?? this.ambient,
      content: content ?? this.content,
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
      ambient: ThemeAmbientComponents.lerp(a.ambient, b.ambient, t),
      content: ThemeContentMetrics.lerp(a.content, b.content, t),
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
    required this.selectedIndicatorFill,
    this.showProfile = true,
    this.showPlaylistGroup = true,
  });

  const ThemeNavBarComponents.baseline()
    : background = const Color(0x00000000),
      gradient = ThemeGradient.none,
      selectedItem = const Color(0xFF2F6FED),
      selectedIndicator = const Color(0x1F2F6FED),
      selectedIndicatorFill = const Color(0x1F2F6FED),
      showProfile = true,
      showPlaylistGroup = true;

  /// Fully transparent means "use the semantic background token".
  final Color background;

  /// Painted over [background] when non-empty — the QQ-music-style look.
  final ThemeGradient gradient;

  final Color selectedItem;

  /// Solid accent edge on the selected row.
  final Color selectedIndicator;

  /// Brand wash behind the selected row, layered under [selectedIndicator].
  ///
  /// Split out of [selectedIndicator] so the design's solid right-edge accent
  /// and its translucent row background can both be declared without the
  /// solid accent losing its alpha at parse time.
  final Color selectedIndicatorFill;

  /// Whether the rail lists the user's playlists beneath the destinations.
  ///
  /// The design's rail is a fixed composition — four destinations, a tools
  /// group and a footer — so the group that the app adds by default is a
  /// composition decision, not a decoration. A skin that wants the tighter
  /// rail switches it off; the playlists page remains one click away.
  final bool showPlaylistGroup;

  /// Whether the rail leads with the user identity block (avatar, name,
  /// library count).
  ///
  /// The design drew the block for an account system the app does not have
  /// yet; a skin whose flagship targets a signed-out MVP hides it rather than
  /// shipping a dead control. The destinations start the rail instead.
  final bool showProfile;

  ThemeNavBarComponents copyWith({
    Color? background,
    Object? gradient = _sentinel,
    Color? selectedItem,
    Color? selectedIndicator,
    Color? selectedIndicatorFill,
    bool? showProfile,
    bool? showPlaylistGroup,
  }) {
    return ThemeNavBarComponents(
      background: background ?? this.background,
      gradient: identical(gradient, _sentinel)
          ? this.gradient
          : (gradient as ThemeGradient?) ?? ThemeGradient.none,
      selectedItem: selectedItem ?? this.selectedItem,
      selectedIndicator: selectedIndicator ?? this.selectedIndicator,
      selectedIndicatorFill:
          selectedIndicatorFill ?? this.selectedIndicatorFill,
      showProfile: showProfile ?? this.showProfile,
      showPlaylistGroup: showPlaylistGroup ?? this.showPlaylistGroup,
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
      selectedIndicatorFill:
          Color.lerp(a.selectedIndicatorFill, b.selectedIndicatorFill, t) ??
          a.selectedIndicatorFill,
      showProfile: t < 0.5 ? a.showProfile : b.showProfile,
      showPlaylistGroup: t < 0.5 ? a.showPlaylistGroup : b.showPlaylistGroup,
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
///
/// See also [ThemeAmbientComponents], which paints the cover-driven wash the
/// design spec calls the app's signature.
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

/// The cover-driven atmosphere behind the content region.
///
/// `UI_DESIGN_SPEC.md` §3.4 calls this "Robyne 的标志性识别": the top of the
/// content area picks up the dominant colour of what is playing, fading into
/// the page background. Without it every screen is a flat panel, and the
/// design's most recognisable trait is simply absent.
///
/// It is a *token*, not a hardcoded effect, because how much atmosphere a skin
/// wants is a taste decision: one skin glows, another stays matte. `strength`
/// of zero switches it off entirely and costs nothing to render.
class ThemeAmbientComponents {
  const ThemeAmbientComponents({
    required this.enabled,
    required this.strength,
    required this.heightFraction,
    required this.blur,
    this.color,
  });

  const ThemeAmbientComponents.baseline()
    : enabled = false,
      strength = 0.28,
      heightFraction = 0.32,
      blur = 48,
      color = null;

  /// Whether the wash renders at all.
  final bool enabled;

  /// Peak opacity of the wash, 0..1. Design spec §3.4 asks for 0.20–0.35.
  final double strength;

  /// How far down the content region the wash reaches, as a fraction of its
  /// height. The spec asks for the top 25%–35%.
  final double heightFraction;

  /// Blur sigma. A high value turns banding into a soft glow.
  final double blur;

  /// Fixed wash colour, or null to derive it from the current artwork.
  ///
  /// Deriving is the design's intent — the wash follows the music — and the
  /// fixed colour is the escape hatch for a skin that wants a constant brand
  /// glow regardless of what is playing.
  final Color? color;

  bool get isVisible => enabled && strength > 0;

  ThemeAmbientComponents copyWith({
    bool? enabled,
    double? strength,
    double? heightFraction,
    double? blur,
    Object? color = _sentinel,
  }) {
    return ThemeAmbientComponents(
      enabled: enabled ?? this.enabled,
      strength: strength ?? this.strength,
      heightFraction: heightFraction ?? this.heightFraction,
      blur: blur ?? this.blur,
      color: identical(color, _sentinel) ? this.color : color as Color?,
    );
  }

  static ThemeAmbientComponents lerp(
    ThemeAmbientComponents a,
    ThemeAmbientComponents b,
    double t,
  ) {
    return ThemeAmbientComponents(
      enabled: t < 0.5 ? a.enabled : b.enabled,
      strength: a.strength + (b.strength - a.strength) * t,
      heightFraction:
          a.heightFraction + (b.heightFraction - a.heightFraction) * t,
      blur: a.blur + (b.blur - a.blur) * t,
      color: Color.lerp(a.color, b.color, t),
    );
  }
}

/// Geometry of the content region.
///
/// `UI_DESIGN_SPEC.md` §3.2 specifies these as concrete numbers — 32dp desktop
/// gutters, 56dp list rows, 180dp minimum card width, 16dp card gaps — but
/// they lived as literals inside feature pages, so a skin could recolour a
/// library row and not move it by a pixel. That is the ceiling on "just tweak
/// the spacing a little": without these, every such request is a code change.
///
/// Values are logical pixels rather than the main-axis ratios used by
/// [ThemeLayout]: a gutter or a row height is a legibility decision with a
/// right answer, not a share of the window. Ratios are for *regions*.
class ThemeContentMetrics {
  const ThemeContentMetrics({
    required this.gutter,
    required this.gutterCompact,
    required this.rowHeight,
    required this.rowHeightCompact,
    required this.cardMinWidth,
    required this.cardMinWidthCompact,
    required this.cardGap,
    required this.cardGapCompact,
    required this.sectionGap,
    required this.navIconSize,
    required this.logoSize,
    required this.avatarSize,
  });

  const ThemeContentMetrics.baseline()
    : gutter = 28,
      gutterCompact = 16,
      rowHeight = 56,
      rowHeightCompact = 48,
      cardMinWidth = 180,
      cardMinWidthCompact = 140,
      cardGap = 16,
      cardGapCompact = 12,
      sectionGap = 24,
      navIconSize = 22,
      logoSize = 26,
      avatarSize = 38;

  /// Side padding on an expanded-width window.
  final double gutter;

  /// Side padding on a phone. The design halves the desktop gutter rather
  /// than scaling it, because touch targets should not shrink with the window.
  final double gutterCompact;

  /// Height of one content row, and its compressed form for landscape phones.
  final double rowHeight;
  final double rowHeightCompact;

  /// Minimum width of a grid/card tile, and the gap between tiles.
  final double cardMinWidth;
  final double cardMinWidthCompact;
  final double cardGap;
  final double cardGapCompact;

  /// Vertical space between content sections.
  final double sectionGap;

  /// Chrome proportions that sit next to the content.
  ///
  /// Kept here rather than in a separate group because they are the same kind
  /// of decision — "how big is this thing on screen" — and splitting them
  /// would make a skin author look in two places for one answer.
  final double navIconSize;

  /// Brand mark in the rail.
  final double logoSize;

  /// Profile avatar in the rail and the phone header.
  final double avatarSize;

  /// Side padding for [compact].
  double gutterFor({required bool compact}) => compact ? gutterCompact : gutter;

  /// Row height for [compact].
  double rowHeightFor({required bool compact}) =>
      compact ? rowHeightCompact : rowHeight;

  /// Tile minimum width for [compact].
  double cardMinWidthFor({required bool compact}) =>
      compact ? cardMinWidthCompact : cardMinWidth;

  /// Tile gap for [compact].
  double cardGapFor({required bool compact}) =>
      compact ? cardGapCompact : cardGap;

  ThemeContentMetrics copyWith({
    double? gutter,
    double? gutterCompact,
    double? rowHeight,
    double? rowHeightCompact,
    double? cardMinWidth,
    double? cardMinWidthCompact,
    double? cardGap,
    double? cardGapCompact,
    double? sectionGap,
    double? navIconSize,
    double? logoSize,
    double? avatarSize,
  }) {
    return ThemeContentMetrics(
      gutter: gutter ?? this.gutter,
      gutterCompact: gutterCompact ?? this.gutterCompact,
      rowHeight: rowHeight ?? this.rowHeight,
      rowHeightCompact: rowHeightCompact ?? this.rowHeightCompact,
      cardMinWidth: cardMinWidth ?? this.cardMinWidth,
      cardMinWidthCompact: cardMinWidthCompact ?? this.cardMinWidthCompact,
      cardGap: cardGap ?? this.cardGap,
      cardGapCompact: cardGapCompact ?? this.cardGapCompact,
      sectionGap: sectionGap ?? this.sectionGap,
      navIconSize: navIconSize ?? this.navIconSize,
      logoSize: logoSize ?? this.logoSize,
      avatarSize: avatarSize ?? this.avatarSize,
    );
  }

  static ThemeContentMetrics lerp(
    ThemeContentMetrics a,
    ThemeContentMetrics b,
    double t,
  ) {
    double mix(double from, double to) => from + (to - from) * t;
    return ThemeContentMetrics(
      gutter: mix(a.gutter, b.gutter),
      gutterCompact: mix(a.gutterCompact, b.gutterCompact),
      rowHeight: mix(a.rowHeight, b.rowHeight),
      rowHeightCompact: mix(a.rowHeightCompact, b.rowHeightCompact),
      cardMinWidth: mix(a.cardMinWidth, b.cardMinWidth),
      cardMinWidthCompact: mix(a.cardMinWidthCompact, b.cardMinWidthCompact),
      cardGap: mix(a.cardGap, b.cardGap),
      cardGapCompact: mix(a.cardGapCompact, b.cardGapCompact),
      sectionGap: mix(a.sectionGap, b.sectionGap),
      navIconSize: mix(a.navIconSize, b.navIconSize),
      logoSize: mix(a.logoSize, b.logoSize),
      avatarSize: mix(a.avatarSize, b.avatarSize),
    );
  }
}
