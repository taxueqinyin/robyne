import 'theme_layout.dart';
import 'theme_navigation.dart';
import 'theme_icons.dart';
import 'theme_strings.dart';
import 'theme_tokens.dart';

/// A skin package: metadata plus the tokens it declares.
///
/// Skins are pure data. There is no executable code in a skin, which is why
/// they can be imported, listed and applied without any trust prompt.
class ThemePackage {
  const ThemePackage({
    required this.id,
    required this.name,
    required this.author,
    required this.authorUrl,
    required this.version,
    required this.description,
    required this.preview,
    required this.tags,
    required this.mode,
    required this.schemaVersion,
    required this.tokens,
    required this.layout,
    required this.settings,
    required this.assets,
    this.navigation = const ThemeNavigation.empty(),
    this.strings = const ThemeStrings.empty(),
    this.icons = ThemeIcons.empty,
    required this.source,
  });

  final String id;
  final String name;
  final String author;
  final String? authorUrl;
  final String version;
  final String description;

  /// Either an asset path inside the package or a CSS-like colour literal.
  final String? preview;

  final List<String> tags;

  /// Preferred brightness. The user can still override it in settings.
  final ThemeModePreference mode;

  /// Manifest schema the skin was authored against.
  ///
  /// Recorded so the token set can evolve: a future migration can tell an
  /// old skin apart from a current one instead of guessing. Parsing itself is
  /// unaffected — the parser ignores unknown fields either way.
  final int schemaVersion;

  final ThemeTokens tokens;

  /// Declarative shell shape, split by form factor.
  final ThemeLayout layout;

  /// User-facing knobs declared by the skin, rendered as sliders/colour
  /// pickers in the settings page so non-technical users can tweak a skin
  /// without editing JSON.
  final List<ThemeSetting> settings;

  final ThemeAssets assets;

  /// Navigation entries this skin chooses not to render.
  ///
  /// Empty means "render every destination", which is every skin that predates
  /// the field.
  final ThemeNavigation navigation;

  /// Chrome text the skin renames, e.g. the navigation labels.
  ///
  /// Empty means "use the app's default wording", which is every skin that
  /// predates the field.
  final ThemeStrings strings;

  /// Chrome glyphs the skin redraws, e.g. the rail and transport icons.
  ///
  /// Empty means "keep every built-in glyph", which is every skin that
  /// predates the field.
  final ThemeIcons icons;

  /// Where this package came from, used by the UI to offer deletion.
  final ThemeSource source;

  /// The font family a skin's `glyph` declarations index into.
  ///
  /// Null when the skin ships no icon font, in which case `glyph`
  /// declarations fall through to the built-in glyph.
  ///
  /// This is the **single source of truth** for the name: the loader registers
  /// the font under exactly this string and the widget renders with it. When
  /// both sides computed their own, they disagreed — the parser produced
  /// `robyne_builtin_x_icons_MySet` and the loader wrapped it a second time,
  /// so the font registered under a name nothing rendered with.
  String? get iconsFontFamily {
    final font = assets.iconFont;
    if (font == null || font.isEmpty) {
      return null;
    }
    final suffix = source == ThemeSource.builtIn ? 'builtin' : 'user';
    final safeId = id.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final base = 'robyne_${suffix}_${safeId}_icons';
    final declared = assets.iconFontFamily?.trim();
    if (declared == null || declared.isEmpty) {
      return base;
    }
    // The declared name is still namespaced: a skin may call its set
    // "MaterialIcons" for authoring convenience, but it must not be able to
    // *be* MaterialIcons and shadow the app's own glyphs.
    return '${base}_${declared.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}';
  }

  ThemePackage copyWith({
    String? id,
    String? name,
    String? author,
    String? authorUrl,
    String? version,
    String? description,
    String? preview,
    List<String>? tags,
    ThemeModePreference? mode,
    int? schemaVersion,
    ThemeTokens? tokens,
    ThemeLayout? layout,
    List<ThemeSetting>? settings,
    ThemeAssets? assets,
    ThemeNavigation? navigation,
    ThemeStrings? strings,
    ThemeIcons? icons,
    ThemeSource? source,
  }) {
    return ThemePackage(
      id: id ?? this.id,
      name: name ?? this.name,
      author: author ?? this.author,
      authorUrl: authorUrl ?? this.authorUrl,
      version: version ?? this.version,
      description: description ?? this.description,
      preview: preview ?? this.preview,
      tags: tags ?? this.tags,
      mode: mode ?? this.mode,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      tokens: tokens ?? this.tokens,
      layout: layout ?? this.layout,
      settings: settings ?? this.settings,
      assets: assets ?? this.assets,
      navigation: navigation ?? this.navigation,
      strings: strings ?? this.strings,
      icons: icons ?? this.icons,
      source: source ?? this.source,
    );
  }
}

