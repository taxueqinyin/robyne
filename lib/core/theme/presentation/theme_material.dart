import 'dart:math' as math;
import 'dart:io' show Platform;
import 'dart:typed_data' show Float64List;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../domain/theme_materials.dart';
import '../domain/theme_tokens.dart';

/// Whether decorative theme motion (shimmer, ambient drift) may run.
///
/// Three callers need to say "no" and they all deserve the answer:
/// accessibility's reduce-motion setting, an environment where frames are
/// stepped deterministically (a widget test that calls `pumpAndSettle` will
/// otherwise never settle against an endless ticker), and a platform where
/// `dart:io` is unavailable.
///
/// Motion is decoration, so gating it costs a skin nothing but its animation:
/// the surface still paints, just without the moving highlight.
bool themeMotionAllowed(BuildContext context) {
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
    return false;
  }
  if (kIsWeb) {
    return true;
  }
  // The same signal the shell uses to decide whether it owns a native title
  // bar: under `flutter test` there is no real frame clock, only a stepper.
  return !Platform.environment.containsKey('FLUTTER_TEST');
}

/// Resolves the material a surface should paint, folding in the two effects
/// tokens that predate materials.
///
/// `effects.blur` and `effects.glassOpacity` were parsed, exported and
/// round-tripped for a year while only one widget read them. Rather than
/// leaving them dead next to a working material vocabulary, they act as a
/// *fallback*: a skin that only knows the old spelling still gets frosted
/// glass, and a skin that declares a material keeps full control.
///
/// Precedence is deliberate and one-directional — material fields always win,
/// and the fallback only fills in what the material left at its default.
ThemeMaterial resolveSurfaceMaterial({
  required ThemeMaterial material,
  required ThemeTokens tokens,
  Color? fallbackColor,
  ThemeGradient? fallbackGradient,
  double? fallbackRadius,
  bool applyLegacyEffects = false,
}) {
  final effects = tokens.effects;
  // Blur is a real raster cost, so the legacy fallback is opt-in per call
  // site: shell chrome (a handful of surfaces) takes it, but a grid of fifty
  // cards does not silently acquire fifty backdrop filters.
  final legacyBlur = !applyLegacyEffects
      ? 0.0
      : (material.blur > 0 ? material.blur : effects.blur);
  final legacyOpacity = !applyLegacyEffects || material.opacity < 1
      ? material.opacity
      : effects.glassOpacity;

  if (material.isTransparent) {
    final hasLegacyEffect = legacyBlur > 0 || legacyOpacity < 1;
    return material.copyWith(
      color: fallbackColor,
      gradient: fallbackGradient ?? ThemeGradient.none,
      blur: hasLegacyEffect ? legacyBlur : 0,
      opacity: hasLegacyEffect ? legacyOpacity.clamp(0.0, 1.0) : 1,
      radius: fallbackRadius,
    );
  }
  return material.copyWith(
    blur: material.blur > 0 ? material.blur : legacyBlur,
    radius: material.radius ?? fallbackRadius,
  );
}

/// Paints a skin's [ThemeMaterial] behind and over its child.
///
/// This is the one seam between the material model and the render tree, so
/// every surface — navigation, transport, queue, cards, hero — gets the same
/// treatment without any of them knowing how a material is built:
///
/// ```
/// theme shadows (glow)
/// └─ ClipRRect(radius)
///    ├─ BackdropFilter(blur + colour matrix)   ← frosted glass
///    ├─ CustomPaint(fill + gradient)            ← blends with the backdrop
///    ├─ child
///    └─ CustomPaint(overlay + shimmer + border) ← blends with the content
/// ```
///
/// A skin that declares nothing gets `child` back unchanged — no layers, no
/// filter, no ticker — which is what keeps every pre-material skin's cost and
/// widget tree exactly as they were.
class MaterialSurface extends StatelessWidget {
  const MaterialSurface({
    super.key,
    required this.material,
    required this.tokens,
    required this.child,
    this.borderRadius,
    this.clip = true,
    this.scaleToFill = false,
  });

  final ThemeMaterial material;

  /// Fallback token source for the radius when neither the material nor the
  /// caller declares one.
  final ThemeTokens tokens;

