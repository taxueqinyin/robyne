import 'dart:convert';
import 'dart:io';

import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/infrastructure/theme_manifest_parser.dart';

/// The bundled flagship skin《玄》, parsed from the manifest that ships.
///
/// Reading the real file keeps tests honest: a skin that loses its `strings`,
/// `layout.home` or component tokens shows up as a failure rather than as a
/// silent fallback to the neutral defaults.
///
/// Tests use this instead of letting the app load the skin itself because the
/// bundle read needs a real async gap, and a widget test's fake clock does not
/// provide one. Overriding `baseThemePackageProvider` with the parsed package
/// exercises the same rendering path with none of the timing.
ThemePackage xuanFixture() {
  final decoded =
      jsonDecode(File('assets/themes/xuan/theme.json').readAsStringSync())
          as Map<String, Object?>;
  return const ThemeManifestParser().tryParse(
    decoded,
    source: ThemeSource.builtIn,
  )!;
}
