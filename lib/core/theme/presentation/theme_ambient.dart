import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/application/theme_providers.dart';
import '../../theme/infrastructure/token_resolver.dart';

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
