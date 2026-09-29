import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Guards the "no hard-coded look" rule from `docs/THEME_ROADMAP.md` stage 1.
///
/// A skin can only restyle what widgets read from tokens. A literal
/// `Colors.white` or `BorderRadius.circular(8)` inside a feature page is
/// invisible to every skin, so those literals silently accumulate until the
/// app is no longer skinnable at all. This test fails the build when a new
/// one appears.
void main() {
  final libRoot = Directory(p.join(Directory.current.path, 'lib'));
  final featureRoot = Directory(p.join(libRoot.path, 'features'));

  List<File> dartFiles(Directory root) {
    if (!root.existsSync()) {
      return const <File>[];
    }
    return root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);
  }

  /// Lines that legitimately hard-code a value, with a stated reason.
  ///
  /// The desktop lyric window is a separate engine with its own always-dark
  /// surface and is deliberately outside the skin system
  /// (`THEME_DECISIONS.md` Q2 chose to leave it alone for now).
  // The desktop lyric and tray panel windows are separate desktop engine
  // surfaces. They are intentionally outside the skin system for now, so
  // their always-dark chrome does not pretend to be skin-token driven.
  final allowListed = <String>{
    'desktop_lyric_window.dart',
    'tray_panel_window.dart',
  };

  test('feature pages do not hard-code Material colours', () {
    final offenders = <String>[];
    for (final file in dartFiles(featureRoot)) {
      if (allowListed.contains(p.basename(file.path))) {
        continue;
      }
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index];
        final trimmed = line.trim();
        if (trimmed.startsWith('//')) {
          continue;
        }
        // `Colors.transparent` is a structural intent ("no fill"), not a
        // colour choice, and `Colors.amber` used as a null-fallback for a
        // missing theme is not a styling decision either.
        if (RegExp(r'\bColors\.(?!transparent\b|amber\b)\w+').hasMatch(line)) {
          offenders.add(
            '${p.relative(file.path, from: libRoot.path)}:${index + 1}: $trimmed',
          );
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Use RobyneTheme.of(context).tokens instead of Colors.* so '
          'skins can restyle the surface.',
    );
  });

  test('feature pages do not hard-code numeric corner radii', () {
    final offenders = <String>[];
    for (final file in dartFiles(featureRoot)) {
      if (allowListed.contains(p.basename(file.path))) {
        continue;
      }
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index];
        final trimmed = line.trim();
        if (trimmed.startsWith('//')) {
          continue;
        }
        if (RegExp(r'BorderRadius\.circular\(\s*\d').hasMatch(line)) {
          offenders.add(
            '${p.relative(file.path, from: libRoot.path)}:${index + 1}: $trimmed',
          );
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Use RobyneTheme.of(context).tokens.radius so a skin can change '
          'corner shape.',
    );
  });

  test('the guard actually inspects the feature tree', () {
    // Guards against the scan silently passing because the path changed.
    expect(dartFiles(featureRoot).length, greaterThan(10));
  });
}