  final Widget child;

  /// Explicit radius, overriding `material.radius` and the token default.
  final BorderRadius? borderRadius;

  /// Whether content is clipped to [radius]. Glows and sheens still paint
  /// correctly when false, which is what an un-clipped overlay wants.
  final bool clip;

  /// Whether the painted fill covers the whole parent (used by surfaces that
  /// only contribute the backdrop pass).
  final bool scaleToFill;

  @override
  Widget build(BuildContext context) {
    if (material.isTransparent) {
      return child;
    }

    final radius = _resolveRadius();
    Widget result = _buildLayers(radius);
    if (material.shadows.isNotEmpty) {
      result = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: <BoxShadow>[
            for (final shadow in material.shadows)
              BoxShadow(
                color: shadow.color,
                blurRadius: shadow.blur,
                spreadRadius: shadow.spread,
                offset: Offset(shadow.dx, shadow.dy),
              ),
          ],
        ),
        child: result,
      );
    }
    return result;
  }

  /// The radius this surface will paint with, resolved the same way the
  /// painter resolves it. Callers that need to clip their own content can
  /// share one answer instead of guessing.
  BorderRadius resolvedRadius() => _resolveRadius();

  BorderRadius _resolveRadius() {
    final explicit = borderRadius;
    if (explicit != null) {
      return explicit;
    }
    final declared = material.radius;
    if (declared != null) {
      return BorderRadius.all(Radius.circular(declared));
    }
    return BorderRadius.zero;
  }

  Widget _buildLayers(BorderRadius radius) {
    final hasFill = material.color != null || !material.gradient.isEmpty;
    Widget body = Stack(
      fit: scaleToFill ? StackFit.expand : StackFit.passthrough,
      children: <Widget>[
        if (hasFill)
          Positioned.fill(
            // Decoration must never take part in hit testing: `RenderCustomPaint`
            // treats a background painter's default `hitTest` (null) as "hit",
            // so an unpainted overlay would silently swallow every tap on the
            // surface beneath it.
            child: IgnorePointer(
              child: CustomPaint(
                painter: _MaterialFillPainter(material),
                isComplex: material.blur > 0 || !material.gradient.isEmpty,
              ),
            ),
          ),
        child,
        if (material.shimmer != null)
          Positioned.fill(
            child: _ShimmerLayer(shimmer: material.shimmer!),
          ),
        if (material.overlay?.isEmpty == false)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _MaterialOverlayPainter(material.overlay!),
                isComplex: !material.overlay!.gradient.isEmpty,
              ),
            ),
          ),
        if (material.border != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _MaterialBorderPainter(material.border!, radius),
              ),
            ),
          ),
      ],
    );

    if (material.hasBackdropFilter) {
      body = BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: material.blur,
          sigmaY: material.blur,
          tileMode: TileMode.decal,
        ),
        child: _BackdropColorMatrix(
          matrix: materialColorMatrix(material),
          child: body,
        ),
      );
    }
    if (clip) {
      body = ClipRRect(borderRadius: radius, child: body);
    }
    return body;
  }
}

/// Applies the material's colour adjustments to whatever is behind it.
///
/// Separate from the blur because [BackdropFilter] takes one [ui.ImageFilter]
/// and only accepts a 4x4 transform — a 4x5 *colour* matrix is not one of
/// those. `ImageFiltered` builds its filter lazily from the widget's own
/// colour filter stack (`ColorFilter` is a subtype of `ImageFilter`), which is
/// the supported way to recolour the backdrop.
class _BackdropColorMatrix extends StatelessWidget {
  const _BackdropColorMatrix({required this.matrix, required this.child});

  final List<double>? matrix;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final values = matrix;
    if (values == null) {
      return child;
    }
    return ImageFiltered(
      imageFilter: ui.ColorFilter.matrix(Float64List.fromList(values)),
      child: child,
    );
  }
}

