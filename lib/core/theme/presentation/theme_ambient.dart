import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/application/theme_providers.dart';
import '../../theme/domain/theme_components.dart';
import '../../theme/domain/theme_materials.dart';
import '../../theme/infrastructure/token_resolver.dart';
import 'theme_material.dart';

/// The dominant colour of the artwork currently playing.
///
/// `UI_DESIGN_SPEC.md` §3.4 makes this the app's signature: the page picks up
/// the colour of the music. There is no palette package in the dependency set,
/// so the colour is derived by decoding the artwork at a deliberately tiny
/// width and averaging the result — a 16px decode costs a fraction of a
/// millisecond and cannot be mistaken for an accurate palette, which is fine,
/// because the wash is blurred to the point where only the hue survives.
///
/// Results are cached by URL: a skin that re-renders the shell must not
/// re-decode the same cover on every frame.
final artworkAccentProvider = FutureProvider.family<Color?, String>((
  ref,
  url,
) async {
  return _accentCache.putIfAbsent(url, () => _dominantColor(url));
});

final Map<String, Future<Color?>> _accentCache = <String, Future<Color?>>{};

/// Visible for tests: the cache would otherwise leak between cases.
void clearArtworkAccentCache() => _accentCache.clear();

/// A small palette derived from one cover.
///
/// Q12 asked for the background and the player's controls to be coloured by
/// the artwork, which a single averaged colour cannot do: averaging a pink
/// cover with a green character yields a muddy grey that matches neither.
/// What the eye reads as "the colour of this cover" is the *dominant* one, so
/// this buckets the decoded pixels by hue, weights each bucket by how much of
/// the image it covers times how saturated it is, and returns both the winner
/// and the runner-up so a gradient can mix two real colours from the image.
class ArtworkPalette {
  const ArtworkPalette({
    required this.primary,
    required this.secondary,
    this.isDark = false,
  });

  /// The colour with the largest weight — the cover's identity.
  final Color primary;

  /// The next distinct colour, used to keep a gradient from reading as a
  /// single flat wash. Falls back to [primary] when the cover is monochrome.
  final Color secondary;

  /// True when the sampled colours are dark enough that text laid over them
  /// has to be light, and vice versa. Derived from the palette rather than
  /// assumed, so a bright cover gets dark ink and a dark cover gets light ink.
  final bool isDark;

  /// A readable ink colour for [background].
  Color get onColor =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1A1A22);
}

/// The palette of the artwork at [url], cached by URL.
final artworkPaletteProvider = FutureProvider.family<ArtworkPalette?, String>((
  ref,
  url,
) async {
  return _paletteCache.putIfAbsent(url, () => _paletteOf(url));
});

final Map<String, Future<ArtworkPalette?>> _paletteCache =
    <String, Future<ArtworkPalette?>>{};

/// Visible for tests.
void clearArtworkPaletteCache() => _paletteCache.clear();

Future<ArtworkPalette?> _paletteOf(String url) async {
  final pixels = await _decodePixels(url);
  return pixels == null ? null : paletteFromPixels(pixels);
}

