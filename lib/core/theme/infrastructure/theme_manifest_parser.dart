import 'dart:ui';

import '../domain/theme_components.dart';
import '../domain/theme_icons.dart';
import '../domain/theme_home.dart';
import '../domain/theme_layout.dart';
import '../domain/theme_navigation.dart';
import '../domain/theme_package.dart';
import '../domain/theme_regions.dart';
import '../domain/theme_strings.dart';
import '../domain/theme_tokens.dart';
import 'token_resolver.dart';
import 'theme_path_guard.dart';

/// Parses `theme.json` into a [ThemePackage].
///
/// The parser is deliberately permissive: an unknown or malformed field is
/// ignored and replaced by its baseline value rather than rejected. A broken
/// skin must degrade to "looks plain", never to "app has no theme at all".
class ThemeManifestParser {
  const ThemeManifestParser();

  /// Parses a decoded manifest.
  ///
  /// Returns `null` only when the payload is too broken to identify itself,
  /// in which case the caller falls back to the previously active skin.
  ThemePackage? tryParse(
    Object? raw, {
    required ThemeSource source,
    String? fallbackId,
  }) {
    if (raw is! Map) {
      return null;
    }
    final id = _readId(raw, fallbackId: fallbackId);
    if (id == null || id.isEmpty) {
      return null;
    }
    final tokensRaw = raw['tokens'];
    final assetsRaw = raw['assets'];

    return ThemePackage(
      id: id,
      name: _bounded(raw['name'], _maxShortText) ?? id,
      author: _bounded(raw['author'], _maxShortText) ?? '',
      authorUrl: _bounded(raw['authorUrl'], _maxLongText),
      version: _bounded(raw['version'], _maxShortText) ?? '0.0.0',
      description: _bounded(raw['description'], _maxLongText) ?? '',
      preview: _bounded(raw['preview'], _maxLongText),
      tags: _stringList(raw['tags']),
      mode: ThemeModePreference.fromName(_string(raw['mode'])),
      // Recorded so that when the token set grows, a skin authored against an
      // older schema can be told apart from a current one.
      schemaVersion: _schemaVersion(raw['schemaVersion']),
      tokens: _tokens(tokensRaw is Map ? tokensRaw : null),
      layout: _layout(raw['layout'] is Map ? raw['layout'] as Map : null),
      settings: _settings(raw['settings']),
      assets: _assets(
        assetsRaw is Map ? assetsRaw : null,
        iconFontFamily: _iconFontFamily(assetsRaw),
      ),
      // The whole `navigation` object goes through, not just `hidden`: the
      // hidden set and the overflow slot are one decision, and the parser is
      // the only layer that sees the raw JSON.
      navigation: ThemeNavigation.parse(raw['navigation']),
      // Screen untrusted text with this parser's own `_bounded`, so a manifest
      // is length-capped by one rule rather than by whichever reader it hit.
      strings: ThemeStrings.parse(
        raw['strings'],
        readText: _bounded,
        maxLength: _maxShortText,
      ),
      icons: ThemeIcons.parse(raw['icons']),
      source: source,
    );
  }

  /// Lowest schema version the parser understands; also assumed when a
  /// manifest omits the field.
  static const int _firstSchemaVersion = 1;

  /// Highest schema version the parser understands.
  static const int currentSchemaVersion = 1;

  static int _schemaVersion(Object? value) {
    final parsed = _double(value);
    if (parsed == null) {
      return _firstSchemaVersion;
    }
    // A skin from a newer schema is clamped down rather than rejected: the
    // parser already ignores fields it does not understand, so refusing the
    // whole skin would be a worse outcome for the user.
    return parsed.round().clamp(_firstSchemaVersion, currentSchemaVersion);
  }

  static String? _readId(Map raw, {String? fallbackId}) {
    final id = _string(raw['id']);
    if (id != null && id.isNotEmpty) {
      return id;
    }
    return fallbackId;
  }