/// Builds the 4x5 matrix that turns a backdrop into glass.
///
/// Returns null when every adjustment is identity so the caller can skip the
/// extra layer entirely.
List<double>? materialColorMatrix(ThemeMaterial material) {
  final grayscale = material.grayscale.clamp(0.0, 1.0);
  final saturation = material.saturation;
  final contrast = material.contrast;
  final brightness = material.brightness;
  if (grayscale == 0 &&
      saturation == 1 &&
      contrast == 1 &&
      brightness == 1) {
    return null;
  }

  // Luminance weights from Rec. 709, the same ones Flutter's own
  // `ColorFilter.matrix` examples use.
  const lr = 0.2126;
  const lg = 0.7152;
  const lb = 0.0722;

  // Saturation: identity lerped towards the luminance projection. A
  // `grayscale` declaration is the same operation with saturation 0, so the
  // two compose by multiplication rather than fighting over the result.
  final s = saturation * (1 - grayscale);
  final sr = (1 - s) * lr;
  final sg = (1 - s) * lg;
  final sb = (1 - s) * lb;
  final saturationMatrix = <double>[
    sr + s, sg, sb, 0, 0, //
    sr, sg + s, sb, 0, 0, //
    sr, sg, sb + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  // Contrast pivots around mid-grey; brightness is a straight gain on the
  // result. Folding them into one scale+offset keeps the matrix count at two.
  final scale = contrast * brightness;
  final offset = (0.5 - 0.5 * contrast) * brightness * 255;
  final adjustMatrix = <double>[
    scale, 0, 0, 0, offset, //
    0, scale, 0, 0, offset, //
    0, 0, scale, 0, offset, //
    0, 0, 0, 1, 0, //
  ];

  return _multiplyColorMatrices(adjustMatrix, saturationMatrix);
}

/// Composes two 4x5 colour matrices: `first ∘ second`.
List<double> _multiplyColorMatrices(List<double> first, List<double> second) {
  final out = List<double>.filled(20, 0);
  for (var row = 0; row < 4; row += 1) {
    for (var column = 0; column < 5; column += 1) {
      var value = 0.0;
      for (var index = 0; index < 4; index += 1) {
        value += first[row * 5 + index] * second[index * 5 + column];
      }
      if (column == 4) {
        value += first[row * 5 + 4];
      }
      out[row * 5 + column] = value;
    }
  }
  return out;
}

/// The gradient shader for [rect], or null when the gradient is empty.
///
/// Public so any other painter (the ambient wash, the background compositor)
/// can share exactly one interpretation of a skin's gradient declaration.
Shader? materialGradientShader(ThemeGradient gradient, Rect rect) {
  if (gradient.isEmpty) {
    return null;
  }
  final colors = <Color>[for (final stop in gradient.stops) stop.color];
  final stops = <double>[for (final stop in gradient.stops) stop.offset];
  final tileMode = _tileMode(gradient.tile);
  return switch (gradient.kind) {
    ThemeGradientKind.linear => LinearGradient(
      colors: colors,
      stops: stops,
      begin: _alignment(gradient.begin),
      end: _alignment(gradient.end),
      tileMode: tileMode,
    ).createShader(rect),
    ThemeGradientKind.radial => RadialGradient(
      colors: colors,
      stops: stops,
      center: _alignment(gradient.center),
      radius: gradient.radius.clamp(0.01, 4),
      tileMode: tileMode,
    ).createShader(rect),
    ThemeGradientKind.sweep => SweepGradient(
      colors: colors,
      stops: stops,
      center: _alignment(gradient.center),
      startAngle: _radians(gradient.startAngle),
      endAngle: _radians(gradient.endAngle),
      tileMode: tileMode,
    ).createShader(rect),
  };
}

Alignment _alignment(ThemePoint point) {
  return Alignment(
    point.x.clamp(-1.0, 1.0),
    point.y.clamp(-1.0, 1.0),
  );
}

double _radians(double degrees) => degrees * math.pi / 180;

TileMode _tileMode(ThemeGradientTile tile) {
  return switch (tile) {
    ThemeGradientTile.clamp => TileMode.clamp,
    ThemeGradientTile.repeat => TileMode.repeated,
    ThemeGradientTile.mirror => TileMode.mirror,
    ThemeGradientTile.decal => TileMode.decal,
  };
}

/// Flutter's blend enum for our curated vocabulary.
BlendMode materialBlendMode(ThemeBlendMode mode) {
  return switch (mode) {
    ThemeBlendMode.normal => BlendMode.srcOver,
    ThemeBlendMode.multiply => BlendMode.multiply,
    ThemeBlendMode.screen => BlendMode.screen,
    ThemeBlendMode.overlay => BlendMode.overlay,
    ThemeBlendMode.darken => BlendMode.darken,
    ThemeBlendMode.lighten => BlendMode.lighten,
    ThemeBlendMode.colorDodge => BlendMode.colorDodge,
    ThemeBlendMode.colorBurn => BlendMode.colorBurn,
    ThemeBlendMode.hardLight => BlendMode.hardLight,
    ThemeBlendMode.softLight => BlendMode.softLight,
    ThemeBlendMode.difference => BlendMode.difference,
    ThemeBlendMode.exclusion => BlendMode.exclusion,
    ThemeBlendMode.hue => BlendMode.hue,
    ThemeBlendMode.saturation => BlendMode.saturation,
    ThemeBlendMode.color => BlendMode.color,
    ThemeBlendMode.luminosity => BlendMode.luminosity,
    ThemeBlendMode.plus => BlendMode.plus,
    ThemeBlendMode.modulate => BlendMode.modulate,
  };
}

/// Paints a material's fill: base colour, then gradient, as one layer.
class _MaterialFillPainter extends CustomPainter {
  const _MaterialFillPainter(this.material);

  final ThemeMaterial material;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final opacity = material.opacity.clamp(0.0, 1.0);
    if (opacity <= 0) {
      return;
    }
    final blend = materialBlendMode(material.blend);
    final color = material.color;
    if (color != null) {
      canvas.drawRect(
        rect,
        Paint()
          ..color = color.withValues(alpha: color.a * opacity)
          ..blendMode = blend,
      );
    }
    final shader = materialGradientShader(material.gradient, rect);
    if (shader != null) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = shader
          ..blendMode = blend
          ..color = Colors.white.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_MaterialFillPainter oldDelegate) {
    return oldDelegate.material != material;
  }
}