/// Builds a palette from raw RGBA bytes.
///
/// Separated from decoding so it can be exercised on synthetic images: the
/// bucketing is the part with a right answer, and it should not need a real
/// PNG on disk to be verified.
ArtworkPalette? paletteFromPixels(Uint8List bytes) {
  // Hue buckets of 15 degrees: fine enough to tell the pink of one cover from
  // its purple, coarse enough that a photograph does not scatter across them.
  const bucketCount = 24;
  final weight = List<double>.filled(bucketCount, 0);
  final red = List<double>.filled(bucketCount, 0);
  final green = List<double>.filled(bucketCount, 0);
  final blue = List<double>.filled(bucketCount, 0);
  var sumLuminance = 0.0;
  var counted = 0;

  for (var index = 0; index + 3 < bytes.length; index += 4) {
    final a = bytes[index + 3];
    if (a < 128) {
      continue;
    }
    final r = bytes[index] / 255;
    final g = bytes[index + 1] / 255;
    final b = bytes[index + 2] / 255;
    final max = math.max(r, math.max(g, b));
    final min = math.min(r, math.min(g, b));
    final lightness = (max + min) / 2;
    final saturation = max == min
        ? 0.0
        : (lightness > 0.5
              ? (max - min) / (2 - max - min)
              : (max - min) / (max + min));
    sumLuminance += lightness;
    counted += 1;

    // Near-white and near-black pixels are the cover's paper and ink, not its
    // identity; letting them vote is what made dark covers sample as grey.
    if (saturation < 0.12 || max < 0.06 || min > 0.95) {
      continue;
    }
    final hue = _hue(r, g, b, max, min);
    final bucket = ((hue / 360) * bucketCount).floor() % bucketCount;
    // Weight = coverage x saturation x a mild preference for mid lightness,
    // so a small saturated accent can outrank a large muddy field without a
    // single pixel of neon winning outright.
    final mid = 1 - (lightness - 0.5).abs();
    final w = saturation * (0.5 + 0.5 * mid);
    weight[bucket] += w;
    red[bucket] += r * w;
    green[bucket] += g * w;
    blue[bucket] += b * w;
  }

  if (counted == 0) {
    return null;
  }

  final ranked = <int>[
    for (var i = 0; i < bucketCount; i++)
      if (weight[i] > 0) i,
  ]..sort((a, b) => weight[b].compareTo(weight[a]));
  if (ranked.isEmpty) {
    // A genuinely greyscale cover: fall back to its average lightness so the
    // player still gets a sensible surface instead of no surface at all.
    final average = (sumLuminance / counted).clamp(0.0, 1.0);
    final grey = Color.fromARGB(
      255,
      (average * 255).round(),
      (average * 255).round(),
      (average * 255).round(),
    );
    return ArtworkPalette(
      primary: grey,
      secondary: grey,
      isDark: average < 0.5,
    );
  }

  Color bucketColor(int bucket) {
    final w = weight[bucket];
    return Color.fromARGB(
      255,
      ((red[bucket] / w) * 255).round().clamp(0, 255),
      ((green[bucket] / w) * 255).round().clamp(0, 255),
      ((blue[bucket] / w) * 255).round().clamp(0, 255),
    );
  }

  final primary = bucketColor(ranked.first);
  // The runner-up has to be a *different* hue, otherwise the gradient is just
  // the same colour twice and the mix does nothing.
  Color secondary = primary;
  for (final bucket in ranked.skip(1)) {
    final distance = (bucket - ranked.first).abs();
    if (math.min(distance, bucketCount - distance) >= 2) {
      secondary = bucketColor(bucket);
      break;
    }
  }

  final luminance = _relativeLuminance(primary);
  return ArtworkPalette(
    primary: primary,
    secondary: secondary,
    isDark: luminance < 0.42,
  );
}

double _hue(double r, double g, double b, double max, double min) {
  final delta = max - min;
  if (delta == 0) {
    return 0;
  }
  final hue = switch (max) {
    _ when max == r => ((g - b) / delta) % 6,
    _ when max == g => (b - r) / delta + 2,
    _ => (r - g) / delta + 4,
  };
  return (hue * 60 + 360) % 360;
}

double _relativeLuminance(Color color) {
  double channel(double value) {
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// Decodes [url] at 16px and returns its RGBA bytes.
Future<Uint8List?> _decodePixels(String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  try {
    ui.Image image;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final provider = NetworkImage(trimmed);
      final stream = provider.resolve(ImageConfiguration.empty);
      final completer = Completer<ui.Image>();
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          if (!completer.isCompleted) {
            completer.complete(info.image);
          }
          stream.removeListener(listener);
        },
        onError: (error, stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      image = await completer.future;
    } else {
      final file = File(trimmed);
      if (!await file.exists()) {
        return null;
      }
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 16);
      final frame = await codec.getNextFrame();
      image = frame.image;
    }
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data?.buffer.asUint8List();
  } on Object {
    // Artwork is decoration: a cover that cannot be decoded must not cost the
    // page its atmosphere.
    return null;
  }
}

