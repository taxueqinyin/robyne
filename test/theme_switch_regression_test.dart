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
    for (final id in const <String>['xuan']) {
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
  test('REGRESSION: the flagship skin resolves its own palette', () async {
    final themes = await _BundleRepository().listThemes();
    expect(themes, hasLength(1), reason: '《玄》is the single built-in skin');

    const resolver = TokenResolver();
    final theme = themes.single;
    final resolved = resolver.resolve(
      theme.tokens,
      TokenResolver.naturalBrightness(theme.mode),
      theme.mode,
    );
    // The bug was that a skin degraded to the baseline palette, so the
    // flagship looked like a default Material app instead of《玄》.
    expect(resolved.scaffoldBackgroundColor, const Color(0xFF0B0C0E));
    expect(resolved.colorScheme.primary, const Color(0xFFFF6B3D));
    expect(
      theme.tokens.components.navBar.selectedIndicator,
      const Color(0xFFFF6B3D),
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
      // A single-mode skin keeps its authored palette in its own brightness
      // and derives the other one; a dark skin must not silently render its
      // dark background in light mode.
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
