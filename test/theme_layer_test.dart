import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/domain/theme_tokens.dart';
import 'package:robyne/core/theme/infrastructure/theme_manifest_parser.dart';
import 'package:robyne/core/theme/infrastructure/token_resolver.dart';

void main() {
  const parser = ThemeManifestParser();

  group('ThemeManifestParser', () {
    test('parses a full manifest', () {
      final raw =
          jsonDecode('''
      {
        "id": "test.full",
        "name": "Test",
        "author": "Someone",
        "version": "1.2.3",
        "mode": "dark",
        "tags": ["dark", "minimalist"],
        "tokens": {
          "color": { "brand": { "base": "#FF0000" } },
          "radius": { "md": 20 },
          "effects": { "blur": 25 }
        }
      }
      ''')
              as Object?;

      final theme = parser.tryParse(raw, source: ThemeSource.user);
      expect(theme, isNotNull);
      expect(theme!.id, 'test.full');
      expect(theme.mode, ThemeModePreference.dark);
      expect(theme.tokens.color.brandBase, const Color(0xFFFF0000));
      expect(theme.tokens.radius.md, 20);
      expect(theme.tokens.effects.blur, 25);
    });

    test('fills missing tokens from the baseline instead of failing', () {
      final theme = parser.tryParse(
        jsonDecode('{"id": "test.min"}') as Object?,
        source: ThemeSource.user,
      );
      expect(theme, isNotNull);
      expect(theme!.tokens.color.brandBase, ThemeColors.baseline().brandBase);
      expect(theme.name, 'test.min');
    });

    test('rejects payloads that cannot be identified', () {
      expect(parser.tryParse(null, source: ThemeSource.user), isNull);
      expect(parser.tryParse('not a map', source: ThemeSource.user), isNull);
      expect(parser.tryParse({}, source: ThemeSource.user), isNull);
    });

    test('falls back to the provided id when the manifest omits one', () {
      final theme = parser.tryParse(
        jsonDecode('{"name": "No Id"}') as Object?,
        source: ThemeSource.user,
        fallbackId: 'folder.name',
      );
      expect(theme?.id, 'folder.name');
    });

    test('ignores unknown and malformed fields', () {
      final theme = parser.tryParse(
        jsonDecode('''
        {
          "id": "test.junk",
          "unknownField": 123,
          "tokens": {
            "radius": { "md": "not a number" },
            "effects": { "blur": 999 }
          }
        }
        ''')
            as Object?,
        source: ThemeSource.user,
      );
      expect(theme, isNotNull);
      expect(theme!.tokens.radius.md, ThemeRadii.baseline().md);
      // Out-of-range values are clamped, not rejected.
      expect(theme.tokens.effects.blur, 40);
    });

    test('accepts shorthand hex colours', () {
      final theme = parser.tryParse(
        jsonDecode(
              '{"id": "c", "tokens": {"color": {"brand": {"base": "#F00"}}}}',
            )
            as Object?,
        source: ThemeSource.user,
      );
      expect(theme!.tokens.color.brandBase, const Color(0xFFFF0000));
    });

    test('parses user-adjustable settings', () {
      final theme = parser.tryParse(
        jsonDecode('''
        {
          "id": "test.settings",
          "settings": [
            { "key": "blurAmount", "type": "range", "label": "模糊",
              "min": 0, "max": 40, "default": 12, "target": "effects.blur" },
            { "key": "bad" }
          ]
        }
        ''')
            as Object?,
        source: ThemeSource.user,
      );
      // The malformed entry is dropped, the valid one survives.
      expect(theme!.settings, hasLength(1));
      expect(theme.settings.first.key, 'blurAmount');
      expect(theme.settings.first.type, ThemeSettingType.range);
      expect(theme.settings.first.target, 'effects.blur');
    });
  });

  group('TokenResolver', () {
    test('baseline tokens resolve without throwing', () {
      final resolver = const TokenResolver();
      final light = resolver.resolve(
        const ThemeTokens.baseline(),
        Brightness.light,
      );
      final dark = resolver.resolve(
        const ThemeTokens.baseline(),
        Brightness.dark,
      );
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.extension<RobyneTheme>(), isNotNull);
    });

    test('brand colour reaches the resolved color scheme', () {
      final tokens = ThemeTokens.baseline().copyWith(
        color: ThemeColors.baseline().copyWith(
          brandBase: const Color(0xFFABCDEF),
        ),
      );
      final theme = const TokenResolver().resolve(tokens, Brightness.light);
      expect(theme.colorScheme.primary, const Color(0xFFABCDEF));
    });
  });
}
