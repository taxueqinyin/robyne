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
  });

  /// Official defaults: a persistent rail beside the content, player bar at
  /// the bottom.
  const ThemeLayout.baseline()
    : desktop = const ThemeDesktopLayout.baseline(),
      mobile = const ThemeMobileLayout.baseline(),
      content = const ThemeContentLayout.baseline();

  final ThemeDesktopLayout desktop;
  final ThemeMobileLayout mobile;
  final ThemeContentLayout content;

  ThemeLayout copyWith({
    ThemeDesktopLayout? desktop,
    ThemeMobileLayout? mobile,
    ThemeContentLayout? content,
  }) {
    return ThemeLayout(
      desktop: desktop ?? this.desktop,
      mobile: mobile ?? this.mobile,
      content: content ?? this.content,
    );
  }
}

/// Desktop (and large-window) chrome.
class ThemeDesktopLayout {
  const ThemeDesktopLayout({
    required this.sidebar,
    required this.playerBarPosition,
    required this.playerBarHeight,
  });

  const ThemeDesktopLayout.baseline()
    : sidebar = const ThemeSidebarLayout.baseline(),
      playerBarPosition = ThemePlayerBarPosition.bottom,
      playerBarHeight = 72;

  final ThemeSidebarLayout sidebar;

  /// Where the player bar sits. `floating` is not supported on compact
  /// layouts; they always use `bottom`.
  final ThemePlayerBarPosition playerBarPosition;
  final double playerBarHeight;

  ThemeDesktopLayout copyWith({
    ThemeSidebarLayout? sidebar,
    ThemePlayerBarPosition? playerBarPosition,
    double? playerBarHeight,
  }) {
    return ThemeDesktopLayout(
      sidebar: sidebar ?? this.sidebar,
      playerBarPosition: playerBarPosition ?? this.playerBarPosition,
      playerBarHeight: playerBarHeight ?? this.playerBarHeight,
    );
  }
}

/// Phone-sized chrome.
class ThemeMobileLayout {
  const ThemeMobileLayout({
    required this.navigation,
    required this.playerBarHeight,
    required this.playerBarCompact,
  });

  const ThemeMobileLayout.baseline()
    : navigation = ThemeMobileNavigation.bottomTabs,
      playerBarHeight = 64,
      playerBarCompact = true;

  final ThemeMobileNavigation navigation;
  final double playerBarHeight;

  /// Drops the volume slider and tightens padding on phone-sized windows.
  final bool playerBarCompact;

  ThemeMobileLayout copyWith({
    ThemeMobileNavigation? navigation,
    double? playerBarHeight,
    bool? playerBarCompact,
  }) {
    return ThemeMobileLayout(
      navigation: navigation ?? this.navigation,
      playerBarHeight: playerBarHeight ?? this.playerBarHeight,
      playerBarCompact: playerBarCompact ?? this.playerBarCompact,
    );
  }
}

/// Shape of the primary navigation on desktop.
class ThemeSidebarLayout {
  const ThemeSidebarLayout({
    required this.position,
    required this.width,
    required this.collapsible,
    required this.labelMode,
  });

  const ThemeSidebarLayout.baseline()
    : position = ThemeSidebarPosition.left,
      width = 80,
      collapsible = false,
      labelMode = ThemeRailLabelMode.all;

  final ThemeSidebarPosition position;

  /// Rail width. Widened automatically when labels are shown.
  final double width;
  final bool collapsible;
  final ThemeRailLabelMode labelMode;

  double get effectiveWidth {
    return switch (labelMode) {
      ThemeRailLabelMode.all => width < 120 ? width + 52 : width,
      ThemeRailLabelMode.selected => width < 100 ? width + 32 : width,
      ThemeRailLabelMode.none => width,
    };
  }

  ThemeSidebarLayout copyWith({
    ThemeSidebarPosition? position,
    double? width,
    bool? collapsible,
    ThemeRailLabelMode? labelMode,
  }) {
    return ThemeSidebarLayout(
      position: position ?? this.position,
      width: width ?? this.width,
      collapsible: collapsible ?? this.collapsible,
      labelMode: labelMode ?? this.labelMode,
    );
  }
}

/// How lists and grids are presented.
class ThemeContentLayout {
  const ThemeContentLayout({required this.listStyle, required this.density});

  const ThemeContentLayout.baseline()
    : listStyle = ThemeListStyle.list,
      density = ThemeDensity.regular;

  final ThemeListStyle listStyle;
  final ThemeDensity density;

  ThemeContentLayout copyWith({
    ThemeListStyle? listStyle,
    ThemeDensity? density,
  }) {
    return ThemeContentLayout(
      listStyle: listStyle ?? this.listStyle,
      density: density ?? this.density,
    );
  }
}

/// Which side the desktop rail sits on.
enum ThemeSidebarPosition {
  left,
  right;

  static ThemeSidebarPosition fromName(String? name) {
    return values.firstWhere(
      (value) => value.name == name,
      orElse: () => ThemeSidebarPosition.left,
    );
  }
}

/// NavigationRail label behaviour.
enum ThemeRailLabelMode {
  all,
  selected,
  none;

  static ThemeRailLabelMode fromName(String? name) {
    return values.firstWhere(
      (value) => value.name == name,
      orElse: () => ThemeRailLabelMode.all,
    );
  }
}

/// Player bar placement.
enum ThemePlayerBarPosition {
  bottom,
  top;

  static ThemePlayerBarPosition fromName(String? name) {
    return values.firstWhere(
      (value) => value.name == name,
      orElse: () => ThemePlayerBarPosition.bottom,
    );
  }
}

/// Mobile navigation style.
enum ThemeMobileNavigation {
  bottomTabs,
  navigationDrawer;

  static ThemeMobileNavigation fromName(String? name) {
    return values.firstWhere(
      (value) => value.name == name,
      orElse: () => ThemeMobileNavigation.bottomTabs,
    );
  }
}

/// List presentation.
enum ThemeListStyle {
  list,
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
enum ThemeDensity {
  compact,
  regular,
  comfortable;

  static ThemeDensity fromName(String? name) {
    return values.firstWhere(
      (value) => value.name == name,
      orElse: () => ThemeDensity.regular,
    );
  }
}
