import 'dart:ui';

/// How a gradient paints its stops.
enum ThemeGradientKind {
  linear,
  radial,
  sweep;

  static ThemeGradientKind fromName(String? name) {
    return values.firstWhere(
      (kind) => kind.name == name,
      orElse: () => ThemeGradientKind.linear,
    );
  }
}

/// How a gradient shader behaves outside its declared area.
enum ThemeGradientTile {
  clamp,
  repeat,
  mirror,
  decal;

  static ThemeGradientTile fromName(String? name) {
    return values.firstWhere(
      (tile) => tile.name == name,
      orElse: () => ThemeGradientTile.clamp,
    );
  }
}

/// One colour stop in a [ThemeGradient].
class ThemeGradientStop {
  const ThemeGradientStop({required this.color, required this.offset});

  final Color color;

  /// Normalised position, 0..1. The parser clamps it, because Skia rejects
  /// out-of-order or out-of-range stops and would drop the whole frame.
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

/// A normalised point in the painted rect.
///
/// `-1..1` on both axes matches Flutter's alignment space, so `(0, 0)` is the
/// centre. The domain keeps its own type rather than importing `Alignment` so
/// this file stays free of the widget library, exactly like
/// [ThemeMotionCurve]'s control points.
class ThemePoint {
  const ThemePoint(this.x, this.y);

  final double x;
  final double y;

  static const ThemePoint topLeft = ThemePoint(-1, -1);
  static const ThemePoint topCenter = ThemePoint(0, -1);
  static const ThemePoint topRight = ThemePoint(1, -1);
  static const ThemePoint centerLeft = ThemePoint(-1, 0);
  static const ThemePoint center = ThemePoint(0, 0);
  static const ThemePoint centerRight = ThemePoint(1, 0);
  static const ThemePoint bottomLeft = ThemePoint(-1, 1);
  static const ThemePoint bottomCenter = ThemePoint(0, 1);
  static const ThemePoint bottomRight = ThemePoint(1, 1);

  /// Parses `"topLeft"`, `"bottom-right"`-style names, or `[x, y]`.
  ///
  /// Names are compared with separators stripped, so `top-left` and
  /// `topLeft` are the same declaration — icon cheat sheets and design tools
  /// spell these both ways and forcing one spelling is a pointless papercut.
  static ThemePoint? tryParse(
    Object? raw, {
    double minCoordinate = -1,
    double maxCoordinate = 1,
  }) {
    if (raw is List && raw.length == 2) {
      final x = _coordinate(raw[0], minCoordinate, maxCoordinate);
      final y = _coordinate(raw[1], minCoordinate, maxCoordinate);
      if (x == null || y == null) {
        return null;
      }
      return ThemePoint(x, y);
    }
    if (raw is! String) {
      return null;
    }
    final name = raw.replaceAll(RegExp(r'[\s_-]'), '').toLowerCase();
    return switch (name) {
      'topleft' => topLeft,
      'topcenter' || 'top' => topCenter,
      'topright' => topRight,
      'centerleft' || 'left' => centerLeft,
      'center' || 'middle' => center,
      'centerright' || 'right' => centerRight,
      'bottomleft' => bottomLeft,
      'bottomcenter' || 'bottom' => bottomCenter,
      'bottomright' => bottomRight,
      _ => null,
    };
  }

  static double? _coordinate(Object? value, double min, double max) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (parsed == null || !parsed.isFinite) {
      return null;
    }
    return parsed.clamp(min, max).toDouble();
  }

  static ThemePoint lerp(ThemePoint a, ThemePoint b, double t) {
    return ThemePoint(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
  }
}

/// A gradient or a flat colour, in one value.
///
/// A music player's identity lives in its gradients, and a pure-colour token
/// cannot express them. The original model only spoke linear gradients with a
/// hard-coded direction per surface; this one carries the full vocabulary
/// Skia supports: linear (with arbitrary begin/end), radial (arbitrary centre
/// and radius) and sweep (arbitrary start/end angle).
///
/// Every field beyond [stops] defaults to the exact behaviour of the old
/// linear-only model, so skins that only ever wrote stops are unaffected.
class ThemeGradient {
  const ThemeGradient({
    required this.stops,
    this.kind = ThemeGradientKind.linear,
    this.begin = ThemePoint.topLeft,
    this.end = ThemePoint.bottomRight,
    this.center = ThemePoint.center,
    this.radius = 0.5,
    this.startAngle = 0,
    this.endAngle = 360,
    this.tile = ThemeGradientTile.clamp,
  });