  static ThemeTokens _tokens(Map? raw) {
    const baseline = ThemeTokens.baseline();
    if (raw == null) {
      return baseline;
    }
    final colorRaw = raw['color'];
    final radiusRaw = raw['radius'];
    final spacingRaw = raw['spacing'];
    final typographyRaw = raw['typography'];
    final elevationRaw = raw['elevation'];
    final effectsRaw = raw['effects'];
    final backgroundRaw = raw['background'];
    final componentsRaw = raw['components'];

    return baseline.copyWith(
      color: _colors(colorRaw is Map ? colorRaw : null),
      radius: _radii(radiusRaw is Map ? radiusRaw : null),
      spacing: _spacings(spacingRaw is Map ? spacingRaw : null),
      typography: _typography(typographyRaw is Map ? typographyRaw : null),
      elevation: _elevations(elevationRaw is Map ? elevationRaw : null),
      effects: _effects(effectsRaw is Map ? effectsRaw : null),
      background: _background(backgroundRaw is Map ? backgroundRaw : null),
      components: _components(componentsRaw is Map ? componentsRaw : null),
    );
  }

  static ThemeComponents _components(Map? raw) {
    const baseline = ThemeComponents.baseline();
    if (raw == null) {
      return baseline;
    }
    return baseline.copyWith(
      navBar: _navBar(raw['navBar'] is Map ? raw['navBar'] as Map : null),
      playerBar: _playerBar(
        raw['playerBar'] is Map ? raw['playerBar'] as Map : null,
      ),
      lyric: _lyric(raw['lyric'] is Map ? raw['lyric'] as Map : null),
      card: _card(raw['card'] is Map ? raw['card'] as Map : null),
      list: _list(raw['list'] is Map ? raw['list'] as Map : null),
      motion: _motion(raw['motion'] is Map ? raw['motion'] as Map : null),
      ambient: _ambient(raw['ambient'] is Map ? raw['ambient'] as Map : null),
      content: _contentMetrics(
        raw['content'] is Map ? raw['content'] as Map : null,
      ),
    );
  }

  /// Parses `components.content`, the content region's geometry.
  ///
  /// Bounded so a skin cannot make a row 4dp (untappable) or 400dp (one row
  /// per screen), and a gutter wide enough to leave no content column.
  static ThemeContentMetrics? _contentMetrics(Map? raw) {
    if (raw == null) {
      return null;
    }
    const base = ThemeContentMetrics.baseline();
    return base.copyWith(
      gutter: _doubleRangedOrNull(raw['gutter'], 0, 96),
      gutterCompact: _doubleRangedOrNull(raw['gutterCompact'], 0, 96),
      rowHeight: _doubleRangedOrNull(raw['rowHeight'], 32, 160),
      rowHeightCompact: _doubleRangedOrNull(raw['rowHeightCompact'], 32, 160),
      cardMinWidth: _doubleRangedOrNull(raw['cardMinWidth'], 80, 480),
      cardMinWidthCompact: _doubleRangedOrNull(
        raw['cardMinWidthCompact'],
        80,
        480,
      ),
      cardGap: _doubleRangedOrNull(raw['cardGap'], 0, 64),
      cardGapCompact: _doubleRangedOrNull(raw['cardGapCompact'], 0, 64),
      sectionGap: _doubleRangedOrNull(raw['sectionGap'], 0, 96),
      navIconSize: _doubleRangedOrNull(raw['navIconSize'], 12, 40),
      logoSize: _doubleRangedOrNull(raw['logoSize'], 12, 64),
      avatarSize: _doubleRangedOrNull(raw['avatarSize'], 16, 96),
    );
  }

  /// Parses `components.ambient`, the cover-driven wash from design §3.4.
  ///
  /// `strength` is clamped to the 0..0.6 the design allows: a wash strong
  /// enough to swallow the text would make every page unreadable, and the
  /// atmosphere layer is explicitly not allowed to decide readability.
  static ThemeAmbientComponents? _ambient(Map? raw) {
    if (raw == null) {
      return null;
    }
    const base = ThemeAmbientComponents.baseline();
    return base.copyWith(
      // `_bool` also accepts "true"/"false" strings, which is what a hand
      // edited manifest is most likely to contain.
      enabled: _bool(raw['enabled']),
      strength: _doubleRangedOrNull(raw['strength'], 0, 0.6),
      heightFraction: _doubleRangedOrNull(raw['heightFraction'], 0.05, 1),
      blur: _doubleRangedOrNull(raw['blur'], 0, 200),
      color: _color(raw['color']),
    );
  }