/// Paints the optional second layer over the child.
class _MaterialOverlayPainter extends CustomPainter {
  const _MaterialOverlayPainter(this.overlay);

  final ThemeMaterialOverlay overlay;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final opacity = overlay.opacity.clamp(0.0, 1.0);
    if (opacity <= 0) {
      return;
    }
    final blend = materialBlendMode(overlay.blend);
    final color = overlay.color;
    if (color != null) {
      canvas.drawRect(
        rect,
        Paint()
          ..color = color.withValues(alpha: color.a * opacity)
          ..blendMode = blend,
      );
    }
    final shader = materialGradientShader(overlay.gradient, rect);
    if (shader != null) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = shader
          ..blendMode = blend
          ..color = Colors.white.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_MaterialOverlayPainter oldDelegate) {
    return oldDelegate.overlay != overlay;
  }
}

/// Draws the material's hairline stroke on top of the content.
class _MaterialBorderPainter extends CustomPainter {
  const _MaterialBorderPainter(this.border, this.radius);

  final ThemeMaterialBorder border;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final width = border.width;
    if (width <= 0 || border.color.a <= 0) {
      return;
    }
    final rect = Rect.fromLTWH(
      width / 2,
      width / 2,
      math.max(0, size.width - width),
      math.max(0, size.height - width),
    );
    canvas.drawRRect(
      radius.toRRect(rect).deflate(width / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = border.color,
    );
  }

  @override
  bool shouldRepaint(_MaterialBorderPainter oldDelegate) {
    return oldDelegate.border != border || oldDelegate.radius != radius;
  }
}

/// A card-shaped surface that a page can drop in wherever it previously used
/// a `Material` + `InkWell` pair.
///
/// The two widgets solve different problems and every list row needs both:
/// [MaterialSurface] paints the skin's material *behind* the ink, and the
/// transparent [Material] above it gives `InkWell` a canvas to splash on.
/// Bundling them here keeps that ordering in one place, so a page cannot
/// accidentally paint a splash under a card's own fill.
class ThemedSurface extends StatelessWidget {
  const ThemedSurface({
    super.key,
    required this.material,
    required this.tokens,
    required this.child,
    this.fallbackColor,
    this.radius,
    this.splashColor,
    this.highlightColor,
    this.onTap,
  });