Future<Color?> _dominantColor(String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  try {
    ui.Codec codec;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      // Network artwork is fetched through the same path the widgets use, so
      // headers and proxies behave identically.
      final provider = NetworkImage(trimmed);
      final stream = provider.resolve(ImageConfiguration.empty);
      final completer = Completer<ui.Image>();
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          if (!completer.isCompleted) {
            completer.complete(info.image);
          }
          stream.removeListener(listener);
        },
        onError: (error, stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      final image = await completer.future;
      return _averageOf(image);
    }
    // Local artwork: read through the same resolver the player uses, then
    // decode downscaled.
    final file = File(trimmed);
    if (!await file.exists()) {
      return null;
    }
    final bytes = await file.readAsBytes();
    codec = await ui.instantiateImageCodec(bytes, targetWidth: 16);
    final frame = await codec.getNextFrame();
    return _averageOf(frame.image);
  } on Object {
    // Artwork is decoration here: a cover that cannot be read must not cost
    // the page its atmosphere, let alone throw.
    return null;
  }
}

/// Mean colour of a decoded image, ignoring fully transparent pixels.
Future<Color?> _averageOf(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) {
    return null;
  }
  var red = 0;
  var green = 0;
  var blue = 0;
  var count = 0;
  final bytes = data.buffer.asUint8List();
  for (var index = 0; index + 3 < bytes.length; index += 4) {
    final alpha = bytes[index + 3];
    if (alpha < 8) {
      continue;
    }
    red += bytes[index];
    green += bytes[index + 1];
    blue += bytes[index + 2];
    count += 1;
  }
  if (count == 0) {
    return null;
  }
  return Color.fromARGB(255, red ~/ count, green ~/ count, blue ~/ count);
}

/// Paints the cover-driven wash at the top of a content region.
///
/// Renders nothing when the skin switches it off, so a matte skin keeps
/// exactly the widget tree — and the cost — it had before the token existed.
///
/// The wash is a decoration only: it never touches text colour and never
/// participates in layout, which is what lets a skin turn the atmosphere all
/// the way up without risking readability (design spec §3.4 rule 3).
class ThemeAmbient extends ConsumerWidget {
  const ThemeAmbient({
    super.key,
    required this.artworkUrl,
    required this.child,
  });

  /// Cover to derive the wash from. Null falls back to the skin's own colour.
  final String? artworkUrl;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ambient = ref.watch(activeThemeTokensProvider).components.ambient;
    if (!ambient.isVisible) {
      return child;
    }
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final url = artworkUrl?.trim();
    final derived = url == null || url.isEmpty
        ? null
        : ref.watch(artworkAccentProvider(url)).value;
    // Order matters: an explicit skin colour is a deliberate statement about
    // the brand, so it outranks whatever the cover happens to be.
    final wash = ambient.color ?? derived ?? colors.brandBase;

    if (ambient.lights.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: _AmbientLights(
                lights: ambient.lights,
                fallback: wash,
                driftSeconds: ambient.driftSeconds,
              ),
            ),
          ),
          child,
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height =
                    constraints.maxHeight * ambient.heightFraction.clamp(0, 1);
                Widget band = SizedBox(
                  height: height,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          wash.withValues(alpha: ambient.strength.clamp(0, 1)),
                          wash.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                );
                // `ambient.blur` is the design's soft-light reach: the wash is
                // blurred so it reads as light on the page rather than as a
                // second, coloured panel. Zero (the default) keeps the flat
                // gradient every pre-existing skin already had.
                if (ambient.blur > 0) {
                  band = ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: ambient.blur,
                      sigmaY: ambient.blur,
                    ),
                    child: band,
                  );
                }
                return Align(alignment: Alignment.topCenter, child: band);
              },
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Paints the ambient layer as a set of soft light sources.
///
/// Each light is a radial gradient placed at its anchor, optionally drifting
/// in a slow ellipse when the skin asks for motion. Drift is what separates
/// "a coloured rectangle" from "light": the eye reads a moving highlight as a
/// volume even when the colour is identical, and a still one reads as paint.
///
/// The ticker is created only for skins that declare `driftSeconds > 0`, so a
/// static skin pays nothing.
class _AmbientLights extends StatefulWidget {
  const _AmbientLights({
    required this.lights,
    required this.fallback,
    required this.driftSeconds,
  });