  /// Builds each component group from its own baseline, so a partial group
  /// keeps every field the skin did not mention.
  static ThemeNavBarComponents? _navBar(Map? raw) {
    if (raw == null) {
      return null;
    }
    const base = ThemeNavBarComponents.baseline();
    return base.copyWith(
      background: _color(raw['background']),
      gradient: _gradient(raw['gradient']),
      selectedItem: _color(raw['selectedItem']),
      selectedIndicator: _color(raw['selectedIndicator']),
      selectedIndicatorFill: _color(raw['selectedIndicatorFill']),
      showProfile: _bool(raw['showProfile']),
      showPlaylistGroup: _bool(raw['showPlaylistGroup']),
    );
  }

  static ThemePlayerBarComponents? _playerBar(Map? raw) {
    if (raw == null) {
      return null;
    }
    const base = ThemePlayerBarComponents.baseline();
    return base.copyWith(
      background: _color(raw['background']),
      gradient: _gradient(raw['gradient']),
      progressTrack: _color(raw['progressTrack']),
      progressActive: _color(raw['progressActive']),
    );
  }

  static ThemeLyricComponents? _lyric(Map? raw) {
    if (raw == null) {
      return null;
    }
    const base = ThemeLyricComponents.baseline();
    return base.copyWith(
      activeLine: _color(raw['activeLine']),
      inactiveLine: _color(raw['inactiveLine']),
      activeBackground: _color(raw['activeBackground']),
    );
  }

  static ThemeCardComponents? _card(Map? raw) {
    if (raw == null) {
      return null;
    }
    const base = ThemeCardComponents.baseline();
    return base.copyWith(
      surface: _color(raw['surface']),
      hover: _color(raw['hover']),
      selected: _color(raw['selected']),
    );
  }

  static ThemeListComponents? _list(Map? raw) {
    if (raw == null) {
      return null;
    }
    const base = ThemeListComponents.baseline();
    return base.copyWith(
      itemSelected: _color(raw['itemSelected']),
      itemHover: _color(raw['itemHover']),
    );
  }

  static ThemeMotionComponents? _motion(Map? raw) {
    if (raw == null) {
      return null;
    }
    const base = ThemeMotionComponents.baseline();
    return base.copyWith(
      shortDurationMs: _intRangedOrNull(
        raw['shortDurationMs'],
        ThemeMotionComponents.minDurationMs,
        ThemeMotionComponents.maxDurationMs,
      ),
      mediumDurationMs: _intRangedOrNull(
        raw['mediumDurationMs'],
        ThemeMotionComponents.minDurationMs,
        ThemeMotionComponents.maxDurationMs,
      ),
      curve: raw['curve'] == null
          ? null
          : ThemeMotionCurve.fromName(_string(raw['curve'])),
    );
  }

  /// Accepts either a colour literal or a list of stops.
  ///
  /// A single colour is the common case and is cheaper to author; stops are
  /// for skins that want a real gradient.
  static ThemeGradient _gradient(Object? raw) {
    if (raw == null) {
      return ThemeGradient.none;
    }
    if (raw is! List) {
      final solid = _color(raw);
      return solid == null ? ThemeGradient.none : ThemeGradient.solid(solid);
    }
    final stops = <ThemeGradientStop>[];
    for (final entry in raw.take(_maxGradientStops)) {
      if (entry is! Map) {
        continue;
      }
      final color = _color(entry['color']);
      if (color == null) {
        continue;
      }
      // Offsets outside 0..1 make Skia drop the whole frame, so they are
      // clamped rather than trusted.
      final offset = _ranged(entry['offset'] ?? entry['stop'], 0, 1) ?? 0;
      stops.add(ThemeGradientStop(color: color, offset: offset));
    }
    if (stops.isEmpty) {
      return ThemeGradient.none;
    }
    // A gradient with one stop is just a colour; keep it sortable so the
    // renderer can always assume ascending offsets.
    stops.sort((a, b) => a.offset.compareTo(b.offset));
    return ThemeGradient(stops: stops);
  }

