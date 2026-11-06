import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Deterministic gradient artwork for the design-board screenshots.
///
/// The flagship skin's identity is its material layer — frosted chrome, the
/// hero gradient, the ambient wash — and every one of those needs a real
/// picture underneath it. A null `artworkUrl` renders the grey placeholder
/// instead, which would make the boards useless for judging the skin.
///
/// Written to a temp directory at run time rather than shipped as files:
/// `ArtworkView` resolves `file://` urls itself (`artwork_view.dart:91`), so
/// this needs no seam in production code, and a binary nobody can diff stays
/// out of the repository.
///
/// The colour ramp is the one `docs/design/mockups/index.html` uses for its
/// `.a1`..`.a8` placeholders, so a board and its mockup ancestor stay
/// visually comparable.
abstract final class FixtureArtwork {
  /// The artwork for [index], wrapping around the ramp.
  ///
  /// Null until [install] has run; call that from `setUpAll`.
  static String? urlFor(int index) {
    final directory = _directory;
    if (directory == null) {
      return null;
    }
    return File('$directory/a${index % _ramp.length + 1}.png').uri.toString();
  }

  static String? _directory;

  static const List<List<Color>> _ramp = <List<Color>>[
    <Color>[Color(0xFFFF9A6B), Color(0xFFC1472A), Color(0xFF6D2015)],
    <Color>[Color(0xFF8FE0D0), Color(0xFF2E8C86), Color(0xFF12474D)],
    <Color>[Color(0xFFA896F5), Color(0xFF5B45B8), Color(0xFF251A56)],
    <Color>[Color(0xFFFFD98C), Color(0xFFC8912F), Color(0xFF6B4711)],
    <Color>[Color(0xFFF5A6BD), Color(0xFFA63E63), Color(0xFF4B162E)],
    <Color>[Color(0xFF9CBFF5), Color(0xFF3E60A8), Color(0xFF1A2850)],
    <Color>[Color(0xFFCFE884), Color(0xFF6E9A2E), Color(0xFF2F4718)],
    <Color>[Color(0xFFF2A9D8), Color(0xFF8E3E96), Color(0xFF391642)],
  ];

  /// Paints every ramp entry and remembers where they landed.
  static Future<void> install() async {
    final directory = Directory(
      p.join(Directory.systemTemp.path, 'robyne_fixture_artwork'),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    for (var index = 0; index < _ramp.length; index += 1) {
      final file = File(p.join(directory.path, 'a${index + 1}.png'));
      await file.writeAsBytes(await paint(_ramp[index]), flush: true);
    }
    _directory = directory.path;
  }

  /// Exposed so a board can paint one cover without the whole ramp.
  static Future<List<int>> paint(List<Color> colors) async {
    const size = 256.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Offset.zero & const Size(size, size);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          colors,
          const <double>[0, 0.58, 1],
        ),
    );
    // Two soft lights, matching the mockup's `::after` / `::before`: without
    // them every cover is a flat ramp and the board reads as a colour chart
    // rather than as artwork.
    canvas.drawCircle(
      Offset(size * 0.18, size * 0.12),
      size * 0.55,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size * 0.18, size * 0.12),
          size * 0.55,
          const <Color>[Color(0x3DFFFFFF), Color(0x00FFFFFF)],
        ),
    );
    canvas.drawCircle(
      Offset(size * 0.82, size * 0.84),
      size * 0.38,
      Paint()..color = const Color(0x21FFFFFF),
    );

    final image = await recorder.endRecording().toImage(
      size.round(),
      size.round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }
}
