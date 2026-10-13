import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/presentation/theme_ambient.dart';

void main() {
  group('artwork palette extraction', () {
    test('picks the cover\'s dominant hue, not its average', () {
      // 80% deep pink, 20% green: averaging these two gives a muddy grey that
      // belongs to neither, which is the bug the histogram exists to avoid.
      final bytes = _pixels(<_Patch>[
        (const Color(0xFFD94F9E), 80),
        (const Color(0xFF4CAF50), 20),
      ]);

      final palette = paletteFromPixels(bytes)!;
      final primary = HSLColor.fromColor(palette.primary);

      expect(
        primary.hue,
        closeTo(HSLColor.fromColor(const Color(0xFFD94F9E)).hue, 20),
        reason: 'the pink covers four fifths of the image',
      );
    });

    test('ignores white and black paper when the cover is mostly one art', () {
      // A character on a white field: the white must not win.
      final bytes = _pixels(<_Patch>[
        (const Color(0xFFFFFFFF), 60),
        (const Color(0xFF2E5BFF), 40),
      ]);

      final palette = paletteFromPixels(bytes)!;
      final hue = HSLColor.fromColor(palette.primary).hue;
      expect(hue, closeTo(HSLColor.fromColor(const Color(0xFF2E5BFF)).hue, 20));
    });

    test('a second colour comes from a different hue', () {
      final bytes = _pixels(<_Patch>[
        (const Color(0xFFD94F9E), 50),
        (const Color(0xFF2E5BFF), 50),
      ]);

      final palette = paletteFromPixels(bytes)!;
      final first = HSLColor.fromColor(palette.primary).hue;
      final second = HSLColor.fromColor(palette.secondary).hue;
      // More than two buckets apart, otherwise a gradient of the two is a
      // gradient of one colour.
      expect((first - second).abs(), greaterThan(20));
    });

    test('reports whether the sampled colour needs light or dark ink', () {
      final dark = paletteFromPixels(
        _pixels(<_Patch>[(const Color(0xFF102A6B), 100)]),
      )!;
      final bright = paletteFromPixels(
        _pixels(<_Patch>[(const Color(0xFFFFF3A0), 100)]),
      )!;

      expect(dark.isDark, isTrue);
      expect(dark.onColor, const Color(0xFFFFFFFF));
      expect(bright.isDark, isFalse);
      expect(bright.onColor, const Color(0xFF1A1A22));
    });

    test('a greyscale cover still yields a usable palette', () {
      // No bucket can win a hue vote, so the extractor must fall back to
      // lightness rather than returning null and leaving the player unthemed.
      final bytes = _pixels(<_Patch>[(const Color(0xFF808080), 100)]);
      final palette = paletteFromPixels(bytes)!;
      expect(palette.primary, isNotNull);
      expect(palette.primary.r, closeTo(palette.primary.b, 0.01));
    });

    test('an empty buffer is not a palette', () {
      expect(paletteFromPixels(Uint8List(0)), isNull);
    });
  });
}

typedef _Patch = (Color color, int count);

/// Builds an RGBA buffer out of colour/count pairs.
Uint8List _pixels(List<_Patch> patches) {
  final builder = BytesBuilder();
  for (final (color, count) in patches) {
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    for (var i = 0; i < count; i++) {
      builder.add(<int>[r, g, b, 255]);
    }
  }
  return builder.toBytes();
}