  /// Caps the work a hostile manifest can create in the gradient painter.
  static const int _maxGradientStops = 8;

  /// Like [_ranged] but yields `null` when absent, so a partial group keeps
  /// the baseline for fields the skin did not mention.
  static int? _intRangedOrNull(Object? value, int min, int max) {
    final parsed = _ranged(value, min.toDouble(), max.toDouble());
    if (parsed == null) {
      return null;
    }
    return parsed.round().clamp(min, max);
  }

  /// Clamped double that stays `null` when the field is absent, so a partial
  /// component group keeps its baseline instead of snapping to zero.
  static double? _doubleRangedOrNull(Object? value, double min, double max) {
    final parsed = _ranged(value, min, max);
    return parsed?.clamp(min, max);
  }

  static ThemeLayout _layout(Map? raw) {
    const baseline = ThemeLayout.baseline();
    if (raw == null) {
      return baseline;
    }
    final desktopRaw = raw['desktop'];
    final mobileRaw = raw['mobile'];
    final contentRaw = raw['content'];
    final homeRaw = raw['home'];
    return baseline.copyWith(
      desktop: _desktopLayout(desktopRaw is Map ? desktopRaw : null),
      mobile: _mobileLayout(mobileRaw is Map ? mobileRaw : null),
      content: _contentLayout(contentRaw is Map ? contentRaw : null),
      // The whole `home` object goes through, not just `blocks`: a skin may
      // shape each form factor's composition independently, and the parser is
      // the only layer that sees the raw JSON.
      home: ThemeHomeLayout.parse(homeRaw),
    );
  }

  static ThemeDesktopLayout _desktopLayout(Map? raw) {
    const baseline = ThemeDesktopLayout.baseline();
    if (raw == null) {
      return baseline;
    }
    return baseline.copyWith(
      arrangement: RobyneArrangement.parse(
        raw['arrangement'],
        formFactor: RobyneFormFactor.desktop,
      ),
    );
  }

  static ThemeMobileLayout _mobileLayout(Map? raw) {
    const baseline = ThemeMobileLayout.baseline();
    if (raw == null) {
      return baseline;
    }
    return baseline.copyWith(
      arrangement: RobyneArrangement.parse(
        raw['arrangement'],
        formFactor: RobyneFormFactor.mobile,
      ),
    );
  }

  static ThemeContentLayout _contentLayout(Map? raw) {
    const baseline = ThemeContentLayout.baseline();
    if (raw == null) {
      return baseline;
    }
    return baseline.copyWith(
      listStyle: ThemeListStyle.fromName(_string(raw['listStyle'])),
      density: ThemeDensity.fromName(_string(raw['density'])),
      styles: _contentStyles(raw['styles']),
    );
  }

  /// Parses `layout.content.styles`, the per-destination presentation map.
  ///
  /// The design's §2.5 table is per surface ("本地库 uses `list`, 发现页 uses
  /// `grid`"), so a single global `listStyle` could not express it. Unknown
  /// destinations and values are dropped, which keeps a skin written for a
  /// newer app from breaking an older one.
  static Map<ThemeContentSurface, ThemeListStyle> _contentStyles(Object? raw) {
    if (raw is! Map) {
      return const <ThemeContentSurface, ThemeListStyle>{};
    }
    final styles = <ThemeContentSurface, ThemeListStyle>{};
    raw.forEach((rawKey, rawValue) {
      final surface = ThemeContentSurface.fromJsonName(
        rawKey?.toString().trim(),
      );
      if (surface == null) {
        return;
      }
      final name = _string(rawValue);
      if (name == null) {
        return;
      }
      // Only accept a value the enum actually knows: `fromName` silently
      // falls back to `list`, which would turn a typo into a real override.
      for (final style in ThemeListStyle.values) {
        if (style.name == name) {
          styles[surface] = style;
          return;
        }
      }
    });
    return Map<ThemeContentSurface, ThemeListStyle>.unmodifiable(styles);
  }

