import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/theme_providers.dart';
import '../infrastructure/theme_asset_resolver.dart';

/// Resolves one declared skin asset for the active theme.
///
/// Skins may be built in (loaded from the bundle) or installed on disk, so the
/// widget goes through [ThemeAssetResolver] instead of `Image.asset`. A
/// missing or oversized file resolves to null, and the caller supplies the
/// design fallback.
final themeAssetImageProvider = FutureProvider.family<ImageBytes?, String>((
  ref,
  asset,
) async {
  final package = ref.watch(activeThemePackageProvider);
  return const ThemeAssetResolver().resolveBytes(package, asset);
});

/// Renders a skin asset with a fallback widget when it is absent.
class ThemeAssetImage extends ConsumerWidget {
  const ThemeAssetImage({
    super.key,
    required this.asset,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  /// Asset path as declared by the skin, e.g. `assets/logo.png`.
  final String? asset;

  /// Shown while loading, when absent, or when the file fails to decode.
  final Widget fallback;

  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = asset?.trim();
    if (path == null || path.isEmpty) {
      return fallback;
    }
    final resolved = ref.watch(themeAssetImageProvider(path));
    return resolved.maybeWhen(
      data: (bytes) {
        if (bytes == null) {
          return fallback;
        }
        return Image(
          image: bytes.provider,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => fallback,
        );
      },
      orElse: () => fallback,
    );
  }
}
