import 'dart:ui';

import 'theme_components.dart';

/// Semantic design tokens shared by every Robyne surface.
///
/// Skin authors only ever describe this layer. Component-level values are
/// derived from it, which is what guarantees that a skin cannot break the UI.
class ThemeTokens {
  const ThemeTokens({
    required this.color,
    required this.radius,
    required this.spacing,
    required this.typography,
    required this.elevation,
    required this.effects,
    required this.background,
    this.components = const ThemeComponents.baseline(),
  });

  /// Default tokens used as the baseline whenever a skin omits a value.
  const ThemeTokens.baseline()
    : color = const ThemeColors.baseline(),
      radius = const ThemeRadii.baseline(),
      spacing = const ThemeSpacings.baseline(),
      typography = const ThemeTypography.baseline(),
      elevation = const ThemeElevations.baseline(),
      effects = const ThemeEffects.baseline(),
      background = const ThemeBackground.baseline(),
      components = const ThemeComponents.baseline();

  /// Dark-neutral tokens, used wherever the app needs a legible dark surface
  /// without a skin to describe one.
  ///
  /// Two callers share this: the resolver, when a light-authored skin is
  /// forced into dark mode, and the pre-load stand-in the shell paints on its
  /// very first frame. Keeping one palette for both means "dark default" is
  /// defined once instead of being re-guessed per call site.
  const ThemeTokens.darkBaseline()
    : color = const ThemeColors.darkBaseline(),
      radius = const ThemeRadii.baseline(),
      spacing = const ThemeSpacings.baseline(),
      typography = const ThemeTypography.baseline(),
      elevation = const ThemeElevations.baseline(),
      effects = const ThemeEffects.baseline(),
      background = const ThemeBackground.baseline(),
      components = const ThemeComponents.baseline();

  final ThemeColors color;
  final ThemeRadii radius;
  final ThemeSpacings spacing;
  final ThemeTypography typography;
  final ThemeElevations elevation;
  final ThemeEffects effects;
  final ThemeBackground background;

  /// Recognisable surfaces (navigation gradient, active lyric line, card
  /// hover...). See [ThemeComponents]: these have no home in the semantic
  /// layer, and without them a skin can only recolour the generic roles.
  ///
  /// Defaults to the baseline so existing skins are unaffected.
  final ThemeComponents components;

  ThemeTokens copyWith({
    ThemeColors? color,
    ThemeRadii? radius,
    ThemeSpacings? spacing,
    ThemeTypography? typography,
    ThemeElevations? elevation,
    ThemeEffects? effects,
    ThemeBackground? background,
    ThemeComponents? components,
  }) {
    return ThemeTokens(
      color: color ?? this.color,
      radius: radius ?? this.radius,
      spacing: spacing ?? this.spacing,
      typography: typography ?? this.typography,
      elevation: elevation ?? this.elevation,
      effects: effects ?? this.effects,
      background: background ?? this.background,
      components: components ?? this.components,
    );
  }
}

/// Colour tokens grouped by semantic role.
class ThemeColors {
  const ThemeColors({
    required this.backgroundBase,
    required this.backgroundElevated,
    required this.backgroundSunken,
    required this.backgroundOverlay,
    required this.surfaceBase,
    required this.surfaceHover,
    required this.surfaceActive,
    required this.surfaceSelected,
    required this.brandBase,
    required this.brandHover,
    required this.brandMuted,
    required this.onBrand,
    required this.accentBase,
    required this.accentMuted,
    required this.onAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.borderSubtle,
    required this.borderDefault,
    required this.borderStrong,
    required this.borderFocus,
    required this.danger,
    required this.warning,
    required this.success,
  });

