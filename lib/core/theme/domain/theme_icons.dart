/// Icons a skin may replace.
///
/// Icons are the last piece of chrome the app still hardcoded: a rail row, a
/// transport button and a tab are all `Icons.something` literals in the shell,
/// so a skin could recolour them but never *redraw* them. That caps how far a
/// skin can differentiate itself — every skin ends up with the same Material
/// glyphs wearing different colours, which is the "换色不换形" ceiling.
///
/// The slot set is closed, for the same reason [ThemeStringKey] and
/// [ThemeNavEntry] are:
///
/// - a skin can only restyle icons the app actually draws. Letting a skin
///   invent slots would mean either ignoring them silently or letting a skin
///   place glyphs the app has nowhere to put
/// - a missing or unresolvable declaration falls back to the built-in glyph,
///   so a broken icon never costs the user a control. An icon is not
///   decoration: the play button has to stay findable
/// - unknown names are ignored, so a skin authored against a newer app cannot
///   break an older one
///
/// Three ways to declare an icon, in increasing fidelity:
///
/// - `codePoint` — a code point in a Material-style icon font. Cheapest: a
///   skin that only wants a differently shaped play key changes one number
/// - `glyph` — a code point in a *font the skin ships*, which is how a skin
///   brings a real icon set (Lucide, Remix, or a bespoke one)
/// - `image` — a raster shipped by the skin, for marks a font cannot express
library;

import 'package:flutter/widgets.dart';

/// The icon slots a skin may restyle.
enum ThemeIconKey {
  search('search'),
  discover('discover'),
  library('library'),
  nowPlaying('nowPlaying'),
  playlists('playlists'),
  downloads('downloads'),
  plugins('plugins'),
  settings('settings'),
  more('more'),
  back('back'),
  like('like'),
  play('play'),
  pause('pause'),
  skipNext('skipNext'),
  skipPrevious('skipPrevious'),
  queue('queue'),
  volume('volume'),
  lyric('lyric');

  const ThemeIconKey(this.jsonName);

  /// The name a skin writes in `theme.json`.
  final String jsonName;

