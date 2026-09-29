import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/theme_providers.dart';
import '../domain/theme_icons.dart';
import '../domain/theme_package.dart';
import 'theme_asset_image.dart';

/// Default glyph size, matching Flutter's own [Icon] fallback.
///
/// A skin-declared glyph has no ambient `IconTheme` size to inherit from once
/// it stops going through [Icon], so it needs the same default the framework
/// uses instead of letting `Text` pick up the surrounding body size.
const double _kDefaultGlyphSize = 24.0;

/// An icon the active skin may have replaced.
///
/// Every chrome icon in the app renders through this widget so a skin that
/// redraws glyphs changes the rail, the tab strip and the transport row at
/// once — the surfaces cannot drift apart, exactly as [_NavLabel] does for
/// text.
///
/// The fallback matters more than the override: if the declaration is missing,
/// the glyph does not resolve, or the shipped image fails to decode, the
/// built-in [fallback] renders. A skin must never be able to remove a control.
class ThemeIconView extends ConsumerWidget {
  const ThemeIconView({
    super.key,
    required this.slot,
    required this.fallback,
    this.size,
    this.color,
    this.active = false,
  });

  /// Which slot to look up. Using the key rather than a raw `IconData` is
  /// what keeps the slot set closed: the app decides which icons exist.
  final ThemeIconKey slot;

  /// The built-in glyph, used whenever the skin declares nothing usable.
  final IconData fallback;

  /// Logical size. A declared `size` on the icon wins over this.
  final double? size;

  final Color? color;

  /// Whether the surface is showing this icon in its selected state.
  ///
  /// Rails and tabs say "you are here" by swapping an outline for a filled
  /// shape; a skin can declare that twin via `activeGlyph` / `activeImage`.
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final package = ref.watch(activeThemePackageProvider);
    final declaration = package.icons[slot];
    final resolvedSize = declaration?.size ?? size;
    final resolvedColor = declaration?.colorFor(active: active) ?? color;
    final fontFamily = _fontFamily(ref, package, declaration, active: active);

    if (declaration == null || !declaration.isRenderable(active: active)) {
      return Icon(fallback, size: resolvedSize, color: resolvedColor);
    }

    final codePoint = declaration.codePointFor(active: active);
    if (codePoint != null) {
      // Rendered as text rather than through `Icon(IconData(...))`: a code
      // point is only known at runtime, and a non-constant `IconData` makes
      // the release build's icon tree-shaker refuse to run at all. The
      // widget below is what `Icon` builds internally, so the pixels are the
      // same and ConstFinder sees no runtime `IconData`.
      return _SkinGlyph(
        codePoint: codePoint,
        fontFamily: fontFamily,
        size: resolvedSize,
        color: resolvedColor,
      );
    }

    final image = declaration.imageFor(active: active);
    if (image != null) {
      return _IconImage(
        asset: image,
        size: resolvedSize,
        color: resolvedColor,
        fallback: fallback,
      );
    }
    return Icon(fallback, size: resolvedSize, color: resolvedColor);
  }

  /// Which font a [declaration]'s code point indexes into.
  ///
  /// A per-icon `fontFamily` wins; otherwise a skin that ships an icon font
  /// uses it for its `glyph` declarations but *not* for bare Material
  /// `codePoint` ones, since those are written against Material's own font.
  static String? _fontFamily(
    WidgetRef ref,
    ThemePackage package,
    ThemeIcon? declaration, {
    required bool active,
  }) {
    if (declaration == null) {
      return null;
    }
    final perIcon = declaration.fontFamily;
    if (perIcon != null && perIcon.isNotEmpty) {
      return perIcon;
    }
    if (!declaration.usesIconFont(active: active)) {
      return null;
    }
    // The load is async, so the deterministic fallback name is used until it
    // settles — reading it here rather than in `iconsFontFamily` keeps the
    // domain model synchronous and the widget reactive.
    return ref
            .watch(activeSkinIconFontFamilyProvider)
            .maybeWhen(data: (family) => family, orElse: () => null) ??
        package.iconsFontFamily;
  }
}

/// One glyph from a skin-declared code point, drawn as text.
///
/// Mirrors what [Icon] builds internally — the string form of the code point
/// in a non-inherited [TextStyle] at `height: 1`, centred in a square — so a
/// declared glyph lands on the same pixels an `Icon` would have produced.
///
/// Going through [Icon] would mean building an [IconData] with a runtime code
/// point; the release icon tree-shaker rejects any non-constant `IconData`,
/// which would make the whole skin-icon feature unshippable in release.
class _SkinGlyph extends StatelessWidget {
  const _SkinGlyph({
    required this.codePoint,
    required this.fontFamily,
    required this.size,
    required this.color,
  });

  final int codePoint;
  final String? fontFamily;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final glyphSize = size ?? IconTheme.of(context).size ?? _kDefaultGlyphSize;
    final glyphColor = color ?? IconTheme.of(context).color;
    return ExcludeSemantics(
      child: SizedBox(
        width: glyphSize,
        height: glyphSize,
        child: Center(
          child: RichText(
            overflow: TextOverflow.visible,
            textDirection: Directionality.of(context),
            text: TextSpan(
              text: String.fromCharCode(codePoint),
              style: TextStyle(
                inherit: false,
                color: glyphColor,
                fontSize: glyphSize,
                fontFamily: fontFamily,
                // Vertically centre the glyph in its square, as `Icon` does.
                height: 1.0,
                leadingDistribution: TextLeadingDistribution.even,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A raster icon shipped by the skin, with the built-in glyph as fallback.
class _IconImage extends StatelessWidget {
  const _IconImage({
    required this.asset,
    required this.size,
    required this.color,
    required this.fallback,
  });

  final String asset;
  final double? size;
  final Color? color;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ColorFiltered(
        // Raster icons are authored in one colour; tinting is how a declared
        // mark still follows the skin's foreground on hover/selected states.
        colorFilter: color == null
            ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
            : ColorFilter.mode(color!, BlendMode.srcIn),
        child: ThemeAssetImage(
          asset: asset,
          fit: BoxFit.contain,
          // A missing or oversized asset must not leave an empty hole where a
          // control was: fall back to the glyph the app would have drawn.
          fallback: Icon(fallback, size: size, color: color),
        ),
      ),
    );
  }
}