  const ThemeColors.baseline()
    : backgroundBase = const Color(0xFFF7F8FA),
      backgroundElevated = const Color(0xFFFFFFFF),
      backgroundSunken = const Color(0xFFEDEFF3),
      backgroundOverlay = const Color(0x80000000),
      surfaceBase = const Color(0xFFFFFFFF),
      surfaceHover = const Color(0x14000000),
      surfaceActive = const Color(0x1F000000),
      surfaceSelected = const Color(0x1F2F6FED),
      brandBase = const Color(0xFF2F6FED),
      brandHover = const Color(0xFF2559C4),
      brandMuted = const Color(0x1F2F6FED),
      onBrand = const Color(0xFFFFFFFF),
      accentBase = const Color(0xFF2E9E5B),
      accentMuted = const Color(0x1F2E9E5B),
      onAccent = const Color(0xFFFFFFFF),
      textPrimary = const Color(0xFF1B1D21),
      textSecondary = const Color(0xFF4A4F57),
      textMuted = const Color(0xFF7A8089),
      textDisabled = const Color(0xFFB4B9C0),
      borderSubtle = const Color(0x0D000000),
      borderDefault = const Color(0x1A000000),
      borderStrong = const Color(0x29000000),
      borderFocus = const Color(0xFF2F6FED),
      danger = const Color(0xFFD64545),
      warning = const Color(0xFFD98A1F),
      success = const Color(0xFF2E9E5B);

  /// The same semantic roles, resolved for a dark surface.
  ///
  /// Only neutrals move: brand, accent and status keep their identity, because
  /// a dark rendering of a skin should still read as that skin.
  const ThemeColors.darkBaseline()
    : backgroundBase = const Color(0xFF14161A),
      backgroundElevated = const Color(0xFF1C1F24),
      backgroundSunken = const Color(0xFF0F1114),
      backgroundOverlay = const Color(0x99000000),
      surfaceBase = const Color(0xFF1C1F24),
      surfaceHover = const Color(0x14FFFFFF),
      surfaceActive = const Color(0x1FFFFFFF),
      surfaceSelected = const Color(0xFF2B4A7A),
      brandBase = const Color(0xFF2F6FED),
      brandHover = const Color(0xFF4A83F0),
      brandMuted = const Color(0x1F2F6FED),
      onBrand = const Color(0xFFFFFFFF),
      accentBase = const Color(0xFF3FB86C),
      accentMuted = const Color(0x1F3FB86C),
      onAccent = const Color(0xFF06110A),
      textPrimary = const Color(0xFFE8EAED),
      textSecondary = const Color(0xFFA8AEB8),
      textMuted = const Color(0xFF7A8089),
      textDisabled = const Color(0xFF565B63),
      borderSubtle = const Color(0x0DFFFFFF),
      borderDefault = const Color(0x1AFFFFFF),
      borderStrong = const Color(0x29FFFFFF),
      borderFocus = const Color(0xFF4A83F0),
      danger = const Color(0xFFE06C6C),
      warning = const Color(0xFFE0A03F),
      success = const Color(0xFF3FB86C);

  final Color backgroundBase;
  final Color backgroundElevated;
  final Color backgroundSunken;
  final Color backgroundOverlay;

  final Color surfaceBase;
  final Color surfaceHover;
  final Color surfaceActive;
  final Color surfaceSelected;

  final Color brandBase;
  final Color brandHover;
  final Color brandMuted;
  final Color onBrand;

  /// The secondary emphasis colour.
  ///
  /// The flagship design uses it for lossless/high-quality markers and for
  /// toggles that are "on" but are not the primary action, so a skin can
  /// signal quality without reusing the brand colour.
  final Color accentBase;

  /// A washed-out accent for backgrounds that should not shout.
  final Color accentMuted;

  /// Text and icons painted on top of [accentBase].
  final Color onAccent;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;

  final Color borderSubtle;
  final Color borderDefault;
  final Color borderStrong;
  final Color borderFocus;

  final Color danger;
  final Color warning;
  final Color success;