/// Files shipped alongside `theme.json`.
class ThemeAssets {
  const ThemeAssets({
    required this.background,
    required this.font,
    this.logo,
    this.avatar,
    this.hero,
    this.iconFont,
    this.iconFontFamily,
  });

  const ThemeAssets.empty()
    : background = null,
      font = null,
      logo = null,
      avatar = null,
      hero = null,
      iconFont = null,
      iconFontFamily = null;

  final String? background;
  final String? font;

  /// Brand mark shown at the top of the navigation rail.
  final String? logo;

  /// Default profile image shown in the user block.
  final String? avatar;

  /// Hero artwork for the flagship home banner.
  final String? hero;

  /// An icon font the skin ships, so `icons.glyph` declarations can index a
  /// real icon set instead of Material's.
  final String? iconFont;

  /// Family name to register [iconFont] under.
  ///
  /// A skin ships the file; the family name is what `IconData(fontFamily:)`
  /// needs, and it cannot be read from a `.ttf` without parsing it, so the
  /// skin declares it. Falls back to the skin id when omitted, which keeps
  /// two skins' icon fonts from colliding.
  final String? iconFontFamily;

  ThemeAssets copyWith({
    Object? background = _sentinel,
    Object? font = _sentinel,
    Object? logo = _sentinel,
    Object? avatar = _sentinel,
    Object? hero = _sentinel,
    Object? iconFont = _sentinel,
    Object? iconFontFamily = _sentinel,
  }) {
    return ThemeAssets(
      background: identical(background, _sentinel)
          ? this.background
          : background as String?,
      font: identical(font, _sentinel) ? this.font : font as String?,
      logo: identical(logo, _sentinel) ? this.logo : logo as String?,
      avatar: identical(avatar, _sentinel) ? this.avatar : avatar as String?,
      hero: identical(hero, _sentinel) ? this.hero : hero as String?,
      iconFont: identical(iconFont, _sentinel)
          ? this.iconFont
          : iconFont as String?,
      iconFontFamily: identical(iconFontFamily, _sentinel)
          ? this.iconFontFamily
          : iconFontFamily as String?,
    );
  }

  static const Object _sentinel = Object();
}

/// Where a theme package was loaded from.
enum ThemeSource { builtIn, user }

/// Brightness preference declared by a skin.
enum ThemeModePreference {
  light,
  dark,
  auto;

  static ThemeModePreference fromName(String? name) {
    return values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => ThemeModePreference.auto,
    );
  }
}

/// A single user-adjustable knob exposed by a skin.
///
/// Declared in `theme.json` as:
/// ```json
/// { "key": "blurAmount", "type": "range", "label": "模糊程度",
///   "min": 0, "max": 40, "default": 12 }
/// ```
class ThemeSetting {
  const ThemeSetting({
    required this.key,
    required this.type,
    required this.label,
    required this.defaultValue,
    this.min,
    this.max,
    this.options,
    this.target,
  });

  final String key;
  final ThemeSettingType type;
  final String label;
  final Object defaultValue;

  /// Inclusive bounds for `range` settings.
  final num? min;
  final num? max;

  /// Allowed values for `select` settings.
  final List<String>? options;

  /// Dotted token path this knob writes to, e.g. `effects.blur`.
  final String? target;

  static ThemeSetting? tryParse(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final key = raw['key']?.toString().trim();
    if (key == null || key.isEmpty) {
      return null;
    }
    final type = ThemeSettingType.fromName(raw['type']?.toString());
    final label = raw['label']?.toString().trim();
    final defaultRaw = raw['default'];
    if (defaultRaw == null) {
      return null;
    }
    return ThemeSetting(
      key: key,
      type: type,
      label: label ?? key,
      defaultValue: defaultRaw,
      min: raw['min'] is num ? raw['min'] as num : null,
      max: raw['max'] is num ? raw['max'] as num : null,
      options: (raw['options'] as List?)
          ?.map((item) => item.toString())
          .toList(growable: false),
      target: raw['target']?.toString().trim(),
    );
  }

  ThemeSetting copyWith({Object? defaultValue}) {
    return ThemeSetting(
      key: key,
      type: type,
      label: label,
      defaultValue: defaultValue ?? this.defaultValue,
      min: min,
      max: max,
      options: options,
      target: target,
    );
  }
}

/// The kind of control rendered for a [ThemeSetting].
enum ThemeSettingType {
  range,
  color,
  toggle,
  text,
  select;

  static ThemeSettingType fromName(String? name) {
    return values.firstWhere(
      (type) => type.name == name,
      orElse: () => ThemeSettingType.text,
    );
  }
}
