import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/theme_tokens.dart';
import '../infrastructure/theme_asset_resolver.dart';
import '../application/theme_providers.dart';

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
          child: Image(
            image: _sized(image.provider, context, background.fillMode),
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
          ),
        ),
        if (background.overlay != null && background.overlayOpacity > 0)
          Positioned.fill(
            child: ColoredBox(
              color: background.overlay!.withValues(
                alpha: background.overlayOpacity.clamp(0.0, 1.0),
              ),
            ),
          ),
        Positioned.fill(child: child),
      ],
    );
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