  ThemeColors copyWith({
    Color? backgroundBase,
    Color? backgroundElevated,
    Color? backgroundSunken,
    Color? backgroundOverlay,
    Color? surfaceBase,
    Color? surfaceHover,
    Color? surfaceActive,
    Color? surfaceSelected,
    Color? brandBase,
    Color? brandHover,
    Color? brandMuted,
    Color? onBrand,
    Color? accentBase,
    Color? accentMuted,
    Color? onAccent,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textDisabled,
    Color? borderSubtle,
    Color? borderDefault,
    Color? borderStrong,
    Color? borderFocus,
    Color? danger,
    Color? warning,
    Color? success,
  }) {
    return ThemeColors(
      backgroundBase: backgroundBase ?? this.backgroundBase,
      backgroundElevated: backgroundElevated ?? this.backgroundElevated,
      backgroundSunken: backgroundSunken ?? this.backgroundSunken,
      backgroundOverlay: backgroundOverlay ?? this.backgroundOverlay,
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      surfaceActive: surfaceActive ?? this.surfaceActive,
      surfaceSelected: surfaceSelected ?? this.surfaceSelected,
      brandBase: brandBase ?? this.brandBase,
      brandHover: brandHover ?? this.brandHover,
      brandMuted: brandMuted ?? this.brandMuted,
      onBrand: onBrand ?? this.onBrand,
      accentBase: accentBase ?? this.accentBase,
      accentMuted: accentMuted ?? this.accentMuted,
      onAccent: onAccent ?? this.onAccent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textDisabled: textDisabled ?? this.textDisabled,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderDefault: borderDefault ?? this.borderDefault,
      borderStrong: borderStrong ?? this.borderStrong,
      borderFocus: borderFocus ?? this.borderFocus,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      success: success ?? this.success,
    );
  }
}

/// Corner radius tokens.
class ThemeRadii {
  const ThemeRadii({
    required this.sm,
    required this.md,
    required this.lg,
    required this.full,
  });

  const ThemeRadii.baseline() : sm = 6, md = 10, lg = 16, full = 999;

  final double sm;
  final double md;
  final double lg;
  final double full;

  ThemeRadii copyWith({double? sm, double? md, double? lg, double? full}) {
    return ThemeRadii(
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      full: full ?? this.full,
    );
  }
}

/// Spacing tokens.
class ThemeSpacings {
  const ThemeSpacings({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
  });

  const ThemeSpacings.baseline() : xs = 4, sm = 8, md = 12, lg = 16, xl = 24;

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;

  ThemeSpacings copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
  }) {
    return ThemeSpacings(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
    );
  }
}

/// Typography tokens.
///
/// [scale] is the blunt instrument: one multiplier for every size. The role
/// sizes below are the precise one, and they exist because `UI_DESIGN_SPEC.md`
/// §3.3 defines exactly five roles — page title 24/600, section title 18/600,
/// list primary 15/400, list secondary 13/400, label 11/500. Without them a
/// skin could only make *everything* bigger, which is not the same as
/// choosing a typographic voice.
class ThemeTypography {
  const ThemeTypography({
    required this.fontFamily,
    required this.scale,
    required this.bodyWeight,
    required this.titleWeight,
    this.pageTitleSize,
    this.sectionTitleSize,
    this.listPrimarySize,
    this.listSecondarySize,
    this.labelSize,
    this.labelWeight,
  });

  const ThemeTypography.baseline()
    : fontFamily = null,
      scale = 1,
      bodyWeight = 400,
      titleWeight = 600,
      pageTitleSize = null,
      sectionTitleSize = null,
      listPrimarySize = null,
      listSecondarySize = null,
      labelSize = null,
      labelWeight = null;

  /// Null means "use the platform default font".
  final String? fontFamily;

  /// Multiplier applied to every text size. Enables skins that prefer a
  /// slightly denser or airier look without touching individual sizes.
  final double scale;

  final int bodyWeight;
  final int titleWeight;

  /// Per-role sizes, in logical pixels.
  ///
  /// Null means "use the design-spec default for this role", so a skin that
  /// only cares about one role does not have to restate the other four.
  final double? pageTitleSize;
  final double? sectionTitleSize;
  final double? listPrimarySize;
  final double? listSecondarySize;
  final double? labelSize;

  /// Label weight; design spec §3.3 asks for 500.
  final int? labelWeight;

  /// Role sizes resolved against the design-spec defaults.
  double get resolvedPageTitleSize => pageTitleSize ?? 24;
  double get resolvedSectionTitleSize => sectionTitleSize ?? 18;
  double get resolvedListPrimarySize => listPrimarySize ?? 15;
  double get resolvedListSecondarySize => listSecondarySize ?? 13;
  double get resolvedLabelSize => labelSize ?? 11;
  int get resolvedLabelWeight => labelWeight ?? 500;

