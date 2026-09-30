import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
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