  /// A single-colour gradient (renders flat).
  ///
  /// Not `const`: the colour comes from the skin at runtime.
  ThemeGradient.solid(Color color)
    : stops = <ThemeGradientStop>[ThemeGradientStop(color: color, offset: 0)],
      kind = ThemeGradientKind.linear,
      begin = ThemePoint.topLeft,
      end = ThemePoint.bottomRight,
      center = ThemePoint.center,
      radius = 0.5,
      startAngle = 0,
      endAngle = 360,
      tile = ThemeGradientTile.clamp;

  /// No gradient at all: the surface falls back to its semantic colour.
  static const ThemeGradient none = ThemeGradient(stops: <ThemeGradientStop>[]);

  /// Largest number of stops a single gradient may carry.
  ///
  /// Eight is what the old parser enforced and it is already generous: past
  /// that the author is drawing a picture, not a gradient.
  static const int maxStops = 8;

  final List<ThemeGradientStop> stops;
  final ThemeGradientKind kind;

  /// Linear direction, in normalised rect space.
  final ThemePoint begin;
  final ThemePoint end;

  /// Radial centre.
  final ThemePoint center;

  /// Radial radius as a fraction of the shorter side. `0.5` is a circle that
  /// touches the nearest edges, which is the least surprising default.
  final double radius;

  /// Sweep angles in degrees, clockwise from the positive x axis.
  final double startAngle;
  final double endAngle;

  final ThemeGradientTile tile;

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

  /// The first declared colour, or null when empty.
  ///
  /// Useful as a fallback fill behind a translucent gradient: a skin almost
  /// always wants the surface tinted with its own gradient's colour rather
  /// than with a neutral when only the flat colour layer can be painted.
  Color? get primaryColor => stops.isEmpty ? null : stops.first.color;

  ThemeGradient copyWith({
    List<ThemeGradientStop>? stops,
    ThemeGradientKind? kind,
    ThemePoint? begin,
    ThemePoint? end,
    ThemePoint? center,
    double? radius,
    double? startAngle,
    double? endAngle,
    ThemeGradientTile? tile,
  }) {
    return ThemeGradient(
      stops: stops ?? this.stops,
      kind: kind ?? this.kind,
      begin: begin ?? this.begin,
      end: end ?? this.end,
      center: center ?? this.center,
      radius: radius ?? this.radius,
      startAngle: startAngle ?? this.startAngle,
      endAngle: endAngle ?? this.endAngle,
      tile: tile ?? this.tile,
    );
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
    // Discrete axes snap at the midpoint: there is no meaningful "half a
    // radial gradient".
    final discrete = t < 0.5 ? from : to;
    return ThemeGradient(
      stops: stops,
      kind: discrete.kind,
      begin: ThemePoint.lerp(from.begin, to.begin, t),
      end: ThemePoint.lerp(from.end, to.end, t),
      center: ThemePoint.lerp(from.center, to.center, t),
      radius: from.radius + (to.radius - from.radius) * t,
      startAngle: from.startAngle + (to.startAngle - from.startAngle) * t,
      endAngle: from.endAngle + (to.endAngle - from.endAngle) * t,
      tile: discrete.tile,
    );
  }
}

/// The blend vocabulary available to skins.
///
/// Deliberately a curated subset of [BlendMode]: the modes that compose
/// predictably with what is underneath (light, glows, colour, film grain) and
/// none of the ones that read as compositing bugs (`clear`, `src`, `dst`).
enum ThemeBlendMode {
  normal,
  multiply,
  screen,
  overlay,
  darken,
  lighten,
  colorDodge,
  colorBurn,
  hardLight,
  softLight,
  difference,
  exclusion,
  hue,
  saturation,
  color,
  luminosity,
  plus,
  modulate;

  static ThemeBlendMode fromName(String? name) {
    if (name == null || name.isEmpty) {
      return ThemeBlendMode.normal;
    }
    final normalized = name.replaceAll(RegExp(r'[\s_-]'), '').toLowerCase();
    for (final mode in values) {
      if (mode.name.toLowerCase() == normalized) {
        return mode;
      }
    }
    return ThemeBlendMode.normal;
  }
}

/// One entry in [ThemeMaterial.shadows].
///
/// A duplicate of `BoxShadow` in domain form so the model layer stays
/// widget-free. Supports the look every "premium" surface needs: a coloured
/// glow (large blur, small spread, zero offset), a drop shadow, or both.
class ThemeShadow {
  const ThemeShadow({
    required this.color,
    this.blur = 0,
    this.spread = 0,
    this.dx = 0,
    this.dy = 0,
  });

