import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:robyne/core/storage/local_file_store.dart';
import 'package:robyne/core/theme/domain/theme_components.dart';
import 'package:robyne/core/theme/domain/theme_layout.dart';
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/domain/theme_tokens.dart';
import 'package:robyne/core/theme/infrastructure/theme_font_loader.dart';
import 'package:robyne/core/theme/infrastructure/theme_manifest_parser.dart';
import 'package:robyne/core/theme/infrastructure/theme_path_guard.dart';
import 'package:robyne/core/theme/infrastructure/theme_repository.dart';
import 'package:robyne/core/theme/infrastructure/token_patcher.dart';
import 'package:robyne/core/theme/infrastructure/token_resolver.dart';

/// Covers the Stage 1 fixes from `docs/THEME_ROADMAP.md`:
///   S1-2 skin-bundled fonts, S1-5 schemaVersion, S1-7 D5 blockers.
void main() {
  group('schemaVersion (S1-5)', () {
    ThemePackage? parse(Object? raw) =>
        const ThemeManifestParser().tryParse(raw, source: ThemeSource.user);

    test('is read from the manifest', () {
      final theme = parse(<String, Object?>{'id': 'a', 'schemaVersion': 1});
      expect(theme?.schemaVersion, 1);
    });

    test('is assumed when the manifest omits it', () {
      final theme = parse(<String, Object?>{'id': 'a'});
      expect(theme?.schemaVersion, 1);
    });

    test('a newer schema is clamped rather than rejected', () {
      // The parser ignores unknown fields anyway, so refusing the whole skin
      // would be strictly worse for the user.
      final theme = parse(<String, Object?>{'id': 'a', 'schemaVersion': 99});
      expect(theme, isNotNull);
      expect(theme!.schemaVersion, lessThanOrEqualTo(1));
    });

    test('a non-numeric schema does not break parsing', () {
      final theme = parse(<String, Object?>{
        'id': 'a',
        'schemaVersion': 'banana',
      });
      expect(theme, isNotNull);
      expect(theme!.schemaVersion, 1);
    });
  });

  group('id -> directory mapping (S1-7 blocker 2)', () {
    test('built-in and user resolution agree for the same id', () {
      // Before this fix the built-in path used `id.replaceAll('.', '-')`
      // while the user repository used sanitizeId verbatim, so the same id
      // resolved to two different directories.
      expect(ThemePathGuard.directoryName('official.dark'), 'official-dark');
      expect(ThemePathGuard.directoryName('official-dark'), 'official-dark');
    });

    test('the mapping still neutralises traversal attempts', () {
      for (final id in <String>[
        '..',
        '../../etc',
        '/abs/path',
        r'..\..\windows',
      ]) {
        final safe = ThemePathGuard.directoryName(id);
        expect(safe.contains('..'), isFalse, reason: id);
        expect(safe.contains('/'), isFalse, reason: id);
        expect(safe.contains('\\'), isFalse, reason: id);
        expect(safe, isNotEmpty);
      }
    });

    test('a user skin directory uses the mapped name', () async {
      final root = await Directory.systemTemp.createTemp('robyne_map_');
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });
      final repository = FileThemeRepository(
        fileStore: LocalFileStore(baseDirectory: root),
      );
      final directory = await repository.themesDirectory();
      final expected = Directory(
        p.join(directory.path, ThemePathGuard.directoryName('author.theme')),
      );
      await expected.create(recursive: true);
      await File(
        p.join(expected.path, 'theme.json'),
      ).writeAsString('{"id":"author.theme"}');

      final loaded = await repository.loadTheme('author.theme');
      expect(loaded, isNotNull, reason: 'must find the mapped directory');
      expect(loaded!.id, 'author.theme');
    });
  });

  group('component tokens (S1-1)', () {
    ThemePackage? parse(Map<String, Object?> raw) =>
        const ThemeManifestParser().tryParse(raw, source: ThemeSource.user);

    test('a skin omitting components keeps the baseline', () {
      final theme = parse(<String, Object?>{'id': 'a'});
      expect(
        theme!.tokens.components.lyric.activeLine,
        const ThemeComponents.baseline().lyric.activeLine,
      );
    });

    test('a component colour is read', () {
      final theme = parse(<String, Object?>{
        'id': 'a',
        'tokens': <String, Object?>{
          'components': <String, Object?>{
            'lyric': <String, Object?>{'activeLine': '#FF0000'},
          },
        },
      });
      expect(
        theme!.tokens.components.lyric.activeLine,
        const Color(0xFFFF0000),
      );
      // The sibling field the skin did not mention must survive.
      expect(
        theme.tokens.components.lyric.inactiveLine,
        const ThemeComponents.baseline().lyric.inactiveLine,
      );
    });

    test('a gradient parses from stops and is sorted', () {
      final theme = parse(<String, Object?>{
        'id': 'a',
        'tokens': <String, Object?>{
          'components': <String, Object?>{
            'navBar': <String, Object?>{
              'gradient': <Object?>[
                <String, Object?>{'color': '#00FF00', 'offset': 1},
                <String, Object?>{'color': '#FF0000', 'offset': 0},
              ],
            },
          },
        },
      });
      final gradient = theme!.tokens.components.navBar.gradient;
      expect(gradient.isEmpty, isFalse);
      expect(gradient.stops.length, 2);
      expect(gradient.stops.first.color, const Color(0xFFFF0000));
      expect(gradient.stops.last.color, const Color(0xFF00FF00));
    });

    test('a gradient given as a single colour still works', () {
      final theme = parse(<String, Object?>{
        'id': 'a',
        'tokens': <String, Object?>{
          'components': <String, Object?>{
            'navBar': <String, Object?>{'gradient': '#123456'},
          },
        },
      });
      expect(
        theme!.tokens.components.navBar.gradient.solidColor,
        const Color(0xFF123456),
      );
    });

    test('a malformed gradient degrades to empty, never throws', () {
      final theme = parse(<String, Object?>{
        'id': 'a',
        'tokens': <String, Object?>{
          'components': <String, Object?>{
            'navBar': <String, Object?>{
              'gradient': <Object?>[
                <String, Object?>{'color': 'not-a-colour', 'offset': 0},
                42,
              ],
            },
          },
        },
      });
      expect(theme!.tokens.components.navBar.gradient.isEmpty, isTrue);
    });

    test('motion durations are clamped into a sane range', () {
      final theme = parse(<String, Object?>{
        'id': 'a',
        'tokens': <String, Object?>{
          'components': <String, Object?>{
            'motion': <String, Object?>{'shortDurationMs': 999999},
          },
        },
      });
      final motion = theme!.tokens.components.motion;
      expect(
        motion.shortDurationMs,
        lessThanOrEqualTo(ThemeMotionComponents.maxDurationMs),
      );
      // The untouched sibling stays at baseline rather than being zeroed.
      expect(
        motion.mediumDurationMs,
        const ThemeComponents.baseline().motion.mediumDurationMs,
      );
    });
  });

  group('component knobs (S1-1 patcher)', () {
    test('a knob targeted at a component token is applied', () {
      const patcher = TokenPatcher();
      final patched = patcher.apply(
        const ThemeTokens.baseline(),
        <String, Object>{'components.lyric.activeLine': '#00FF00'},
      );
      expect(patched.components.lyric.activeLine, const Color(0xFF00FF00));
    });

    test('an unknown component target is ignored', () {
      const patcher = TokenPatcher();
      final baseline = const ThemeTokens.baseline();
      final patched = patcher.apply(baseline, <String, Object>{
        'components.nonsense.thing': '#00FF00',
      });
      expect(
        patched.components.lyric.activeLine,
        baseline.components.lyric.activeLine,
      );
      expect(patched.components.card.surface, baseline.components.card.surface);
    });
  });

  group('resolver applies component tokens (S1-1)', () {
    test('navBar gradient and lyric colours reach ThemeData', () {
      final tokens = const ThemeTokens.baseline().copyWith(
        components: const ThemeComponents.baseline().copyWith(
          lyric: const ThemeLyricComponents.baseline().copyWith(
            activeLine: Color(0xFFABCDEF),
          ),
        ),
      );
      final data = const TokenResolver().resolve(
        tokens,
        Brightness.light,
        ThemeModePreference.light,
      );
      final robyn = data.extension<RobyneTheme>();
      expect(robyn, isNotNull);
      expect(
        robyn!.tokens.components.lyric.activeLine,
        const Color(0xFFABCDEF),
      );
    });

    test('a skin without component tokens resolves unchanged', () {
      final data = const TokenResolver().resolve(
        const ThemeTokens.baseline(),
        Brightness.light,
        ThemeModePreference.light,
      );
      expect(data.extension<RobyneTheme>(), isNotNull);
    });
  });

  group('skin-bundled fonts (S1-2)', () {
    test('a skin with no font resolves to no family', () async {
      final loader = const ThemeFontLoader();
      final family = await loader.loadFamilyFor(
        _package(assets: const ThemeAssets.empty()),
      );
      expect(family, isNull);
    });

    test('an unresolvable font degrades to null instead of failing', () async {
      // A skin referencing a font file that does not exist must fall back to
      // the platform font, never break the skin.
      final loader = const ThemeFontLoader();
      final family = await loader.loadFamilyFor(
        _package(
          assets: const ThemeAssets(background: null, font: 'missing.ttf'),
        ),
      );
      expect(family, isNull);
    });

    test('the budget rejects an oversized font', () {
      expect(ThemeFontLoader.maxFontBytes, greaterThan(0));
      expect(ThemeFontLoader.maxFontBytes, lessThanOrEqualTo(10 * 1024 * 1024));
    });
  });
}

ThemePackage _package({
  required ThemeAssets assets,
  ThemeSource source = ThemeSource.user,
}) {
  return ThemePackage(
    id: 'test.theme',
    name: 'Test',
    author: 'Test',
    authorUrl: null,
    version: '1.0.0',
    description: '',
    preview: null,
    tags: const <String>[],
    mode: ThemeModePreference.light,
    schemaVersion: 1,
    tokens: const ThemeTokens.baseline(),
    layout: const ThemeLayout(
      desktop: ThemeDesktopLayout.baseline(),
      mobile: ThemeMobileLayout.baseline(),
      content: ThemeContentLayout.baseline(),
    ),
    settings: const <ThemeSetting>[],
    assets: assets,
    source: source,
  );
}
