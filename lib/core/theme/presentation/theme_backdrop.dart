import 'dart:ui' as ui;
import 'dart:typed_data' show Float64List;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/theme_materials.dart';
import '../domain/theme_tokens.dart';
import '../infrastructure/theme_asset_resolver.dart';
import '../application/theme_providers.dart';
import 'theme_material.dart';

/// Resolves the active skin's background artwork once and shares it.
final themeBackdropProvider = FutureProvider<ImageBytes?>((ref) async {
  final package = ref.watch(activeThemePackageProvider);
  final image = package.tokens.background.image ?? package.assets.background;
  if (image == null || image.isEmpty) {
    return null;
  }
  return const ThemeAssetResolver().resolveBytes(package, image);
});

/// Paints the active skin's artwork behind the whole shell.
///
/// Renders nothing (and costs nothing) when the skin declares no artwork,
/// so plain-colour skins keep the exact same widget tree as before.
class ThemeBackdrop extends ConsumerWidget {
  const ThemeBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeTokensProvider);
    final backdrop = ref.watch(themeBackdropProvider);
    final background = tokens.background;

    final image = backdrop.value;
    if (image == null || background.image == null) {
      return child;
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: _BackdropArtwork(
            provider: _sized(image.provider, context, background.fillMode),
            background: background,
          ),
        ),
        if (_hasOverlay(background))
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _BackdropOverlayPainter(background),
                isComplex: !background.overlayGradient.isEmpty,
              ),
            ),
          ),
        for (final layer in background.layers)
          if (!layer.isEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _BackdropLayerPainter(layer),
                  isComplex: !layer.gradient.isEmpty,
                ),
              ),
            ),
        Positioned.fill(child: child),
      ],
    );
  }

  static bool _hasOverlay(ThemeBackground background) {
    final hasFlat =
        background.overlay != null && background.overlayOpacity > 0;
    return hasFlat || !background.overlayGradient.isEmpty;
  }

  /// Wraps [provider] so the decoder never expands it beyond what we can
  /// show.
  ///
  /// A few KB of PNG can describe an enormous image; decoding one at full
  /// size would exhaust memory. Tiled artwork repeats a single tile, so it
  /// gets a small fixed cap instead of a screen-sized one.
  static ImageProvider _sized(
    ImageProvider provider,
    BuildContext context,
    ThemeBackgroundFillMode fillMode,
  ) {
    final width = fillMode == ThemeBackgroundFillMode.tile
        ? 512
        : _displayWidth(context);
    if (width == null) {
      return provider;
    }
    return ResizeImage.resizeIfNeeded(width, null, provider);
  }

  /// Width to decode the backdrop at, in device pixels.
  static int? _displayWidth(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width <= 0) {
      return 4096;
    }
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final width = (size.width * (ratio > 0 ? ratio : 1)).round();
    return width.clamp(1, 4096);
  }
}

/// The artwork itself, with the skin's zoom and colour treatment applied.
///
/// A full-bleed photo is the one background a music player cannot just paint
/// raw: it has to be calm enough to read against. Zoom, blur and the colour
/// matrix are what make "photo as wallpaper" usable instead of a readability
/// hazard.
class _BackdropArtwork extends StatelessWidget {
  const _BackdropArtwork({required this.provider, required this.background});

  final ImageProvider provider;
  final ThemeBackground background;