  static bool? _bool(Object? value) {
    if (value is bool) {
      return value;
    }
    final text = value?.toString().trim().toLowerCase();
    if (text == 'true') {
      return true;
    }
    if (text == 'false') {
      return false;
    }
    return null;
  }

  static ThemeColors _colors(Map? raw) {
    const baseline = ThemeColors.baseline();
    if (raw == null) {
      return baseline;
    }
    final bg = raw['background'];
    final surface = raw['surface'];
    final brand = raw['brand'];
    final accent = raw['accent'];
    final text = raw['text'];
    final border = raw['border'];
    final status = raw['status'];

    // A skin may declare `accent.base` without a companion `onAccent`. The
    // readable foreground is derived rather than left as white, because half
    // of the interesting accent colours are pale yellows and mint greens.
    final accentBase = _color(_group(accent, 'base'));

    return baseline.copyWith(
      backgroundBase: _color(_group(bg, 'base')),
      backgroundElevated: _color(_group(bg, 'elevated')),
      backgroundSunken: _color(_group(bg, 'sunken')),
      backgroundOverlay: _color(_group(bg, 'overlay')),
      surfaceBase: _color(_group(surface, 'base')),
      surfaceHover: _color(_group(surface, 'hover')),
      surfaceActive: _color(_group(surface, 'active')),
      surfaceSelected: _color(_group(surface, 'selected')),
      brandBase: _color(_group(brand, 'base')),
      brandHover: _color(_group(brand, 'hover')),
      brandMuted: _color(_group(brand, 'muted')),
      onBrand: _color(_group(brand, 'onBrand')),
      accentBase: accentBase,
      accentMuted: _color(_group(accent, 'muted')),
      onAccent:
          _color(_group(accent, 'onAccent')) ??
          (accentBase == null ? null : TokenResolver.contrastOn(accentBase)),
      textPrimary: _color(_group(text, 'primary')),
      textSecondary: _color(_group(text, 'secondary')),
      textMuted: _color(_group(text, 'muted')),
      textDisabled: _color(_group(text, 'disabled')),
      borderSubtle: _color(_group(border, 'subtle')),
      borderDefault: _color(_group(border, 'default')),
      borderStrong: _color(_group(border, 'strong')),
      borderFocus: _color(_group(border, 'focus')),
      danger: _color(_group(status, 'danger')),
      warning: _color(_group(status, 'warning')),
      success: _color(_group(status, 'success')),
    );
  }

  static ThemeRadii _radii(Map? raw) {
    const baseline = ThemeRadii.baseline();
    if (raw == null) {
      return baseline;
    }
    return baseline.copyWith(
      sm: _ranged(raw['sm'], 0, 200),
      md: _ranged(raw['md'], 0, 200),
      lg: _ranged(raw['lg'], 0, 200),
      full: _ranged(raw['full'], 0, 4096),
    );
  }

  static ThemeSpacings _spacings(Map? raw) {
    const baseline = ThemeSpacings.baseline();
    if (raw == null) {
      return baseline;
    }
    return baseline.copyWith(
      xs: _ranged(raw['xs'], 0, 200),
      sm: _ranged(raw['sm'], 0, 200),
      md: _ranged(raw['md'], 0, 200),
      lg: _ranged(raw['lg'], 0, 200),
      xl: _ranged(raw['xl'], 0, 200),
    );
  }