  static ThemeIconKey? fromJsonName(String? name) {
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

/// One icon declaration.
///
/// At most one of [codePoint], [glyph] or [image] is set; the parser keeps the
/// first one a skin actually declares and ignores the rest, so a skin cannot
/// ask for two conflicting renderers.
class ThemeIcon {
  const ThemeIcon({
    this.codePoint,
    this.fontFamily,
    this.glyph,
    this.image,
    this.size,
    this.color,
    this.activeCodePoint,
    this.activeGlyph,
    this.activeImage,
    this.activeColor,
  });

  /// A code point in [fontFamily], or in the platform icon font when
  /// [fontFamily] is null.
  final int? codePoint;

  /// The font family [codePoint] indexes into.
  final String? fontFamily;

  /// A code point in the skin's own icon font.
  final int? glyph;

  /// A raster asset shipped by the skin.
  final String? image;

  /// Optional per-icon size override, in logical pixels.
  ///
  /// Null means "whatever the surface already decided", which is what keeps a
  /// declared icon from breaking a dense row it does not know about.
  final double? size;

  /// Optional per-icon colour override.
  final Color? color;

  /// Glyphs for the selected/active state.
  ///
  /// Rails, tabs and the like toggle between an outline and a filled shape to
  /// say "you are here". A skin that declares only one glyph would flatten
  /// that distinction, so each of the three renderers has an `active` twin.
  /// Left unset, the active state reuses the normal one — which is the right
  /// default for a skin whose icon font has no filled variant.
  final int? activeCodePoint;
  final int? activeGlyph;
  final String? activeImage;

  /// Colour for the active state, e.g. a brand tint on the selected tab.
  final Color? activeColor;

  /// True when there is nothing to render and the built-in glyph must stay.
  bool get isEmpty =>
      codePoint == null && glyph == null && (image?.trim().isEmpty ?? true);

  /// The code point to draw, honouring [active] and the declared form.
  ///
  /// A skin that declares *only* an active variant still works: the normal
  /// state falls back to it rather than to Material, since the author clearly
  /// meant this slot to use their artwork.
  int? codePointFor({required bool active}) {
    if (active) {
      return activeGlyph ?? activeCodePoint ?? glyph ?? codePoint;
    }
    return glyph ?? codePoint ?? activeGlyph ?? activeCodePoint;
  }

  /// The image to draw, honouring [active].
  String? imageFor({required bool active}) {
    if (active) {
      return activeImage ?? image;
    }
    return image ?? activeImage;
  }

  /// Whether [codePointFor] resolves through the skin's icon font.
  bool usesIconFont({required bool active}) {
    if (active && activeGlyph != null) {
      return true;
    }
    return glyph != null;
  }

  /// The colour to paint, honouring [active].
  Color? colorFor({required bool active}) =>
      (active ? activeColor : null) ?? color;

  /// True when [active] resolves to a glyph rather than an image.
  bool hasGlyph({required bool active}) => codePointFor(active: active) != null;

  /// True when [active] resolves to anything at all.
  bool isRenderable({required bool active}) {
    return codePointFor(active: active) != null ||
        (imageFor(active: active)?.trim().isNotEmpty ?? false);
  }
}

/// The icon declarations in effect for a skin.
///
/// Empty means "every slot keeps its built-in glyph", which is every skin
/// that predates the field.
class ThemeIcons {
  const ThemeIcons({this.icons = const <ThemeIconKey, ThemeIcon>{}});

  static const ThemeIcons empty = ThemeIcons();

  final Map<ThemeIconKey, ThemeIcon> icons;

  bool get isEmpty => icons.isEmpty;

  /// The declaration for [key], or null to keep the built-in glyph.
  ThemeIcon? operator [](ThemeIconKey key) => icons[key];

  /// Parses the manifest's `icons` object.
  ///
  /// Accepts either `{"play": 0xE037}` for a bare code point or the full
  /// object form `{"play": {"glyph": "0xE037", "size": 20}}`.
  static ThemeIcons parse(Object? raw) {
    if (raw is! Map) {
      return ThemeIcons.empty;
    }
    final parsed = <ThemeIconKey, ThemeIcon>{};
    raw.forEach((rawKey, rawValue) {
      final key = ThemeIconKey.fromJsonName(rawKey?.toString().trim());
      if (key == null) {
        return;
      }
      final icon = _parseIcon(rawValue);
      // Keep the declaration if *either* state is renderable: a skin may
      // legitimately declare only `activeGlyph` (the slot is always shown
      // selected) and dropping it would silently discard its artwork.
      if (icon != null &&
          (icon.isRenderable(active: false) ||
              icon.isRenderable(active: true))) {
        parsed[key] = icon;
      }
    });
    return ThemeIcons(icons: parsed);
  }

  static ThemeIcon? _parseIcon(Object? raw) {
    if (raw is Map) {
      final codePoint = _codePoint(raw['codePoint'] ?? raw['codepoint']);
      final glyph = _codePoint(raw['glyph']);
      final image = raw['image']?.toString().trim();
      final activeCodePoint = _codePoint(
        raw['activeCodePoint'] ?? raw['activeCodepoint'],
      );
      final activeGlyph = _codePoint(raw['activeGlyph']);
      final activeImage = raw['activeImage']?.toString().trim();
      final fontFamily = raw['fontFamily']?.toString().trim();
      final size = _double(raw['size']);
      final color = _color(raw['color']);
      return ThemeIcon(
        codePoint: codePoint,
        fontFamily: fontFamily,
        glyph: glyph,
        image: image?.isEmpty ?? true ? null : image,
        size: size,
        color: color,
        activeCodePoint: activeCodePoint,
        activeGlyph: activeGlyph,
        activeImage: activeImage?.isEmpty ?? true ? null : activeImage,
        activeColor: _color(raw['activeColor']),
      );
    }
    // Bare form: `{"play": 57431}` or `{"play": "0xE037"}`.
    return ThemeIcon(codePoint: _codePoint(raw));
  }

  /// Accepts `57431`, `"0xE037"`, `"E037"` and `"57431"`.
  ///
  /// Hex strings are what an icon-font cheat sheet actually publishes, so
  /// requiring decimal would force every author through a conversion.
  static int? _codePoint(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is int) {
      return raw >= 0 ? raw : null;
    }
    final text = raw.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    final lowered = text.toLowerCase();
    final hex = lowered.startsWith('0x') ? lowered.substring(2) : lowered;
    final isHex =
        RegExp(r'^[0-9a-f]+$').hasMatch(hex) &&
        (lowered.startsWith('0x') || RegExp(r'^[a-f]').hasMatch(hex));
    final parsed = isHex ? int.tryParse(hex, radix: 16) : int.tryParse(text);
    if (parsed == null || parsed < 0) {
      return null;
    }
    return parsed;
  }

  static double? _double(Object? raw) {
    if (raw is num) {
      return raw.toDouble();
    }
    return double.tryParse(raw?.toString().trim() ?? '');
  }

  static Color? _color(Object? raw) {
    if (raw is! String) {
      return null;
    }
    final text = raw.trim();
    // `#AARRGGBB` or `#RRGGBB`, the form the rest of the manifest uses.
    final hex = text.startsWith('#') ? text.substring(1) : text;
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
      return null;
    }
    if (hex.length == 6) {
      return Color(0xFF000000 | int.parse(hex, radix: 16));
    }
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return null;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      for (final entry in icons.entries)
        entry.key.jsonName: <String, Object?>{
          if (entry.value.codePoint != null) 'codePoint': entry.value.codePoint,
          if (entry.value.fontFamily != null)
            'fontFamily': entry.value.fontFamily,
          if (entry.value.glyph != null) 'glyph': entry.value.glyph,
          if (entry.value.image != null) 'image': entry.value.image,
          if (entry.value.activeCodePoint != null)
            'activeCodePoint': entry.value.activeCodePoint,
          if (entry.value.activeGlyph != null)
            'activeGlyph': entry.value.activeGlyph,
          if (entry.value.activeImage != null)
            'activeImage': entry.value.activeImage,
          if (entry.value.size != null) 'size': entry.value.size,
          if (entry.value.color != null)
            'color':
                '#${entry.value.color!.toARGB32().toRadixString(16).padLeft(8, '0')}',
          if (entry.value.activeColor != null)
            'activeColor':
                '#${entry.value.activeColor!.toARGB32().toRadixString(16).padLeft(8, '0')}',
        },
    };
  }

  @override
  bool operator ==(Object other) {
    if (other is! ThemeIcons || other.icons.length != icons.length) {
      return false;
    }
    for (final entry in icons.entries) {
      final mine = entry.value;
      final theirs = other.icons[entry.key];
      if (theirs == null ||
          mine.codePoint != theirs.codePoint ||
          mine.glyph != theirs.glyph ||
          mine.image != theirs.image ||
          mine.size != theirs.size ||
          mine.color != theirs.color ||
          mine.fontFamily != theirs.fontFamily ||
          mine.activeCodePoint != theirs.activeCodePoint ||
          mine.activeGlyph != theirs.activeGlyph ||
          mine.activeImage != theirs.activeImage ||
          mine.activeColor != theirs.activeColor) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    for (final key in ThemeIconKey.values)
      Object.hash(
        key,
        icons[key]?.codePoint,
        icons[key]?.glyph,
        icons[key]?.image,
        icons[key]?.size,
        icons[key]?.color,
        icons[key]?.fontFamily,
        icons[key]?.activeCodePoint,
        icons[key]?.activeGlyph,
        icons[key]?.activeImage,
        icons[key]?.activeColor,
      ),
  ]);
}