  @override
  Widget build(BuildContext context) {
    Widget artwork = Image(
      image: provider,
      fit: switch (background.fillMode) {
        ThemeBackgroundFillMode.cover => BoxFit.cover,
        ThemeBackgroundFillMode.contain => BoxFit.contain,
        ThemeBackgroundFillMode.stretch => BoxFit.fill,
        ThemeBackgroundFillMode.tile => BoxFit.none,
      },
      repeat: background.fillMode == ThemeBackgroundFillMode.tile
          ? ImageRepeat.repeat
          : ImageRepeat.noRepeat,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    final scale = background.scale.clamp(1.0, 4.0);
    if (scale > 1) {
      // Scaling up rather than merely fitting hides the transparent fringe a
      // blur leaves at the edges, which would otherwise read as a vignette.
      artwork = Transform.scale(scale: scale, child: artwork);
    }
    final needsBlur = background.blur > 0;
    final matrix = _backgroundMatrix(background);
    if (needsBlur || matrix != null) {
      artwork = ColorFiltered(
        colorFilter: matrix == null
            ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
            : ColorFilter.matrix(Float64List.fromList(matrix)),
        child: needsBlur
            ? ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: background.blur,
                  sigmaY: background.blur,
                  tileMode: TileMode.decal,
                ),
                child: artwork,
              )
            : artwork,
      );
    }
    return artwork;
  }

  /// Saturation/brightness/contrast/grayscale for the artwork, or null when
  /// every one of them is identity.
  static List<double>? _backgroundMatrix(ThemeBackground background) {
    if (background.saturation == 1 &&
        background.brightness == 1 &&
        background.contrast == 1 &&
        background.grayscale == 0) {
      return null;
    }
    // Reuses the material colour-matrix math by describing the artwork as a
    // "material": one interpretation of saturation/brightness/contrast keeps
    // a background and a frosted panel from grading differently.
    final material = ThemeMaterial(
      saturation: background.saturation,
      brightness: background.brightness,
      contrast: background.contrast,
      grayscale: background.grayscale,
    );
    return materialColorMatrix(material);
  }
}

/// Paints a background's flat scrim and/or overlay gradient in one pass.
class _BackdropOverlayPainter extends CustomPainter {
  const _BackdropOverlayPainter(this.background);

  final ThemeBackground background;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final blend = materialBlendMode(background.overlayBlend);
    final overlay = background.overlay;
    final opacity = background.overlayOpacity.clamp(0.0, 1.0);
    if (overlay != null && opacity > 0) {
      canvas.drawRect(
        rect,
        Paint()
          ..color = overlay.withValues(alpha: overlay.a * opacity)
          ..blendMode = blend,
      );
    }
    final shader = materialGradientShader(background.overlayGradient, rect);
    if (shader != null) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = shader
          ..blendMode = blend,
      );
    }
  }

  @override
  bool shouldRepaint(_BackdropOverlayPainter oldDelegate) {
    return oldDelegate.background != background;
  }
}

/// Paints one extra colour-grading layer.
class _BackdropLayerPainter extends CustomPainter {
  const _BackdropLayerPainter(this.layer);

  final ThemeBackgroundLayer layer;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final opacity = layer.opacity.clamp(0.0, 1.0);
    if (opacity <= 0) {
      return;
    }
    final blend = materialBlendMode(layer.blend);
    final color = layer.color;
    if (color != null) {
      canvas.drawRect(
        rect,
        Paint()
          ..color = color.withValues(alpha: color.a * opacity)
          ..blendMode = blend,
      );
    }
    final shader = materialGradientShader(layer.gradient, rect);
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
  bool shouldRepaint(_BackdropLayerPainter oldDelegate) {
    return oldDelegate.layer != layer;
  }
}

/// A translucent, optionally blurred panel used by the shell chrome.
///
/// When the skin sets `effects.blur` above zero this produces the frosted
/// glass look; with blur zero it degrades to a plain filled panel, so skins
/// that do not want the effect pay no cost.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.tokens,
    this.blurScale = 1,
    this.opacityScale = 1,
    this.borderRadius,
    this.border,
    this.child,
  });

  final ThemeTokens tokens;
  final double blurScale;
  final double opacityScale;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final blur = tokens.effects.blur * blurScale;
    final opacity = (tokens.effects.glassOpacity * opacityScale).clamp(
      0.0,
      1.0,
    );

    Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.color.backgroundBase.withValues(alpha: opacity),
        borderRadius: borderRadius,
        border: border,
      ),
      child: child,
    );

    if (blur > 0) {
      panel = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: panel,
      );
    }
    return panel;
  }
}