  final Color color;
  final double blur;
  final double spread;
  final double dx;
  final double dy;

  static ThemeShadow lerp(ThemeShadow a, ThemeShadow b, double t) {
    return ThemeShadow(
      color: Color.lerp(a.color, b.color, t) ?? a.color,
      blur: a.blur + (b.blur - a.blur) * t,
      spread: a.spread + (b.spread - a.spread) * t,
      dx: a.dx + (b.dx - a.dx) * t,
      dy: a.dy + (b.dy - a.dy) * t,
    );
  }
}

/// A moving specular band across a surface.
///
/// This is the "light sweeps across the glass" effect. It is opt-in per
/// surface: a skin that never declares one pays neither a ticker nor a paint.
class ThemeShimmer {
  const ThemeShimmer({
    required this.color,
    this.width = 0.35,
    this.angle = -20,
    this.periodMs = 2400,
    this.blend = ThemeBlendMode.plus,
    this.opacity = 0.5,
  });

  /// Colour of the moving band.
  final Color color;

  /// Band width as a fraction of the surface's diagonal. `0.35` reads as a
  /// highlight; `1` is a full cross-fade.
  final double width;

  /// Band angle in degrees. A shallow negative angle reads as light from
  /// above-left, which is the convention every glass UI uses.
  final double angle;

  final int periodMs;
  final ThemeBlendMode blend;
  final double opacity;

  Duration get period => Duration(milliseconds: periodMs);

  ThemeShimmer copyWith({
    Color? color,
    double? width,
    double? angle,
    int? periodMs,
    ThemeBlendMode? blend,
    double? opacity,
  }) {
    return ThemeShimmer(
      color: color ?? this.color,
      width: width ?? this.width,
      angle: angle ?? this.angle,
      periodMs: periodMs ?? this.periodMs,
      blend: blend ?? this.blend,
      opacity: opacity ?? this.opacity,
    );
  }

  static ThemeShimmer lerp(ThemeShimmer a, ThemeShimmer b, double t) {
    final discrete = t < 0.5 ? a : b;
    return ThemeShimmer(
      color: Color.lerp(a.color, b.color, t) ?? a.color,
      width: a.width + (b.width - a.width) * t,
      angle: a.angle + (b.angle - a.angle) * t,
      periodMs: discrete.periodMs,
      blend: discrete.blend,
      opacity: a.opacity + (b.opacity - a.opacity) * t,
    );
  }
}

/// A stroke drawn on a material's edge.
class ThemeMaterialBorder {
  const ThemeMaterialBorder({required this.color, this.width = 1});

  final Color color;
  final double width;

  static ThemeMaterialBorder lerp(
    ThemeMaterialBorder a,
    ThemeMaterialBorder b,
    double t,
  ) {
    return ThemeMaterialBorder(
      color: Color.lerp(a.color, b.color, t) ?? a.color,
      width: a.width + (b.width - a.width) * t,
    );
  }
}

/// A second painted layer composited over the fill.
class ThemeMaterialOverlay {
  const ThemeMaterialOverlay({
    this.color,
    this.gradient = ThemeGradient.none,
    this.blend = ThemeBlendMode.normal,
    this.opacity = 1,
  });

  /// Flat colour layer. Null means "draw nothing".
  final Color? color;

  /// Gradient layer, painted after [color] when non-empty.
  final ThemeGradient gradient;

  final ThemeBlendMode blend;
  final double opacity;

  bool get isEmpty => color == null && gradient.isEmpty;

  static ThemeMaterialOverlay lerp(
    ThemeMaterialOverlay a,
    ThemeMaterialOverlay b,
    double t,
  ) {
    final discrete = t < 0.5 ? a : b;
    return ThemeMaterialOverlay(
      color: Color.lerp(a.color, b.color, t),
      gradient:
          ThemeGradient.lerp(a.gradient, b.gradient, t) ?? ThemeGradient.none,
      blend: discrete.blend,
      opacity: a.opacity + (b.opacity - a.opacity) * t,
    );
  }
}

/// Everything needed to paint one surface: fill, backdrop treatment, blend
/// layers, stroke, glow and motion.
///
/// A material is *only* paint. It never decides layout, so the same value
/// describes a nav rail, a card and a floating queue panel without any of
/// them learning about the others.
///
/// `const ThemeMaterial()` is the empty material: nothing painted, no filter,
/// no ticker. Every field is additive, which is what makes this safe to ship
/// in front of skins written before it existed.
class ThemeMaterial {
  const ThemeMaterial({
    this.color,
    this.gradient = ThemeGradient.none,
    this.opacity = 1,
    this.blur = 0,
    this.saturation = 1,
    this.brightness = 1,
    this.contrast = 1,
    this.grayscale = 0,
    this.blend = ThemeBlendMode.normal,
    this.overlay,
    this.border,
    this.radius,
    this.shadows = const <ThemeShadow>[],
    this.shimmer,
  });