  static ThemeTypography _typography(Map? raw) {
    const baseline = ThemeTypography.baseline();
    if (raw == null) {
      return baseline;
    }
    final family = _fontFamily(raw['family']);
    final scale = _ranged(raw['scale'], 0.75, 1.5);
    return baseline.copyWith(
      fontFamily: family,
      scale: scale,
      bodyWeight: _weight(raw['bodyWeight']),
      titleWeight: _weight(raw['titleWeight']),
      // Bounded to a range that can still be laid out: 8dp is unreadable and
      // 96dp would swallow any panel the app can draw.
      pageTitleSize: _doubleRangedOrNull(raw['pageTitleSize'], 8, 96),
      sectionTitleSize: _doubleRangedOrNull(raw['sectionTitleSize'], 8, 96),
      listPrimarySize: _doubleRangedOrNull(raw['listPrimarySize'], 8, 96),
      listSecondarySize: _doubleRangedOrNull(raw['listSecondarySize'], 8, 96),
      labelSize: _doubleRangedOrNull(raw['labelSize'], 8, 96),
      labelWeight: _weight(raw['labelWeight']),
    );
  }

  /// Font families are passed to the platform text engine, so anything that
  /// is not a plain family name is dropped.
  static String? _fontFamily(Object? value) {
    final text = _bounded(value, _maxShortText);
    if (text == null) {
      return null;
    }
    return RegExp(r'^[A-Za-z0-9 _-]+$').hasMatch(text) ? text : null;
  }

  static ThemeElevations _elevations(Map? raw) {
    const baseline = ThemeElevations.baseline();
    if (raw == null) {
      return baseline;
    }
    return baseline.copyWith(
      sm: _ranged(raw['sm'], 0, 64),
      md: _ranged(raw['md'], 0, 64),
      lg: _ranged(raw['lg'], 0, 64),
    );
  }

  static ThemeEffects _effects(Map? raw) {
    const baseline = ThemeEffects.baseline();
    if (raw == null) {
      return baseline;
    }
    final blur = _double(raw['blur']);
    final opacity = _double(raw['glassOpacity']);
    return baseline.copyWith(
      blur: blur?.clamp(0, 40).toDouble(),
      glassOpacity: opacity?.clamp(0, 1).toDouble(),
    );
  }

  static ThemeBackground _background(Map? raw) {
    const baseline = ThemeBackground.baseline();
    if (raw == null) {
      return baseline;
    }
    final opacity = _ranged(raw['overlayOpacity'], 0, 1);
    return baseline.copyWith(
      image: ThemePathGuard.sanitizeAsset(_bounded(raw['image'], 256)),
      fillMode: ThemeBackgroundFillMode.fromName(_string(raw['fillMode'])),
      overlay: _color(raw['overlay']),
      overlayOpacity: opacity,
    );
  }

  static ThemeAssets _assets(Map? raw, {String? iconFontFamily}) {
    const baseline = ThemeAssets.empty();
    if (raw == null) {
      return baseline.copyWith(iconFontFamily: iconFontFamily);
    }
    final iconsRaw = _group(raw, 'icons');
    final iconFont = iconsRaw is Map ? iconsRaw['font'] : null;
    return baseline.copyWith(
      background: ThemePathGuard.sanitizeAsset(
        _bounded(raw['background'], 256),
      ),
      font: ThemePathGuard.sanitizeAsset(_bounded(raw['font'], 256)),
      logo: ThemePathGuard.sanitizeAsset(_bounded(raw['logo'], 256)),
      avatar: ThemePathGuard.sanitizeAsset(_bounded(raw['avatar'], 256)),
      hero: ThemePathGuard.sanitizeAsset(_bounded(raw['hero'], 256)),
      iconFont: ThemePathGuard.sanitizeAsset(_bounded(iconFont, 256)),
      // The namespaced name always wins over the declared one: a skin may
      // call its set "MaterialIcons" for authoring convenience, but it must
      // not be able to *be* MaterialIcons and shadow the app's own glyphs.
      iconFontFamily: iconFontFamily,
    );
  }

