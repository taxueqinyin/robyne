/// Skin-declared shape of the full-window Now Playing surface.
///
/// The flagship player used to be a hard-coded two-pane row (artwork column,
/// a 48dp divider, then the lyrics). That is one look, not a capability: it
/// could not express "art on the right, copy centred, no divider" and it left
/// the background a flat blend of the skin's own colour. This model makes the
/// shape a first-class, closed-enum declaration so a skin can restyle the
/// player without a code change — the same contract the shell regions already
/// follow (see `theme_regions.dart`).
///
/// Every field has a baseline equal to the flagship look, so a skin that omits
/// `layout.nowPlaying` renders exactly as before.
library;

import 'dart:ui';

/// How the full-window player relates to the skin's own brightness.
///
/// QQ Music's player is a *light* card sitting inside an otherwise dark app:
/// the shell keeps the skin's palette and the player page switches to a light
/// one. That is not "the skin is light" — it is one surface inverting — so it
/// has to be a property of the surface, not of the skin.
enum ThemeNowPlayingSurface {
  /// Inherit the skin's own tokens. The default, and what every skin that
  /// predates the field gets.
  followSkin('followSkin'),

  /// Force a legible light surface, whatever the skin's brightness is.
  light('light'),

  /// Force a dark surface, whatever the skin's brightness is.
  dark('dark');

  const ThemeNowPlayingSurface(this.jsonName);

  final String jsonName;