  /// Base fill. Null means "no fill of my own", which is what a pure
  /// backdrop-blur surface wants: it shows the background through itself.
  final Color? color;

  /// Fill gradient, painted over [color] when non-empty.
  final ThemeGradient gradient;

  /// Multiplies the whole fill layer (colour + gradient) in one value.
  final double opacity;

  /// Backdrop blur sigma — the frosted-glass amount.
  final double blur;

  /// Backdrop colour-matrix adjustments, applied before the fill.
  ///
  /// All four default to identity, so a skin that only sets [blur] gets a
  /// pure blur with no tint shift.
  final double saturation;
  final double brightness;
  final double contrast;
  final double grayscale;

  /// How the fill layer composites with everything painted beneath it.
  final ThemeBlendMode blend;

  /// Optional second layer over the fill.
  final ThemeMaterialOverlay? overlay;

  final ThemeMaterialBorder? border;

  /// Corner radius override. Null means "use the surface's own token", so a
  /// material can stay radius-agnostic.
  final double? radius;

  /// Glows and drop shadows, outermost first.
  final List<ThemeShadow> shadows;

  /// Moving highlight, or null for none.
  final ThemeShimmer? shimmer;

  /// True when this material would paint or filter nothing.
  ///
  /// Callers use this to skip wrapping the widget entirely, which is how
  /// every pre-material skin keeps its old widget tree and cost.
  bool get isTransparent {
    return color == null &&
        gradient.isEmpty &&
        (overlay?.isEmpty ?? true) &&
        blur <= 0 &&
        _isIdentityMatrix &&
        border == null &&
        shadows.isEmpty &&
        shimmer == null;
  }

  bool get _isIdentityMatrix =>
      saturation == 1 && brightness == 1 && contrast == 1 && grayscale == 0;

  /// Whether the material adjusts the backdrop at all.
  bool get hasBackdropFilter => blur > 0 || !_isIdentityMatrix;

  ThemeMaterial copyWith({
    Object? color = _sentinel,
    ThemeGradient? gradient,
    double? opacity,
    double? blur,
    double? saturation,
    double? brightness,
    double? contrast,
    double? grayscale,
    ThemeBlendMode? blend,
    Object? overlay = _sentinel,
    Object? border = _sentinel,
    Object? radius = _sentinel,
    List<ThemeShadow>? shadows,
    Object? shimmer = _sentinel,
  }) {
    return ThemeMaterial(
      color: identical(color, _sentinel) ? this.color : color as Color?,
      gradient: gradient ?? this.gradient,
      opacity: opacity ?? this.opacity,
      blur: blur ?? this.blur,
      saturation: saturation ?? this.saturation,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      grayscale: grayscale ?? this.grayscale,
      blend: blend ?? this.blend,
      overlay: identical(overlay, _sentinel)
          ? this.overlay
          : overlay as ThemeMaterialOverlay?,
      border: identical(border, _sentinel)
          ? this.border
          : border as ThemeMaterialBorder?,
      radius: identical(radius, _sentinel) ? this.radius : radius as double?,
      shadows: shadows ?? this.shadows,
      shimmer: identical(shimmer, _sentinel)
          ? this.shimmer
          : shimmer as ThemeShimmer?,
    );
  }

