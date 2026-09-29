import 'theme_regions.dart';
import 'theme_home.dart';

/// Declarative layout knobs for a skin (Level 1).
///
/// Unlike tokens, layout is **per form factor**: a skin can shape the desktop
/// shell and the phone shell independently, or describe only one and inherit
/// the official default for the other. This is what makes a single skin work
/// across desktop and mobile.
class ThemeLayout {
  const ThemeLayout({
    required this.desktop,
    required this.mobile,
    required this.content,
    this.home = const ThemeHomeLayout.baseline(),
  });

  /// Official defaults: a persistent rail beside the content, player bar at
  /// the bottom.
  const ThemeLayout.baseline()
    : desktop = const ThemeDesktopLayout.baseline(),
      mobile = const ThemeMobileLayout.baseline(),
      content = const ThemeContentLayout.baseline(),
      home = const ThemeHomeLayout.baseline();

  final ThemeDesktopLayout desktop;
  final ThemeMobileLayout mobile;
  final ThemeContentLayout content;
  final ThemeHomeLayout home;

  ThemeLayout copyWith({
    ThemeDesktopLayout? desktop,
    ThemeMobileLayout? mobile,
    ThemeContentLayout? content,
    ThemeHomeLayout? home,
  }) {
    return ThemeLayout(
      desktop: desktop ?? this.desktop,
      mobile: mobile ?? this.mobile,
      content: content ?? this.content,
      home: home ?? this.home,
    );
  }
}

/// Desktop (and large-window) chrome.
class ThemeDesktopLayout {
  const ThemeDesktopLayout({required this.arrangement});

  const ThemeDesktopLayout.baseline() : arrangement = RobyneArrangement.desktop;

  /// The D6 arrangement the shell actually renders on a desktop-shaped
  /// window. Skins that omit it inherit the official flagship layout.
  ///
  /// The pre-arrangement legacy knobs (`sidebar.*`, `playerBarHeight`,
  /// `playerBarPosition`) were removed: the arrangement supersedes them, and
  /// keeping both around meant a skin could declare a 72dp player bar and a
  /// 0.09 arrangement ratio and be silently ignored on one of them.
  final RobyneArrangement arrangement;

  ThemeDesktopLayout copyWith({RobyneArrangement? arrangement}) {
    return ThemeDesktopLayout(arrangement: arrangement ?? this.arrangement);
  }
}

/// Phone-sized chrome.
class ThemeMobileLayout {
  const ThemeMobileLayout({required this.arrangement});

  const ThemeMobileLayout.baseline() : arrangement = RobyneArrangement.mobile;

  /// The phone-shell arrangement. Only `top`/`center`/`bottom` slots are
  /// legal here; the parser repairs anything else into the official layout.
  final RobyneArrangement arrangement;

  ThemeMobileLayout copyWith({RobyneArrangement? arrangement}) {
    return ThemeMobileLayout(arrangement: arrangement ?? this.arrangement);
  }
}

/// How lists and grids are presented.
class ThemeContentLayout {
  const ThemeContentLayout({
    required this.listStyle,
    required this.density,
    this.styles = const <ThemeContentSurface, ThemeListStyle>{},
  });

  const ThemeContentLayout.baseline()
    : listStyle = ThemeListStyle.list,
      density = ThemeDensity.regular,
      styles = const <ThemeContentSurface, ThemeListStyle>{};

  final ThemeListStyle listStyle;
  final ThemeDensity density;

  /// Per-destination overrides of [listStyle].
  ///
  /// The design's own table (`UI_DESIGN_SPEC.md` §2.5) maps styles per
  /// *surface*, not globally — `list` for the local library, `grid` for the
  /// discover shelf, `banner` for a recommendation strip. A single global
  /// value cannot express that, so a skin that declared `banner` got a banner
  /// everywhere, including the one place the design asks for rows.
  final Map<ThemeContentSurface, ThemeListStyle> styles;

  /// The style to use for [surface], falling back to [listStyle].
  ThemeListStyle styleFor(ThemeContentSurface surface) =>
      styles[surface] ?? listStyle;

  ThemeContentLayout copyWith({
    ThemeListStyle? listStyle,
    ThemeDensity? density,
    Map<ThemeContentSurface, ThemeListStyle>? styles,
  }) {
    return ThemeContentLayout(
      listStyle: listStyle ?? this.listStyle,
      density: density ?? this.density,
      styles: styles ?? this.styles,
    );
  }
}

/// The destinations whose content presentation a skin may set separately.
///
/// Closed, like every other skin-facing slot set: a skin can restyle the
/// surfaces the app actually renders, and an unknown name is ignored rather
/// than inventing a page.
enum ThemeContentSurface {
  library('library'),
  discover('discover'),
  playlists('playlists'),
  downloads('downloads'),
  queue('queue'),
  search('search');

  const ThemeContentSurface(this.jsonName);

  final String jsonName;

  static ThemeContentSurface? fromJsonName(String? name) {
    if (name == null) {
      return null;
    }
    for (final value in values) {
      if (value.jsonName == name) {
        return value;
      }
    }
    return null;
  }
}

/// List presentation.
enum ThemeListStyle {
  list,
  banner,
  card,
  grid,
  compact;

  static ThemeListStyle fromName(String? name) {
    return values.firstWhere(
      (value) => value.name == name,
      orElse: () => ThemeListStyle.list,
    );
  }
}

/// Vertical rhythm of rows.
///
/// A multiplier rather than an absolute height: `components.content.rowHeight`
/// says how tall a row *is*, and density says whether the skin wants the whole
/// rhythm tighter or airier than that base. Keeping it a factor means a skin
/// can declare both without one silently winning.
enum ThemeDensity {
  compact,
  regular,
  comfortable;

  /// Factor applied to the content region's row height.
  double get rowScale => switch (this) {
    ThemeDensity.compact => 0.85,
    ThemeDensity.regular => 1,
    ThemeDensity.comfortable => 1.2,
  };

  static ThemeDensity fromName(String? name) {
    return values.firstWhere(
      (value) => value.name == name,
      orElse: () => ThemeDensity.regular,
    );
  }
}
