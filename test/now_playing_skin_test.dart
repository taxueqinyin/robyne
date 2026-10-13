import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/core/theme/domain/theme_layout.dart';
import 'package:robyne/core/theme/domain/theme_now_playing.dart';
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/domain/theme_tokens.dart';
import 'package:robyne/core/theme/infrastructure/theme_manifest_parser.dart';

void main() {
  group('layout.nowPlaying parsing', () {
    ThemeNowPlayingLayout parse(Object? raw) =>
        ThemeNowPlayingLayout.parse(raw);

    test('an absent block is the flagship baseline', () {
      final layout = parse(null);
      expect(layout.artworkSide, ThemeNowPlayingArtworkSide.splitLeft);
      expect(layout.showDivider, isTrue);
      expect(layout.surface, ThemeNowPlayingSurface.followSkin);
      expect(layout.background, ThemeNowPlayingBackground.blurredCover);
    });

    test('malformed input degrades to the baseline instead of throwing', () {
      // The parser's contract everywhere else is "a broken skin looks plain";
      // the player must not be the one place a typo white-screens the app.
      for (final broken in <Object?>[
        'poster',
        7,
        <Object?>[],
        <String, Object?>{'side': 'notASide'},
        <String, Object?>{'background': 42},
      ]) {
        final layout = parse(broken);
        expect(layout.artworkSide, ThemeNowPlayingArtworkSide.splitLeft);
        expect(layout.showDivider, isTrue);
      }
    });

    test('the composition knobs are read', () {
      final layout = parse(<String, Object?>{
        'side': 'splitRight',
        'showDivider': false,
        'metadataAlignment': 'end',
        'background': 'artworkGradient',
        'artworkGradientStrength': 0.8,
      });
      expect(layout.artworkSide, ThemeNowPlayingArtworkSide.splitRight);
      expect(layout.artworkOnRight, isTrue);
      expect(layout.showDivider, isFalse);
      expect(layout.metadataAlignment, ThemeNowPlayingAlignment.end);
      expect(layout.background, ThemeNowPlayingBackground.artworkGradient);
      expect(layout.artworkGradientStrength, 0.8);
    });

    test('a centred side implies centred copy', () {
      // A centred poster with left-aligned text under it reads as a bug.
      final layout = parse(<String, Object?>{'side': 'centered'});
      expect(layout.metadataAlignment, ThemeNowPlayingAlignment.center);
      expect(layout.centered, isTrue);
    });

    test('gradient strength is clamped into 0..1', () {
      expect(
        parse(<String, Object?>{
          'artworkGradientStrength': 5,
        }).artworkGradientStrength,
        1.0,
      );
      expect(
        parse(<String, Object?>{
          'artworkGradientStrength': -2,
        }).artworkGradientStrength,
        0.0,
      );
    });

    test('the light surface and its palette are read', () {
      final layout = parse(<String, Object?>{
        'surface': 'light',
        'palette': <String, Object?>{
          'backgroundBase': '#F5F1F7',
          'textPrimary': '#23212B',
          'brandBase': '#C24BD8',
        },
      });
      expect(layout.surface, ThemeNowPlayingSurface.light);
      expect(layout.palette, isNotNull);
      expect(layout.palette!.backgroundBase, const Color(0xFFF5F1F7));
      expect(layout.palette!.textPrimary, const Color(0xFF23212B));
      expect(layout.palette!.brandBase, const Color(0xFFC24BD8));
    });

    test('an unknown palette colour is ignored, not guessed at', () {
      final layout = parse(<String, Object?>{
        'palette': <String, Object?>{'backgroundBase': 'rebeccapurple'},
      });
      // Nothing but the brand was legal, so the whole palette is empty rather
      // than half-applied.
      expect(layout.palette, isNull);
    });
  });

  group('the player surface can invert against its own skin', () {
    test('followSkin returns the skin tokens untouched', () {
      final container = ProviderContainer(
        overrides: [baseThemePackageProvider.overrideWithValue(_darkSkin())],
      );
      addTearDown(container.dispose);
      final tokens = container.read(nowPlayingTokensProvider);
      expect(tokens.color.backgroundBase, const Color(0xFF0B0C0E));
    });

    test('a light player on a dark skin is legible and still that skin', () {
      // This is the QQ Music shape the user asked for: the app stays dark,
      // the player page is light.
      final container = ProviderContainer(
        overrides: [
          baseThemePackageProvider.overrideWithValue(
            _darkSkin(surface: ThemeNowPlayingSurface.light),
          ),
        ],
      );
      addTearDown(container.dispose);
      final tokens = container.read(nowPlayingTokensProvider);
      final skin = container.read(activeThemeTokensProvider);

      // The surface inverted...
      expect(
        tokens.color.backgroundBase.computeLuminance(),
        greaterThan(0.5),
        reason: 'the player surface must be light',
      );
      expect(
        tokens.color.textPrimary.computeLuminance(),
        lessThan(0.5),
        reason: 'text on a light surface must be dark enough to read',
      );
      // ...but it did not stop being this skin: brand and accent survive.
      expect(tokens.color.brandBase, skin.color.brandBase);
      expect(tokens.color.accentBase, skin.color.accentBase);
    });

    test('a declared palette wins over the derived neutrals', () {
      final container = ProviderContainer(
        overrides: [
          baseThemePackageProvider.overrideWithValue(
            _darkSkin(
              surface: ThemeNowPlayingSurface.light,
              palette: const ThemeNowPlayingPalette(
                backgroundBase: Color(0xFFF5F1F7),
                textPrimary: Color(0xFF23212B),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final tokens = container.read(nowPlayingTokensProvider);
      expect(tokens.color.backgroundBase, const Color(0xFFF5F1F7));
      expect(tokens.color.textPrimary, const Color(0xFF23212B));
    });

    test('the lyric colours follow the inverted surface', () {
      final container = ProviderContainer(
        overrides: [
          baseThemePackageProvider.overrideWithValue(
            _darkSkin(surface: ThemeNowPlayingSurface.light),
          ),
        ],
      );
      addTearDown(container.dispose);
      final tokens = container.read(nowPlayingTokensProvider);
      expect(
        tokens.components.lyric.inactiveLine.computeLuminance(),
        lessThan(0.7),
        reason: 'inactive lyric lines must stay readable on the light surface',
      );
    });
  });

  group('the flagship skin', () {
    test('declares a light player surface', () {
      // The reference the user supplied: dark app, light player page.
      final decoded =
          jsonDecode(File('assets/themes/xuan/theme.json').readAsStringSync())
              as Map<String, Object?>;
      final layout = const ThemeManifestParser().tryParse(
        decoded,
        source: ThemeSource.builtIn,
      )!;
      expect(layout.layout.nowPlaying.surface, ThemeNowPlayingSurface.light);
      expect(layout.layout.nowPlaying.showDivider, isFalse);
      // The reference keeps the artwork leading and moves the *composition*
      // inboard; it is not a mirrored two-pane split.
      expect(
        layout.layout.nowPlaying.artworkSide,
        ThemeNowPlayingArtworkSide.splitLeft,
      );
      expect(layout.layout.nowPlaying.contentInset, greaterThan(0));
      expect(
        layout.layout.nowPlaying.infoPlacement,
        ThemeNowPlayingInfoPlacement.aboveLyrics,
      );
      expect(
        layout.layout.nowPlaying.metadataAlignment,
        ThemeNowPlayingAlignment.center,
      );
      // The title/artist lockup sits above the lyric column and the lyric lines
      // themselves are centred, so left-aligned copy next to them read as a
      // misalignment rather than as a deliberate edge.
    });
  });
}

ThemePackage _darkSkin({
  ThemeNowPlayingSurface surface = ThemeNowPlayingSurface.followSkin,
  ThemeNowPlayingPalette? palette,
}) {
  return ThemePackage(
    id: 'test.dark',
    name: 'test',
    author: 'test',
    authorUrl: null,
    version: '1.0.0',
    description: '',
    preview: null,
    tags: const <String>[],
    mode: ThemeModePreference.dark,
    schemaVersion: 1,
    tokens: ThemeTokens.darkBaseline().copyWith(
      color: ThemeColors.darkBaseline().copyWith(
        backgroundBase: const Color(0xFF0B0C0E),
        brandBase: const Color(0xFFFF6B3D),
        accentBase: const Color(0xFF63D8C3),
      ),
    ),
    layout: ThemeLayout.baseline().copyWith(
      nowPlaying: ThemeNowPlayingLayout.baseline().copyWith(
        surface: surface,
        palette: palette,
      ),
    ),
    settings: const <ThemeSetting>[],
    assets: const ThemeAssets.empty(),
    source: ThemeSource.builtIn,
  );
}