  static ThemeNowPlayingSurface? fromJsonName(String? name) {
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

/// Optional neutral overrides for the Now Playing surface.
///
/// Deliberately tiny: only the handful of roles the player actually paints. A
/// skin asks for `surface: "light"` and gets the app's own light baseline; it
/// names a colour here only when it wants a particular one.
class ThemeNowPlayingPalette {
  const ThemeNowPlayingPalette({
    this.backgroundBase,
    this.backgroundElevated,
    this.surfaceBase,
    this.textPrimary,
    this.textSecondary,
    this.textMuted,
    this.borderSubtle,
    this.brandBase,
  });

  final Color? backgroundBase;
  final Color? backgroundElevated;
  final Color? surfaceBase;
  final Color? textPrimary;
  final Color? textSecondary;
  final Color? textMuted;
  final Color? borderSubtle;
  final Color? brandBase;

  bool get isEmpty =>
      backgroundBase == null &&
      backgroundElevated == null &&
      surfaceBase == null &&
      textPrimary == null &&
      textSecondary == null &&
      textMuted == null &&
      borderSubtle == null &&
      brandBase == null;

  static ThemeNowPlayingPalette? parse(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final palette = ThemeNowPlayingPalette(
      backgroundBase: _color(raw['backgroundBase'] ?? raw['background']),
      backgroundElevated: _color(raw['backgroundElevated']),
      surfaceBase: _color(raw['surfaceBase'] ?? raw['surface']),
      textPrimary: _color(raw['textPrimary'] ?? raw['text']),
      textSecondary: _color(raw['textSecondary']),
      textMuted: _color(raw['textMuted']),
      borderSubtle: _color(raw['borderSubtle']),
      brandBase: _color(raw['brandBase'] ?? raw['brand']),
    );
    return palette.isEmpty ? null : palette;
  }

  /// Recognises `#RRGGBB` and `#AARRGGBB`, the two spellings every bundled
  /// skin already uses. Anything else is ignored rather than guessed at.
  static Color? _color(Object? value) {
    if (value is! String) {
      return null;
    }
    final text = value.trim();
    if (!text.startsWith('#')) {
      return null;
    }
    final hex = text.substring(1);
    if (hex.length == 6) {
      final parsed = int.tryParse('FF$hex', radix: 16);
      return parsed == null ? null : Color(parsed);
    }
    if (hex.length == 8) {
      final parsed = int.tryParse(hex, radix: 16);
      return parsed == null ? null : Color(parsed);
    }
    return null;
  }
}

/// Which side the artwork sits on, and how the page composes around it.
///
/// This is the one knob that changes the whole page: [splitLeft] is the
/// flagship two-pane reading surface, [centered] is the "now playing" poster
/// (artwork centred, metadata centred under it), and [splitRight] mirrors the
/// flagship with the artwork on the right.
enum ThemeNowPlayingArtworkSide {
  /// Artwork left, lyrics right — the flagship layout.
  splitLeft('splitLeft'),

  /// Artwork and metadata centred, lyrics beneath the metadata.
  centered('centered'),

  /// Artwork right, lyrics left.
  splitRight('splitRight');

  const ThemeNowPlayingArtworkSide(this.jsonName);

  final String jsonName;

  static ThemeNowPlayingArtworkSide? fromJsonName(String? name) {
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

/// Where the background wash is derived from.
enum ThemeNowPlayingBackground {
  /// Flat skin background, plus the blurred cover behind it. The pre-existing
  /// look.
  blurredCover('blurredCover'),

  /// A diagonal gradient sampled from the cover's dominant colour fading into
  /// the skin background. This is the 图2 look.
  artworkGradient('artworkGradient'),

  /// The skin's declared background image or colour only.
  plain('plain');

  const ThemeNowPlayingBackground(this.jsonName);

  final String jsonName;

  static ThemeNowPlayingBackground? fromJsonName(String? name) {
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

/// Where the title/artist lockup sits.
///
/// Both arrangements exist in the wild and they read very differently: under
/// the cover it is a "record sleeve" caption, above the lyrics it is a header
/// for the reading surface. The reference screenshot uses the second.
enum ThemeNowPlayingInfoPlacement {
  /// Title and artist directly beneath the artwork.
  underArtwork('underArtwork'),

  /// Title and artist at the top of the text column, above the lyrics.
  aboveLyrics('aboveLyrics');

  const ThemeNowPlayingInfoPlacement(this.jsonName);

  final String jsonName;

  static ThemeNowPlayingInfoPlacement? fromJsonName(String? name) {
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

/// Layout knobs for the full-window player.
class ThemeNowPlayingLayout {
  const ThemeNowPlayingLayout({
    required this.artworkSide,
    required this.showDivider,
    required this.metadataAlignment,
    required this.background,
    required this.artworkGradientStrength,
    this.contentInset = 0,
    this.infoPlacement = ThemeNowPlayingInfoPlacement.underArtwork,
    this.surface = ThemeNowPlayingSurface.followSkin,
    this.palette,
  });

  /// One-line composition axis. Because a `theme.json` value is a single
  /// string, the remaining fields default to the flagship values and every
  /// arrangement created from [artworkSide] is valid.
  const ThemeNowPlayingLayout.baseline()
    : artworkSide = ThemeNowPlayingArtworkSide.splitLeft,
      showDivider = true,
      metadataAlignment = ThemeNowPlayingAlignment.start,
      background = ThemeNowPlayingBackground.blurredCover,
      artworkGradientStrength = 0.55,
      contentInset = 0,
      infoPlacement = ThemeNowPlayingInfoPlacement.underArtwork,
      surface = ThemeNowPlayingSurface.followSkin,
      palette = null;

  /// Art-on-the-right, copy-right, no divider, artwork-gradient background.
  ///
  /// The flagship skin switches to this from `layout.nowPlaying` to render the
  /// 图2 composition.
  const ThemeNowPlayingLayout.poster()
    : artworkSide = ThemeNowPlayingArtworkSide.splitRight,
      showDivider = false,
      metadataAlignment = ThemeNowPlayingAlignment.end,
      background = ThemeNowPlayingBackground.artworkGradient,
      artworkGradientStrength = 0.55,
      contentInset = 0,
      infoPlacement = ThemeNowPlayingInfoPlacement.underArtwork,
      surface = ThemeNowPlayingSurface.followSkin,
      palette = null;

  final ThemeNowPlayingArtworkSide artworkSide;

  /// Whether a vertical divider is drawn between the artwork and the body.
  final bool showDivider;

  /// Text alignment of the metadata block when there is room to align it
  /// independently of [artworkSide].
  final ThemeNowPlayingAlignment metadataAlignment;

  final ThemeNowPlayingBackground background;

  /// How strongly the artwork gradient shows through, 0..1.
  ///
  /// Clamped at parse time. Zero is the same as [ThemeNowPlayingBackground.plain].
  final double artworkGradientStrength;

  /// How far the whole composition is pushed away from its leading edge, as a
  /// fraction of the player's width.
  ///
  /// A fraction rather than a pixel count, for the same reason the shell
  /// regions use ratios: the same skin has to work in a 400dp window and on a
  /// 2560dp one. The reference design sits the artwork and copy noticeably
  /// inboard of the edge; this is the knob that expresses that without moving
  /// either one independently.
  final double contentInset;

  /// Whether the title/artist lockup trails the cover or heads the lyrics.
  final ThemeNowPlayingInfoPlacement infoPlacement;

  /// The player's own brightness, independent of the skin's.
  final ThemeNowPlayingSurface surface;

  /// Neutrals that override the skin's on this surface only.
  ///
  /// Optional. Null means "derive them", so a skin can ask for a light player
  /// without authoring a second full token set.
  final ThemeNowPlayingPalette? palette;

  bool get artworkOnRight =>
      artworkSide == ThemeNowPlayingArtworkSide.splitRight;

  bool get centered => artworkSide == ThemeNowPlayingArtworkSide.centered;

  ThemeNowPlayingLayout copyWith({
    ThemeNowPlayingArtworkSide? artworkSide,
    bool? showDivider,
    ThemeNowPlayingAlignment? metadataAlignment,
    ThemeNowPlayingBackground? background,
    double? artworkGradientStrength,
    double? contentInset,
    ThemeNowPlayingInfoPlacement? infoPlacement,
    ThemeNowPlayingSurface? surface,
    ThemeNowPlayingPalette? palette,
  }) {
    return ThemeNowPlayingLayout(
      artworkSide: artworkSide ?? this.artworkSide,
      showDivider: showDivider ?? this.showDivider,
      metadataAlignment: metadataAlignment ?? this.metadataAlignment,
      background: background ?? this.background,
      artworkGradientStrength:
          artworkGradientStrength ?? this.artworkGradientStrength,
      contentInset: contentInset ?? this.contentInset,
      infoPlacement: infoPlacement ?? this.infoPlacement,
      surface: surface ?? this.surface,
      palette: palette ?? this.palette,
    );
  }

  /// Parses `layout.nowPlaying`.
  ///
  /// Absent or malformed input yields the baseline, matching the "a broken
  /// skin looks plain, it does not crash" contract of the rest of the parser.
  static ThemeNowPlayingLayout parse(Object? raw) {
    if (raw is! Map) {
      return const ThemeNowPlayingLayout.baseline();
    }
    const base = ThemeNowPlayingLayout.baseline();
    // `side` is the primary spelling; `artworkSide` and `artwork` are accepted
    // so an author can reach the knob under the name their mental model uses.
    final side =
        ThemeNowPlayingArtworkSide.fromJsonName(
          _string(raw['side'] ?? raw['artworkSide'] ?? raw['artwork']),
        ) ??
        base.artworkSide;
    final background =
        ThemeNowPlayingBackground.fromJsonName(_string(raw['background'])) ??
        base.background;
    final alignment =
        ThemeNowPlayingAlignment.fromJsonName(
          _string(raw['metadataAlignment'] ?? raw['align']),
        ) ??
        // A `centered` artwork side implies centred copy even when the skin
        // only declares the side, because a centred poster with left-aligned
        // text under it reads as a bug rather than as a choice.
        (side == ThemeNowPlayingArtworkSide.centered
            ? ThemeNowPlayingAlignment.center
            : base.metadataAlignment);

    return ThemeNowPlayingLayout(
      artworkSide: side,
      showDivider: _bool(raw['showDivider']) ?? base.showDivider,
      metadataAlignment: alignment,
      background: background,
      artworkGradientStrength:
          _double(
            raw['artworkGradientStrength'] ?? raw['gradientStrength'],
          )?.clamp(0, 1).toDouble() ??
          base.artworkGradientStrength,
      contentInset:
          _double(
            raw['contentInset'] ?? raw['inset'],
          )?.clamp(0, _maxContentInset).toDouble() ??
          base.contentInset,
      infoPlacement:
          ThemeNowPlayingInfoPlacement.fromJsonName(
            _string(raw['infoPlacement'] ?? raw['info']),
          ) ??
          base.infoPlacement,
      surface:
          ThemeNowPlayingSurface.fromJsonName(
            _string(raw['surface'] ?? raw['brightness']),
          ) ??
          base.surface,
      palette: ThemeNowPlayingPalette.parse(raw['palette'] ?? raw['colors']),
    );
  }

  /// The composition may be pushed inboard, but never far enough to squeeze the
  /// lyrics into a slit.
  static const double _maxContentInset = 0.3;

  static String? _string(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  static bool? _bool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final text = value.trim().toLowerCase();
      if (text == 'true') {
        return true;
      }
      if (text == 'false') {
        return false;
      }
    }
    return null;
  }

  static double? _double(Object? value) {
    if (value is num) {
      final parsed = value.toDouble();
      return parsed.isFinite ? parsed : null;
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }
}

/// Text alignment the metadata block may declare.
enum ThemeNowPlayingAlignment {
  start('start'),
  center('center'),
  end('end');

  const ThemeNowPlayingAlignment(this.jsonName);

  final String jsonName;

  static ThemeNowPlayingAlignment? fromJsonName(String? name) {
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
