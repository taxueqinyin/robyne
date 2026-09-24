import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/domain/theme_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

final desktopLyricThemeServiceProvider = Provider<DesktopLyricThemeService>((
  ref,
) {
  return DesktopLyricThemeService();
});

class DesktopLyricTheme {
  const DesktopLyricTheme({
    required this.backgroundColorValue,
    required this.titleColorValue,
    required this.subtitleColorValue,
    this.lyricColorValue = 0xFFFFFFFF,
  });

  const DesktopLyricTheme.defaultTheme()
    : backgroundColorValue = 0xFF1C221F,
      titleColorValue = 0xFF9FC9BA,
      subtitleColorValue = 0xFF7CA696,
      lyricColorValue = 0xFFFFFFFF;

  final int backgroundColorValue;
  final int titleColorValue;
  final int subtitleColorValue;
  final int lyricColorValue;

  Color get backgroundColor => Color(backgroundColorValue);
  Color get titleColor => Color(titleColorValue);
  Color get subtitleColor => Color(subtitleColorValue);
  Color get lyricColor => Color(lyricColorValue);

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'backgroundColorValue': backgroundColorValue,
      'titleColorValue': titleColorValue,
      'subtitleColorValue': subtitleColorValue,
      'lyricColorValue': lyricColorValue,
    };
  }

  factory DesktopLyricTheme.fromJson(Map<Object?, Object?> json) {
    const fallback = DesktopLyricTheme.defaultTheme();
    return DesktopLyricTheme(
      backgroundColorValue:
          (json['backgroundColorValue'] as num?)?.toInt() ??
          fallback.backgroundColorValue,
      titleColorValue:
          (json['titleColorValue'] as num?)?.toInt() ??
          fallback.titleColorValue,
      subtitleColorValue:
          (json['subtitleColorValue'] as num?)?.toInt() ??
          fallback.subtitleColorValue,
      lyricColorValue:
          (json['lyricColorValue'] as num?)?.toInt() ??
          fallback.lyricColorValue,
    );
  }

  factory DesktopLyricTheme.fromAccent(Color accent) {
    final hsl = HSLColor.fromColor(accent);
    final hue = hsl.hue;
    final titleSaturation = hsl.saturation.clamp(0.18, 0.40).toDouble();
    final subtitleSaturation = (titleSaturation * 0.72).clamp(0.14, 0.28);
    final backgroundSaturation = (titleSaturation * 0.42).clamp(0.08, 0.16);
    return DesktopLyricTheme(
      backgroundColorValue: HSLColor.fromAHSL(
        1,
        hue,
        backgroundSaturation,
        0.12,
      ).toColor().toARGB32(),
      titleColorValue: HSLColor.fromAHSL(
        1,
        hue,
        titleSaturation,
        0.70,
      ).toColor().toARGB32(),
      subtitleColorValue: HSLColor.fromAHSL(
        1,
        hue,
        subtitleSaturation,
        0.56,
      ).toColor().toARGB32(),
    );
  }

  /// Builds a lyric theme from the active skin's tokens.
  ///
  /// Used when the current track has no artwork, so the desktop lyric window
  /// still follows the user's chosen skin instead of snapping to the default.
  factory DesktopLyricTheme.fromTokens(ThemeTokens tokens) {
    final brand = tokens.color.brandBase;
    final background = tokens.color.backgroundBase;
    return DesktopLyricTheme(
      backgroundColorValue: background.toARGB32(),
      titleColorValue: brand.toARGB32(),
      subtitleColorValue: tokens.color.textSecondary.toARGB32(),
      lyricColorValue: tokens.color.textPrimary.toARGB32(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is DesktopLyricTheme &&
        other.backgroundColorValue == backgroundColorValue &&
        other.titleColorValue == titleColorValue &&
        other.subtitleColorValue == subtitleColorValue &&
        other.lyricColorValue == lyricColorValue;
  }

  @override
  int get hashCode => Object.hash(
    backgroundColorValue,
    titleColorValue,
    subtitleColorValue,
    lyricColorValue,
  );
}

class DesktopLyricThemeService {
  final _themeCache = <String, Future<DesktopLyricTheme>>{};

  Future<DesktopLyricTheme> resolve(String? artworkUrl) {
    final normalized = artworkUrl?.trim();
    if (normalized == null || normalized.isEmpty) {
      return Future<DesktopLyricTheme>.value(
        const DesktopLyricTheme.defaultTheme(),
      );
    }
    return _themeCache.putIfAbsent(
      normalized,
      () => _resolveFromArtwork(normalized),
    );
  }

  Future<DesktopLyricTheme> _resolveFromArtwork(String artworkUrl) async {
    try {
      final bytes = await _loadArtworkBytes(artworkUrl);
      if (bytes == null || bytes.isEmpty) {
        return const DesktopLyricTheme.defaultTheme();
      }
      final accent = await _extractDominantColor(bytes);
      if (accent == null) {
        return const DesktopLyricTheme.defaultTheme();
      }
      return DesktopLyricTheme.fromAccent(accent);
    } catch (_) {
      return const DesktopLyricTheme.defaultTheme();
    }
  }

  Future<Uint8List?> _loadArtworkBytes(String artworkUrl) async {
    final uri = Uri.tryParse(artworkUrl);
    if (uri == null) {
      return null;
    }
    if (uri.scheme == 'file') {
      final file = File.fromUri(uri);
      return await file.exists() ? file.readAsBytes() : null;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      final file = File(artworkUrl);
      return await file.exists() ? file.readAsBytes() : null;
    }
    final cachedFile = await _cacheFileForUrl(artworkUrl);
    if (await cachedFile.exists() && await cachedFile.length() > 0) {
      return cachedFile.readAsBytes();
    }
    final tempFile = File('${cachedFile.path}.download');
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      await response.pipe(tempFile.openWrite());
      if (await cachedFile.exists()) {
        await cachedFile.delete();
      }
      await tempFile.rename(cachedFile.path);
      return cachedFile.readAsBytes();
    } catch (_) {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<Color?> _extractDominantColor(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 32,
      targetHeight: 32,
    );
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data == null) {
          return null;
        }
        return _dominantColorFromByteData(data);
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  Color? _dominantColorFromByteData(ByteData data) {
    final buckets = <int, _ColorBucket>{};
    for (var offset = 0; offset <= data.lengthInBytes - 4; offset += 4) {
      final red = data.getUint8(offset);
      final green = data.getUint8(offset + 1);
      final blue = data.getUint8(offset + 2);
      final alpha = data.getUint8(offset + 3);
      if (alpha < 180) {
        continue;
      }
      final hsl = HSLColor.fromColor(Color.fromARGB(alpha, red, green, blue));
      if (hsl.lightness < 0.08 || hsl.lightness > 0.92) {
        continue;
      }
      final bucketId = ((red >> 4) << 8) | ((green >> 4) << 4) | (blue >> 4);
      final weight = 1 + hsl.saturation * 2;
      buckets
          .putIfAbsent(bucketId, _ColorBucket.new)
          .add(red, green, blue, weight);
    }
    if (buckets.isEmpty) {
      return null;
    }
    final dominant = buckets.values.reduce((left, right) {
      return left.weight >= right.weight ? left : right;
    });
    return dominant.color;
  }

  Future<File> _cacheFileForUrl(String url) async {
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}/robyne_artwork_cache',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}/${_stableHash(url)}.img');
  }

  String _stableHash(String value) {
    var hash = 0xcbf29ce484222325;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16);
  }
}

class _ColorBucket {
  double weight = 0;
  double redTotal = 0;
  double greenTotal = 0;
  double blueTotal = 0;

  void add(int red, int green, int blue, double nextWeight) {
    weight += nextWeight;
    redTotal += red * nextWeight;
    greenTotal += green * nextWeight;
    blueTotal += blue * nextWeight;
  }

  Color get color {
    if (weight <= 0) {
      return const Color(0xFF9FC9BA);
    }
    return Color.fromARGB(
      255,
      (redTotal / weight).round().clamp(0, 255),
      (greenTotal / weight).round().clamp(0, 255),
      (blueTotal / weight).round().clamp(0, 255),
    );
  }
}