  final ThemeMaterial material;
  final ThemeTokens tokens;
  final Widget child;

  /// Fill used when the skin declares no material, preserving the page's
  /// pre-material appearance.
  final Color? fallbackColor;

  /// Corner radius; falls back to the material's own or zero.
  final double? radius;

  final Color? splashColor;
  final Color? highlightColor;

  /// Tap handler for the whole surface. Null keeps the surface inert, which
  /// is what a purely decorative card wants.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.all(Radius.circular(radius ?? 0));
    final effective = material.isTransparent
        ? material.copyWith(color: fallbackColor, radius: radius)
        : material.copyWith(radius: material.radius ?? radius);
    return MaterialSurface(
      material: effective,
      tokens: tokens,
      borderRadius: borderRadius,
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: splashColor,
          highlightColor: highlightColor,
          borderRadius: borderRadius,
          child: child,
        ),
      ),
    );
  }
}

/// The moving specular band.
///
/// Created only when a skin declares a shimmer, and it drives its own
/// [AnimationController]: a matte skin never allocates a ticker.
class _ShimmerLayer extends StatefulWidget {
  const _ShimmerLayer({required this.shimmer});

  final ThemeShimmer shimmer;

  @override
  State<_ShimmerLayer> createState() => _ShimmerLayerState();
}

class _ShimmerLayerState extends State<_ShimmerLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.shimmer.period,
  );

  @override
  void didUpdateWidget(_ShimmerLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shimmer.period != widget.shimmer.period) {
      _controller.duration = widget.shimmer.period;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Motion is decoration, and an endless ticker means the shell never
    // reaches a stable frame. Reduce-motion users and stepped test frames
    // both stop it here rather than paying for an animation they cannot see.
    if (!themeMotionAllowed(context)) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      return const SizedBox.shrink();
    }
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _ShimmerPainter(
                shimmer: widget.shimmer,
                progress: _controller.value,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  const _ShimmerPainter({required this.shimmer, required this.progress});

  final ThemeShimmer shimmer;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    if (width <= 0 || height <= 0) {
      return;
    }
    final angle = _radians(shimmer.angle);
    final direction = Offset(math.cos(angle), math.sin(angle));
    // Travel from fully off one edge to fully off the other, so the band
    // sweeps the whole surface instead of fading in at the middle.
    final diagonal = math.sqrt(width * width + height * height);
    final bandWidth = (diagonal * shimmer.width.clamp(0.01, 4)).abs();
    final travel = diagonal + bandWidth * 2;
    final center = Offset(width / 2, height / 2) +
        direction * (progress * travel - travel / 2);
    final half = direction * (bandWidth / 2);
    final perpendicular = Offset(-direction.dy, direction.dx);
    final reach = math.max(width, height) * 1.5;
    final quad = Path()
      ..moveTo(
        center.dx - half.dx + perpendicular.dx * reach,
        center.dy - half.dy + perpendicular.dy * reach,
      )
      ..lineTo(
        center.dx + half.dx + perpendicular.dx * reach,
        center.dy + half.dy + perpendicular.dy * reach,
      )
      ..lineTo(
        center.dx + half.dx - perpendicular.dx * reach,
        center.dy + half.dy - perpendicular.dy * reach,
      )
      ..lineTo(
        center.dx - half.dx - perpendicular.dx * reach,
        center.dy - half.dy - perpendicular.dy * reach,
      )
      ..close();
    final opacity = shimmer.opacity.clamp(0.0, 1.0);
    canvas.drawPath(
      quad,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            shimmer.color.withValues(alpha: 0),
            shimmer.color.withValues(alpha: shimmer.color.a * opacity),
            shimmer.color.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCenter(
            center: center,
            width: bandWidth * 2,
            height: reach * 2,
          ),
        )
        ..blendMode = materialBlendMode(shimmer.blend),
    );
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.shimmer != shimmer;
  }
}
