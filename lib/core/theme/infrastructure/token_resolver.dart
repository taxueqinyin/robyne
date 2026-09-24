import 'package:flutter/material.dart';

import '../domain/theme_components.dart';
import '../domain/theme_package.dart';
import '../domain/theme_tokens.dart';

/// Derives Flutter themes from [ThemeTokens].
///
/// This is the single place where Robin's semantic tokens become concrete
/// Flutter values. Widgets should read tokens through [RobyneTheme] rather
/// than guessing from `ThemeData`.
class TokenResolver {
  const TokenResolver();

  static const double _minScale = 0.75;
  static const double _maxScale = 1.5;

  /// Uses [value] only when it is actually opaque.
  ///
  /// Component colours default to fully transparent so a skin that omits them
  /// keeps the semantic colour; a transparent value here therefore means
  /// "unset", not "paint nothing".
  static Color _opaqueOr(Color value, Color fallback) {
    return value.a > 0 ? value : fallback;
  }

  /// The brightness a skin was authored for.
  ///
  /// `auto` skins are treated as light-authored, so their dark variant is
  /// derived rather than identical — otherwise flipping the system or user
  /// brightness would have no visible effect.
  static Brightness naturalBrightness(ThemeModePreference skinMode) {
    return switch (skinMode) {
      ThemeModePreference.dark => Brightness.dark,
      ThemeModePreference.light => Brightness.light,
      ThemeModePreference.auto => Brightness.light,
    };
  }

  /// Adapts [tokens] so [brightness] is actually visible to the user.
  ///
  /// When the requested brightness matches the skin's own mode the tokens are
  /// returned untouched, preserving the author's palette exactly. When they
  /// disagree, only the neutral surfaces and text are swapped for a legible
  /// baseline; brand colour, radii, effects and background artwork are kept so
  /// the skin still reads as itself.
  ThemeTokens adaptToBrightness(
    ThemeTokens tokens,
    Brightness brightness,
    ThemeModePreference skinMode,
  ) {
    if (brightness == naturalBrightness(skinMode)) {
      return tokens;
    }
    final reference = brightness == Brightness.light
        ? _lightNeutrals
        : _darkNeutrals;
    return tokens.copyWith(
      color: tokens.color.copyWith(
        backgroundBase: reference.backgroundBase,
        backgroundElevated: reference.backgroundElevated,
        backgroundSunken: reference.backgroundSunken,
        surfaceBase: reference.surfaceBase,
        surfaceHover: reference.surfaceHover,
        surfaceActive: reference.surfaceActive,
        surfaceSelected: reference.surfaceSelected,
        textPrimary: reference.textPrimary,
        textSecondary: reference.textSecondary,
        textMuted: reference.textMuted,
        textDisabled: reference.textDisabled,
        borderSubtle: reference.borderSubtle,
        borderDefault: reference.borderDefault,
        borderStrong: reference.borderStrong,
      ),
    );
  }

  /// Neutral palette used when a dark skin is forced into light mode.
  static final ThemeColors _lightNeutrals = ThemeColors.baseline();

  /// Neutral palette used when a light (or auto) skin renders in dark mode.
  static final ThemeColors _darkNeutrals = ThemeColors.baseline().copyWith(
    backgroundBase: const Color(0xFF14161A),
    backgroundElevated: const Color(0xFF1C1F24),
    backgroundSunken: const Color(0xFF0F1114),
    surfaceBase: const Color(0xFF1C1F24),
    surfaceHover: const Color(0x14FFFFFF),
    surfaceActive: const Color(0x1FFFFFFF),
    surfaceSelected: const Color(0xFF2B4A7A),
    textPrimary: const Color(0xFFE8EAED),
    textSecondary: const Color(0xFFA8AEB8),
    textMuted: const Color(0xFF7A8089),
    textDisabled: const Color(0xFF565B63),
    borderSubtle: const Color(0x0DFFFFFF),
    borderDefault: const Color(0x1AFFFFFF),
    borderStrong: const Color(0x29FFFFFF),
  );

  ThemeData resolve(
    ThemeTokens tokens,
    Brightness brightness, [
    ThemeModePreference skinMode = ThemeModePreference.auto,
  ]) {
    final adapted = adaptToBrightness(tokens, brightness, skinMode);
    final c = adapted.color;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.brandBase,
      onPrimary: c.onBrand,
      primaryContainer: c.brandMuted,
      onPrimaryContainer: c.textPrimary,
      secondary: c.brandHover,
      onSecondary: c.onBrand,
      surface: c.surfaceBase,
      onSurface: c.textPrimary,
      surfaceContainerHighest: c.backgroundSunken,
      onSurfaceVariant: c.textSecondary,
      outline: c.borderDefault,
      outlineVariant: c.borderSubtle,
      error: c.danger,
      onError: c.onBrand,
      scrim: c.backgroundOverlay,
    );

    final scale = tokens.typography.scale
        .clamp(_minScale, _maxScale)
        .toDouble();
    final family = tokens.typography.fontFamily;
    final textTheme = _textTheme(adapted, brightness, scale, family);
    final comp = tokens.components;

