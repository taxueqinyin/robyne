import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/domain/theme_tokens.dart';
import 'package:robyne/core/theme/infrastructure/token_resolver.dart';

void main() {
  testWidgets('FIX 1: bundled skins load from the asset bundle', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('probe'))),
    );
    final ctx = tester.element(find.text('probe'));
    for (final p in const <String>[
      'assets/themes/official-light/theme.json',
      'assets/themes/official-dark/theme.json',
      'assets/themes/official-midnight/theme.json',
    ]) {
      String result;
      try {
        await DefaultAssetBundle.of(ctx).loadString(p);
        result = 'OK';
      } catch (e) {
        result = 'FAIL';
      }
      expect(result, 'OK', reason: '$p must be loadable from the bundle');
    }
  });

  test('FIX 2: light and dark resolve to different backgrounds', () {
    const tokens = ThemeTokens.baseline();
    final light = const TokenResolver().resolve(tokens, Brightness.light);
    final dark = const TokenResolver().resolve(tokens, Brightness.dark);
    expect(
      light.scaffoldBackgroundColor,
      isNot(dark.scaffoldBackgroundColor),
      reason: 'forcing dark must change what the user sees',
    );
  });

  test('FIX 2: a dark skin forced into light mode stays readable', () {
    const resolver = TokenResolver();
    final darkTokens = ThemeTokens.baseline().copyWith(
      color: ThemeColors.baseline().copyWith(
        backgroundBase: const Color(0xFF14161A),
        textPrimary: const Color(0xFFE8EAED),
      ),
    );
    final forcedLight = resolver.resolve(
      darkTokens,
      Brightness.light,
      ThemeModePreference.dark,
    );
    // The neutral background follows the requested brightness...
    expect(forcedLight.scaffoldBackgroundColor, isNot(const Color(0xFF14161A)));
    // ...while the dark text theme is no longer applied on top of a light
    // surface, which is the pairing that made text invisible before.
    expect(forcedLight.brightness, Brightness.light);
  });

  test('FIX 2: brand colour survives brightness adaptation', () {
    const resolver = TokenResolver();
    const brand = Color(0xFFABCDEF);
    final tokens = ThemeTokens.baseline().copyWith(
      color: ThemeColors.baseline().copyWith(brandBase: brand),
    );
    for (final brightness in Brightness.values) {
      final theme = resolver.resolve(
        tokens,
        brightness,
        ThemeModePreference.dark,
      );
      expect(
        theme.colorScheme.primary,
        brand,
        reason: 'brand must not be overridden by brightness adaptation',
      );
    }
  });

  test('FIX 2: text theme matches the requested brightness', () {
    const resolver = TokenResolver();
    const tokens = ThemeTokens.baseline();
    final light = resolver.resolve(tokens, Brightness.light);
    final dark = resolver.resolve(tokens, Brightness.dark);
    // Material's white typography uses a light-on-dark body colour.
    expect(
      light.textTheme.bodyMedium?.color,
      isNot(dark.textTheme.bodyMedium?.color),
    );
  });
}
