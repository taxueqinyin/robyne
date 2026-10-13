import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/domain/theme_tokens.dart';
import 'package:robyne/core/theme/infrastructure/token_resolver.dart';

void main() {
  test('the bundled typeface is MiSans and the asset is declared', () {
    // The family is only cosmetic if the file is not bundled: Flutter falls
    // back to the platform font silently, which is indistinguishable from
    // "the font is applied".
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: MiSans'));
    expect(pubspec, contains('asset: assets/fonts/MiSansVF.ttf'));
    expect(File('assets/fonts/MiSansVF.ttf').existsSync(), isTrue);

    // And the default theme actually asks for it.
    expect(ThemeTypography.baseline().fontFamily, 'MiSans');

    final theme = const TokenResolver().resolve(
      const ThemeTokens.baseline(),
      Brightness.light,
    );
    expect(theme.textTheme.bodyMedium?.fontFamily, 'MiSans');
    expect(theme.textTheme.titleLarge?.fontFamily, 'MiSans');
  });
}