  static ThemeMaterial lerp(ThemeMaterial a, ThemeMaterial b, double t) {
    final discrete = t < 0.5 ? a : b;
    final shadows = <ThemeShadow>[];
    final shadowCount = a.shadows.length > b.shadows.length
        ? a.shadows.length
        : b.shadows.length;
    for (var index = 0; index < shadowCount; index += 1) {
      final left = a.shadows.isEmpty
          ? null
          : a.shadows[index % a.shadows.length];
      final right = b.shadows.isEmpty
          ? null
          : b.shadows[index % b.shadows.length];
      if (left == null || right == null) {
        shadows.add((left ?? right)!);
        continue;
      }
      shadows.add(ThemeShadow.lerp(left, right, t));
    }
    return ThemeMaterial(
      color: Color.lerp(a.color, b.color, t),
      gradient:
          ThemeGradient.lerp(a.gradient, b.gradient, t) ?? ThemeGradient.none,
      opacity: a.opacity + (b.opacity - a.opacity) * t,
      blur: a.blur + (b.blur - a.blur) * t,
      saturation: a.saturation + (b.saturation - a.saturation) * t,
      brightness: a.brightness + (b.brightness - a.brightness) * t,
      contrast: a.contrast + (b.contrast - a.contrast) * t,
      grayscale: a.grayscale + (b.grayscale - a.grayscale) * t,
      blend: discrete.blend,
      overlay: a.overlay == null || b.overlay == null
          ? (a.overlay ?? b.overlay)
          : ThemeMaterialOverlay.lerp(a.overlay!, b.overlay!, t),
      border: a.border == null || b.border == null
          ? (a.border ?? b.border)
          : ThemeMaterialBorder.lerp(a.border!, b.border!, t),
      radius: a.radius == null || b.radius == null
          ? (a.radius ?? b.radius)
          : a.radius! + (b.radius! - a.radius!) * t,
      shadows: List<ThemeShadow>.unmodifiable(shadows),
      shimmer: a.shimmer == null || b.shimmer == null
          ? (a.shimmer ?? b.shimmer)
          : ThemeShimmer.lerp(a.shimmer!, b.shimmer!, t),
    );
  }
}

/// The closed set of surfaces a material may describe.
///
/// Adding a surface here is the supported way to make something new
/// skinnable; a name that is not here is ignored rather than inventing a
/// surface nothing renders.
class ThemeMaterials {
  const ThemeMaterials({
    required this.navBar,
    required this.topBar,
    required this.playerBar,
    required this.queue,
    required this.card,
    required this.content,
    required this.hero,
  });

  const ThemeMaterials.baseline()
    : navBar = const ThemeMaterial(),
      topBar = const ThemeMaterial(),
      playerBar = const ThemeMaterial(),
      queue = const ThemeMaterial(),
      card = const ThemeMaterial(),
      content = const ThemeMaterial(),
      hero = const ThemeMaterial();

  /// The main navigation surface (desktop rail / phone tab bar).
  final ThemeMaterial navBar;

  /// The global search window's chrome above the content.
  final ThemeMaterial topBar;

  /// The playback transport.
  final ThemeMaterial playerBar;

  /// The queue panel, docked or floating.
  final ThemeMaterial queue;

  /// Collection tiles and artwork cards.
  final ThemeMaterial card;

  /// The content region's own surface behind every page.
  final ThemeMaterial content;

  /// The discover hero banner.
  final ThemeMaterial hero;

  ThemeMaterial? operator [](String name) {
    return switch (name) {
      'navBar' => navBar,
      'topBar' => topBar,
      'playerBar' => playerBar,
      'queue' => queue,
      'card' => card,
      'content' => content,
      'hero' => hero,
      _ => null,
    };
  }

  ThemeMaterials copyWith({
    ThemeMaterial? navBar,
    ThemeMaterial? topBar,
    ThemeMaterial? playerBar,
    ThemeMaterial? queue,
    ThemeMaterial? card,
    ThemeMaterial? content,
    ThemeMaterial? hero,
  }) {
    return ThemeMaterials(
      navBar: navBar ?? this.navBar,
      topBar: topBar ?? this.topBar,
      playerBar: playerBar ?? this.playerBar,
      queue: queue ?? this.queue,
      card: card ?? this.card,
      content: content ?? this.content,
      hero: hero ?? this.hero,
    );
  }

  static ThemeMaterials lerp(ThemeMaterials a, ThemeMaterials b, double t) {
    return ThemeMaterials(
      navBar: ThemeMaterial.lerp(a.navBar, b.navBar, t),
      topBar: ThemeMaterial.lerp(a.topBar, b.topBar, t),
      playerBar: ThemeMaterial.lerp(a.playerBar, b.playerBar, t),
      queue: ThemeMaterial.lerp(a.queue, b.queue, t),
      card: ThemeMaterial.lerp(a.card, b.card, t),
      content: ThemeMaterial.lerp(a.content, b.content, t),
      hero: ThemeMaterial.lerp(a.hero, b.hero, t),
    );
  }
}

/// Sentinel distinguishing "field absent" from "field explicitly null".
const Object _sentinel = Object();