    final md = tokens.radius.md;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(md)),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.backgroundBase,
      canvasColor: c.backgroundElevated,
      cardColor: c.surfaceBase,
      dividerColor: c.borderSubtle,
      splashColor: c.surfaceHover,
      hoverColor: c.surfaceHover,
      focusColor: c.surfaceHover,
      highlightColor: c.surfaceActive,
      disabledColor: c.textDisabled,
      fontFamily: family,
      brightness: brightness,
      extensions: <ThemeExtension<dynamic>>[RobyneTheme(tokens)],
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: c.backgroundBase,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: tokens.elevation.sm,
      ),
      cardTheme: CardThemeData(
        color: comp.card.surface,
        elevation: tokens.elevation.sm,
        shape: shape,
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        textColor: c.textPrimary,
        iconColor: c.textSecondary,
        shape: shape,
        selectedColor: comp.list.itemSelected,
        selectedTileColor: comp.list.itemSelected,
      ),
      navigationRailTheme: NavigationRailThemeData(
        // A skin may tint the rail itself; transparent keeps the semantic
        // background, which is what skins authored before this token expect.
        backgroundColor: _opaqueOr(comp.navBar.background, c.backgroundBase),
        selectedIconTheme: IconThemeData(color: comp.navBar.selectedItem),
        selectedLabelTextStyle: TextStyle(
          color: comp.navBar.selectedItem,
          fontWeight: FontWeight.values[tokens.typography.titleWeight ~/ 100],
        ),
        unselectedIconTheme: IconThemeData(color: c.textSecondary),
        unselectedLabelTextStyle: TextStyle(color: c.textSecondary),
        indicatorColor: comp.navBar.selectedIndicator,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _opaqueOr(
          comp.navBar.background,
          c.backgroundElevated,
        ),
        indicatorColor: comp.navBar.selectedIndicator,
        elevation: tokens.elevation.md,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceBase,
        hintStyle: TextStyle(color: c.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(md)),
          borderSide: BorderSide(color: c.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(md)),
          borderSide: BorderSide(color: c.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(md)),
          borderSide: BorderSide(color: c.borderFocus, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.brandBase,
          foregroundColor: c.onBrand,
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.textPrimary,
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.borderDefault),
          shape: shape,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: comp.playerBar.progressActive,
        inactiveTrackColor: comp.playerBar.progressTrack,
        thumbColor: comp.playerBar.progressActive,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: comp.playerBar.progressActive,
        linearTrackColor: comp.playerBar.progressTrack,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.backgroundElevated,
        elevation: tokens.elevation.lg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(tokens.radius.lg)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.backgroundElevated,
        contentTextStyle: TextStyle(color: c.textPrimary),
        shape: shape,
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.backgroundElevated,
          borderRadius: BorderRadius.all(Radius.circular(tokens.radius.sm)),
        ),
        textStyle: TextStyle(color: c.textPrimary),
      ),
      dividerTheme: DividerThemeData(
        color: c.borderSubtle,
        thickness: 1,
        space: 1,
      ),
    );
  }

  TextTheme _textTheme(
    ThemeTokens tokens,
    Brightness brightness,
    double scale,
    String? family,
  ) {
    final base = brightness == Brightness.dark
        ? Typography.material2021().white.apply(fontFamily: family)
        : Typography.material2021().black.apply(fontFamily: family);
    final c = tokens.color;
    final sized = base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        color: c.textPrimary,
        fontSize: (base.displayLarge?.fontSize ?? 57) * scale,
        fontWeight: FontWeight.values[tokens.typography.titleWeight ~/ 100],
      ),
      displayMedium: base.displayMedium?.copyWith(
        color: c.textPrimary,
        fontSize: (base.displayMedium?.fontSize ?? 45) * scale,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        color: c.textPrimary,
        fontSize: (base.headlineMedium?.fontSize ?? 28) * scale,
        fontWeight: FontWeight.values[tokens.typography.titleWeight ~/ 100],
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: c.textPrimary,
        fontSize: (base.titleLarge?.fontSize ?? 22) * scale,
        fontWeight: FontWeight.values[tokens.typography.titleWeight ~/ 100],
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: c.textPrimary,
        fontSize: (base.titleMedium?.fontSize ?? 16) * scale,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        color: c.textPrimary,
        fontSize: (base.bodyLarge?.fontSize ?? 16) * scale,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        color: c.textSecondary,
        fontSize: (base.bodyMedium?.fontSize ?? 14) * scale,
      ),
      bodySmall: base.bodySmall?.copyWith(
        color: c.textMuted,
        fontSize: (base.bodySmall?.fontSize ?? 12) * scale,
      ),
      labelLarge: base.labelLarge?.copyWith(
        color: c.textPrimary,
        fontSize: (base.labelLarge?.fontSize ?? 14) * scale,
      ),
    );
    return sized;
  }
}

/// Exposes the active [ThemeTokens] to widgets through `Theme.of(context)`.
class RobyneTheme extends ThemeExtension<RobyneTheme> {
  const RobyneTheme(this.tokens);

