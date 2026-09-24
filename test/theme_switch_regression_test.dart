import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/infrastructure/theme_manifest_parser.dart';
import 'package:robyne/core/theme/infrastructure/theme_repository.dart';
import 'package:robyne/core/theme/infrastructure/token_resolver.dart';

/// Repository backed by the real bundled manifests.
class _BundleRepository implements ThemeRepository {
  @override
  Future<List<ThemePackage>> listThemes() async {
    final out = <ThemePackage>[];
    for (final id in const <String>[
      'official.light',
      'official.dark',
      'official.midnight',
    ]) {
      final t = await loadTheme(id);
      if (t != null) out.add(t);
    }
    return out;
  }

  @override
  Future<ThemePackage?> loadTheme(String id) async {
    final folder = id.replaceAll('.', '-');
    final f = File('assets/themes/$folder/theme.json');
    if (!f.existsSync()) return null;
    return const ThemeManifestParser().tryParse(
      jsonDecode(f.readAsStringSync()) as Object?,
      source: ThemeSource.builtIn,
      fallbackId: id,
    );
  }

  @override
  Future<Directory> userThemesDirectory() async =>
      Directory.systemTemp.createTemp('bundle_repo');

  @override
  Future<bool> deleteTheme(String id) async => false;
}

void main() {
  test('REGRESSION: every official skin is visually distinct', () async {
    final themes = await _BundleRepository().listThemes();
    expect(themes.length, 3, reason: 'all three bundled skins must load');

    const resolver = TokenResolver();
    final backgrounds = <Color>{};
    final brands = <Color>{};
    for (final theme in themes) {
      final resolved = resolver.resolve(
        theme.tokens,
        TokenResolver.naturalBrightness(theme.mode),
        theme.mode,
      );
      backgrounds.add(resolved.scaffoldBackgroundColor);
      brands.add(resolved.colorScheme.primary);
    }
    // The bug was that all skins degraded to one identical baseline palette,
    // so switching appeared to do nothing.
    expect(
      backgrounds.length,
      themes.length,
      reason: 'each skin must render a distinct background',
    );
    expect(
      brands.length,
      themes.length,
      reason: 'each skin must render a distinct brand colour',
    );
  });

  test('REGRESSION: brightness changes the resolved background', () async {
    final themes = await _BundleRepository().listThemes();
    const resolver = TokenResolver();
    for (final theme in themes) {
      final light = resolver.resolve(
        theme.tokens,
        Brightness.light,
        theme.mode,
      );
      final dark = resolver.resolve(theme.tokens, Brightness.dark, theme.mode);
      expect(
        light.scaffoldBackgroundColor,
        isNot(dark.scaffoldBackgroundColor),
        reason: '${theme.id}: light and dark must not render identically',
      );
    }
  });

  test('REGRESSION: dark skins are actually dark', () async {
    final themes = await _BundleRepository().listThemes();
    for (final theme in themes) {
      if (theme.mode != ThemeModePreference.dark) continue;
      final resolved = const TokenResolver().resolve(
        theme.tokens,
        Brightness.dark,
        theme.mode,
      );
      expect(
        resolved.scaffoldBackgroundColor.computeLuminance(),
        lessThan(0.3),
        reason: '${theme.id} should render a dark background',
      );
    }
  });
}