  /// The deterministic icon-font family for a skin that ships one.
  ///
  /// Stores the *declared* name verbatim (screened by [_sanitizeFamily]), not
  /// the final namespaced family: `ThemePackage.iconsFontFamily` composes the
  /// namespace, and it is the one place both the loader and the renderer read.
  /// Pre-namespacing here made the loader namespace it a second time.
  static String? _iconFontFamily(Object? assetsRaw) {
    if (assetsRaw is! Map) {
      return null;
    }
    final iconsRaw = _group(assetsRaw, 'icons');
    if (iconsRaw is! Map) {
      return null;
    }
    final font = _bounded(iconsRaw['font'], 256);
    if (font == null || font.isEmpty) {
      return null;
    }
    return _sanitizeFamily(_bounded(iconsRaw['fontFamily'], 128));
  }

  /// Restricts an icon-font family name to a safe identifier.
  ///
  /// Falls back to null (the package id) when the declaration is unusable, so
  /// two skins can never claim the same family and a malformed name cannot
  /// reach the font loader.
  static String? _sanitizeFamily(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    if (!RegExp(r'^[A-Za-z0-9_\- ]{1,64}$').hasMatch(text)) {
      return null;
    }
    return text;
  }

  static List<ThemeSetting> _settings(Object? raw) {
    if (raw is! List) {
      return const <ThemeSetting>[];
    }
    final settings = <ThemeSetting>[];
    for (final entry in raw) {
      final setting = ThemeSetting.tryParse(entry);
      if (setting != null) {
        settings.add(setting);
      }
    }
    return List<ThemeSetting>.unmodifiable(settings);
  }

  static Object? _group(Object? raw, String key) {
    if (raw is! Map) {
      return null;
    }
    return raw[key];
  }

  /// Caps on free text so a hostile manifest cannot blow up layout or memory.
  static const int _maxShortText = 64;
  static const int _maxLongText = 256;

  static String? _string(Object? value) {
    final text = _bounded(value, _maxShortText);
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  /// Trims and length-caps a value that came from an untrusted manifest.
  ///
  /// Maps and lists are rejected outright: stringifying an arbitrarily deep
  /// structure is unbounded work, and no text field needs one.
  static String? _bounded(Object? value, int maxLength) {
    if (value == null) {
      return null;
    }
    if (value is! String && value is! num && value is! bool) {
      return null;
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return text.length > maxLength ? text.substring(0, maxLength) : text;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((item) => _bounded(item, _maxShortText))
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .take(16)
        .toList(growable: false);
  }

  /// Largest absolute value accepted for a free-form numeric token.
  static const double _maxMagnitude = 4096;

  static double? _double(Object? value) {
    if (value is num) {
      return _finite(value.toDouble());
    }
    return _finite(double.tryParse(value?.toString() ?? ''));
  }

  /// Rejects `Infinity` / `NaN`, which `double.tryParse('1e999')` happily
  /// produces. Non-finite radii and heights reach Skia and corrupt the whole
  /// frame, so they never enter the model.
  static double? _finite(double? value) {
    if (value == null || !value.isFinite) {
      return null;
    }
    if (value.abs() > _maxMagnitude) {
      return null;
    }
    return value;
  }

  /// Clamps a parsed number into [min]..[max].
  static double? _ranged(Object? value, double min, double max) {
    final parsed = _finite(_double(value));
    if (parsed == null) {
      return null;
    }
    return parsed.clamp(min, max).toDouble();
  }

  static int? _weight(Object? value) {
    final parsed = _double(value);
    if (parsed == null) {
      return null;
    }
    return parsed.round().clamp(100, 900);
  }

  /// Accepts `#RGB`, `#RRGGBB`, `#AARRGGBB` and plain integers.
  static Color? _color(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return Color(value);
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    if (text.startsWith('#')) {
      final hex = text.substring(1);
      final buffer = StringBuffer();
      if (hex.length == 3) {
        buffer.write('FF');
        for (final unit in hex.split('')) {
          buffer.write(unit * 2);
        }
      } else if (hex.length == 6) {
        buffer.write('FF$hex');
      } else if (hex.length == 8) {
        buffer.write(hex);
      } else {
        return null;
      }
      final parsed = int.tryParse(buffer.toString(), radix: 16);
      return parsed == null ? null : Color(parsed);
    }
    final numeric = int.tryParse(text);
    return numeric == null ? null : Color(numeric);
  }
}
