import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the one thing that can make a release build refuse to run at all.
///
/// `flutter build apk` runs an icon tree-shaker that scans the compiled kernel
/// for `IconData` instances. A *non-constant* one cannot be analysed, so the
/// tool exits instead of shipping: the skin-icon feature — which resolves a
/// code point from JSON at runtime — is exactly the shape of code that trips
/// it. This test is the guard, because the failure only appears in a release
/// build and `flutter test` never produces an `app.dill`.
///
/// It checks the source rather than the kernel: every `IconData(...)` in
/// `lib/` must be reachable from a `const` context. That is a textual
/// heuristic, but the failure it protects against is all-or-nothing, so an
/// occasional false positive beats a broken release.
void main() {
  final libDir = Directory('lib');

  List<File> dartFiles() {
    return libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
  }

  /// Strips `//` line comments so prose about `IconData` is not scanned.
  String stripLineComments(String source) {
    return source.split('\n').map((line) => line.split('//').first).join('\n');
  }

  test('every IconData in lib/ is built in a const context', () {
    final offenders = <String>[];
    final iconDataPattern = RegExp(r'\bIconData\s*\(');

    for (final file in dartFiles()) {
      final code = stripLineComments(file.readAsStringSync());
      final lines = code.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final match = iconDataPattern.firstMatch(line);
        if (match == null) {
          continue;
        }
        // `const` may sit on the construction itself or on the enclosing
        // declaration a few lines above, e.g.
        //   static const IconData play =
        //       IconData(0xE037);
        final window = <String>[
          line,
          if (i > 0) lines[i - 1],
          if (i > 1) lines[i - 2],
          if (i > 2) lines[i - 3],
        ];
        final isConst = window.any((text) => text.contains('const'));
        if (!isConst) {
          offenders.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'a runtime IconData breaks the release icon tree-shaker; '
          'see docs/THEME_AUTHORING.md — draw skin glyphs as text instead',
    );
  });
}