  final ThemeTokens tokens;

  static RobyneTheme of(BuildContext context) {
    final extension = Theme.of(context).extension<RobyneTheme>();
    // Themes are always resolved through TokenResolver, but keep a safe
    // baseline for widgets rendered outside that pipeline (e.g. tests).
    return extension ?? const RobyneTheme(ThemeTokens.baseline());
  }

  /// Null-tolerant variant for widgets that may render before the theme is
  /// ready.
  static RobyneTheme? maybeOf(BuildContext context) {
    return Theme.of(context).extension<RobyneTheme>();
  }

  @override
  RobyneTheme copyWith({ThemeTokens? tokens}) {
    return RobyneTheme(tokens ?? this.tokens);
  }

  @override
  RobyneTheme lerp(covariant RobyneTheme? other, double t) {
    if (other == null) {
      return this;
    }
    return RobyneTheme(_lerpTokens(tokens, other.tokens, t));
  }

  static ThemeTokens _lerpTokens(ThemeTokens a, ThemeTokens b, double t) {
    return a.copyWith(
      color: _lerpColors(a.color, b.color, t),
      radius: _lerpRadii(a.radius, b.radius, t),
      spacing: _lerpSpacings(a.spacing, b.spacing, t),
      typography: a.typography.copyWith(
        scale: _lerpDouble(a.typography.scale, b.typography.scale, t),
      ),
      elevation: _lerpElevations(a.elevation, b.elevation, t),
      effects: a.effects.copyWith(
        blur: _lerpDouble(a.effects.blur, b.effects.blur, t),
        glassOpacity: _lerpDouble(
          a.effects.glassOpacity,
          b.effects.glassOpacity,
          t,
        ),
      ),
      components: ThemeComponents.lerp(a.components, b.components, t),
    );
  }

  static ThemeColors _lerpColors(ThemeColors a, ThemeColors b, double t) {
    return a.copyWith(
      backgroundBase: Color.lerp(a.backgroundBase, b.backgroundBase, t),
      backgroundElevated: Color.lerp(
        a.backgroundElevated,
        b.backgroundElevated,
        t,
      ),
      backgroundSunken: Color.lerp(a.backgroundSunken, b.backgroundSunken, t),
      backgroundOverlay: Color.lerp(
        a.backgroundOverlay,
        b.backgroundOverlay,
        t,
      ),
      surfaceBase: Color.lerp(a.surfaceBase, b.surfaceBase, t),
      surfaceHover: Color.lerp(a.surfaceHover, b.surfaceHover, t),
      surfaceActive: Color.lerp(a.surfaceActive, b.surfaceActive, t),
      surfaceSelected: Color.lerp(a.surfaceSelected, b.surfaceSelected, t),
      brandBase: Color.lerp(a.brandBase, b.brandBase, t),
      brandHover: Color.lerp(a.brandHover, b.brandHover, t),
      brandMuted: Color.lerp(a.brandMuted, b.brandMuted, t),
      onBrand: Color.lerp(a.onBrand, b.onBrand, t),
      textPrimary: Color.lerp(a.textPrimary, b.textPrimary, t),
      textSecondary: Color.lerp(a.textSecondary, b.textSecondary, t),
      textMuted: Color.lerp(a.textMuted, b.textMuted, t),
      textDisabled: Color.lerp(a.textDisabled, b.textDisabled, t),
      borderSubtle: Color.lerp(a.borderSubtle, b.borderSubtle, t),
      borderDefault: Color.lerp(a.borderDefault, b.borderDefault, t),
      borderStrong: Color.lerp(a.borderStrong, b.borderStrong, t),
      borderFocus: Color.lerp(a.borderFocus, b.borderFocus, t),
      danger: Color.lerp(a.danger, b.danger, t),
      warning: Color.lerp(a.warning, b.warning, t),
      success: Color.lerp(a.success, b.success, t),
    );
  }

  static ThemeRadii _lerpRadii(ThemeRadii a, ThemeRadii b, double t) {
    return a.copyWith(
      sm: _lerpDouble(a.sm, b.sm, t),
      md: _lerpDouble(a.md, b.md, t),
      lg: _lerpDouble(a.lg, b.lg, t),
      full: _lerpDouble(a.full, b.full, t),
    );
  }

  static ThemeSpacings _lerpSpacings(
    ThemeSpacings a,
    ThemeSpacings b,
    double t,
  ) {
    return a.copyWith(
      xs: _lerpDouble(a.xs, b.xs, t),
      sm: _lerpDouble(a.sm, b.sm, t),
      md: _lerpDouble(a.md, b.md, t),
      lg: _lerpDouble(a.lg, b.lg, t),
      xl: _lerpDouble(a.xl, b.xl, t),
    );
  }

  static ThemeElevations _lerpElevations(
    ThemeElevations a,
    ThemeElevations b,
    double t,
  ) {
    return a.copyWith(
      sm: _lerpDouble(a.sm, b.sm, t),
      md: _lerpDouble(a.md, b.md, t),
      lg: _lerpDouble(a.lg, b.lg, t),
    );
  }

  static double _lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }
}
