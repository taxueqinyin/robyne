import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/infrastructure/token_resolver.dart';

/// What the app looks like *before* the skin finishes loading.
///
/// The shell renders on the first frame, and the skin arrives a few
/// milliseconds later. If the stand-in is the light baseline, the user sees a
/// white/blue flash of the retired default theme on every cold start, which is
/// exactly the look 《玄》 replaced.
void main() {
  test('the pre-load stand-in is already the flagship palette', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final placeholder = container.read(baseThemePackageProvider);
    final resolved = const TokenResolver().resolve(
      placeholder.tokens,
      Brightness.dark,
      placeholder.mode,
    );
    final background = resolved.scaffoldBackgroundColor;

    // Dark, not the light baseline.
    expect(
      background.computeLuminance(),
      lessThan(0.1),
      reason: 'the first frame must not flash a light theme',
    );
    expect(placeholder.mode, ThemeModePreference.dark);
  });
}