  ThemeTypography copyWith({
    Object? fontFamily = _sentinel,
    double? scale,
    int? bodyWeight,
    int? titleWeight,
    Object? pageTitleSize = _sentinel,
    Object? sectionTitleSize = _sentinel,
    Object? listPrimarySize = _sentinel,
    Object? listSecondarySize = _sentinel,
    Object? labelSize = _sentinel,
    Object? labelWeight = _sentinel,
  }) {
    return ThemeTypography(
      fontFamily: identical(fontFamily, _sentinel)
          ? this.fontFamily
          : fontFamily as String?,
      scale: scale ?? this.scale,
      bodyWeight: bodyWeight ?? this.bodyWeight,
      titleWeight: titleWeight ?? this.titleWeight,
      pageTitleSize: identical(pageTitleSize, _sentinel)
          ? this.pageTitleSize
          : pageTitleSize as double?,
      sectionTitleSize: identical(sectionTitleSize, _sentinel)
          ? this.sectionTitleSize
          : sectionTitleSize as double?,
      listPrimarySize: identical(listPrimarySize, _sentinel)
          ? this.listPrimarySize
          : listPrimarySize as double?,
      listSecondarySize: identical(listSecondarySize, _sentinel)
          ? this.listSecondarySize
          : listSecondarySize as double?,
      labelSize: identical(labelSize, _sentinel)
          ? this.labelSize
          : labelSize as double?,
      labelWeight: identical(labelWeight, _sentinel)
          ? this.labelWeight
          : labelWeight as int?,
    );
  }

  static const Object _sentinel = Object();
}

/// Elevation (shadow) tokens.
class ThemeElevations {
  const ThemeElevations({required this.sm, required this.md, required this.lg});

  const ThemeElevations.baseline() : sm = 1, md = 3, lg = 6;

  final double sm;
  final double md;
  final double lg;

  ThemeElevations copyWith({double? sm, double? md, double? lg}) {
    return ThemeElevations(
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
    );
  }
}

/// Visual effect tokens such as glass blur.
class ThemeEffects {
  const ThemeEffects({required this.blur, required this.glassOpacity});

  const ThemeEffects.baseline() : blur = 0, glassOpacity = 1;

  /// Backdrop blur sigma. Zero disables the glass effect entirely.
  final double blur;

  /// Opacity applied to translucent panels.
  final double glassOpacity;

  ThemeEffects copyWith({double? blur, double? glassOpacity}) {
    return ThemeEffects(
      blur: blur ?? this.blur,
      glassOpacity: glassOpacity ?? this.glassOpacity,
    );
  }
}

/// Background artwork configuration.
class ThemeBackground {
  const ThemeBackground({
    required this.image,
    required this.fillMode,
    required this.overlay,
    required this.overlayOpacity,
  });

  const ThemeBackground.baseline()
    : image = null,
      fillMode = ThemeBackgroundFillMode.cover,
      overlay = null,
      overlayOpacity = 0;

  /// Asset path resolved by the theme loader. Null means no artwork.
  final String? image;

  final ThemeBackgroundFillMode fillMode;

  /// Scrim drawn above the artwork to keep text legible.
  final Color? overlay;
  final double overlayOpacity;

  ThemeBackground copyWith({
    Object? image = _sentinel,
    ThemeBackgroundFillMode? fillMode,
    Object? overlay = _sentinel,
    double? overlayOpacity,
  }) {
    return ThemeBackground(
      image: identical(image, _sentinel) ? this.image : image as String?,
      fillMode: fillMode ?? this.fillMode,
      overlay: identical(overlay, _sentinel) ? this.overlay : overlay as Color?,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
    );
  }

  static const Object _sentinel = Object();
}

/// How background artwork fills its area.
enum ThemeBackgroundFillMode {
  cover,
  contain,
  stretch,
  tile;

  static ThemeBackgroundFillMode fromName(String? name) {
    return values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => ThemeBackgroundFillMode.cover,
    );
  }
}