  final List<ThemeAmbientLight> lights;

  /// Colour used by lights that follow the artwork.
  final Color fallback;

  final double driftSeconds;

  @override
  State<_AmbientLights> createState() => _AmbientLightsState();
}

class _AmbientLightsState extends State<_AmbientLights>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(_AmbientLights oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.driftSeconds != widget.driftSeconds &&
        widget.driftSeconds <= 0) {
      _disposeController();
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Drift is decoration. Reduce-motion users and stepped test frames get
    // the same lights, held still, instead of an endless ticker that never
    // lets the shell settle.
    final canAnimate = widget.driftSeconds > 0 && themeMotionAllowed(context);
    if (!canAnimate) {
      if (_controller != null) {
        _disposeController();
      }
      return CustomPaint(
        painter: _AmbientLightPainter(
          lights: widget.lights,
          fallback: widget.fallback,
          phase: 0,
        ),
      );
    }
    final duration = Duration(
      milliseconds: (widget.driftSeconds * 1000).round(),
    );
    var controller = _controller;
    if (controller == null) {
      controller = AnimationController(vsync: this, duration: duration);
      _controller = controller;
    } else {
      controller.duration = duration;
    }
    if (!controller.isAnimating) {
      controller.repeat();
    }
    final active = controller;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: active,
        builder: (context, _) {
          return CustomPaint(
            painter: _AmbientLightPainter(
              lights: widget.lights,
              fallback: widget.fallback,
              phase: active.value,
            ),
          );
        },
      ),
    );
  }
}

class _AmbientLightPainter extends CustomPainter {
  const _AmbientLightPainter({
    required this.lights,
    required this.fallback,
    required this.phase,
  });

  final List<ThemeAmbientLight> lights;
  final Color fallback;

  /// 0..1 through one drift cycle.
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final rect = Offset.zero & size;
    final longest = size.longestSide;
    for (var index = 0; index < lights.length; index += 1) {
      final light = lights[index];
      final color = light.color ?? fallback;
      final opacity = light.strength.clamp(0.0, 1.0);
      if (opacity <= 0 || color.a <= 0) {
        continue;
      }
      final anchor = _drift(light.anchor, index, phase);
      final center = Offset(
        rect.center.dx + anchor.x * size.width / 2,
        rect.center.dy + anchor.y * size.height / 2,
      );
      final radius = (longest * light.radius.clamp(0.05, 4)).clamp(1.0, 8192.0);
      final paint = Paint()
        ..blendMode = materialBlendMode(light.blend)
        ..shader = ui.Gradient.radial(
          center,
          radius,
          <Color>[
            color.withValues(alpha: color.a * opacity),
            color.withValues(alpha: 0),
          ],
          const <double>[0, 1],
          ui.TileMode.clamp,
        );
      canvas.drawRect(rect, paint);
    }
  }

  /// Applies the drift cycle to one light's anchor.
  ///
  /// [index] shifts each light's phase so a multi-light skin never pulses in
  /// lockstep, which would read as a global flash rather than as light.
  ThemePoint _drift(ThemePoint anchor, int index, double phase) {
    if (phase == 0) {
      return anchor;
    }
    final shifted = (phase + index * 0.37) % 1.0;
    final angle = shifted * 2 * math.pi;
    return ThemePoint(
      anchor.x + math.cos(angle) * 0.06,
      anchor.y + math.sin(angle) * 0.06,
    );
  }

  @override
  bool shouldRepaint(_AmbientLightPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.lights != lights ||
        oldDelegate.fallback != fallback;
  }
}
