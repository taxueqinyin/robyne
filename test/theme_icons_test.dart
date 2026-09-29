import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/domain/theme_icons.dart';
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/infrastructure/theme_manifest_parser.dart';
import 'package:robyne/core/theme/infrastructure/theme_asset_resolver.dart';
import 'package:robyne/core/theme/infrastructure/theme_font_loader.dart';

/// Icons are the last piece of chrome a skin could not touch: a rail row or a
/// transport button was an `Icons.*` literal in the shell, so a skin could
/// recolour a glyph but never redraw it.
void main() {
  group('theme icons', () {
    test('no declaration keeps every built-in glyph', () {
      final icons = ThemeIcons.parse(null);

      expect(icons.isEmpty, isTrue);
      for (final slot in ThemeIconKey.values) {
        expect(icons[slot], isNull);
      }
    });

    test('a bare code point is the short form', () {
      final icons = ThemeIcons.parse(<String, Object?>{'play': 0xE037});

      expect(icons[ThemeIconKey.play]?.codePoint, 0xE037);
      expect(icons[ThemeIconKey.play]?.isEmpty, isFalse);
    });

    test('hex strings are accepted, since cheat sheets publish them', () {
      // Requiring decimal would force every author through a conversion for
      // no benefit.
      // 0xE037 == 57399; the decimal form must agree with the hex forms.
      for (final raw in <Object?>['0xE037', 'E037', 'e037', 57399]) {
        final icons = ThemeIcons.parse(<String, Object?>{'play': raw});
        expect(icons[ThemeIconKey.play]?.codePoint, 0xE037, reason: '$raw');
      }
    });

    test('the object form carries size, colour and font', () {
      final icons = ThemeIcons.parse(<String, Object?>{
        'discover': <String, Object?>{
          'glyph': '0xE001',
          'size': 26,
          'color': '#FF6B3D',
          'fontFamily': 'MyIcons',
        },
      });

      final icon = icons[ThemeIconKey.discover]!;
      expect(icon.glyph, 0xE001);
      expect(icon.size, 26);
      expect(icon.color, const Color(0xFFFF6B3D));
      expect(icon.fontFamily, 'MyIcons');
    });

    test('unknown slots and empty declarations are dropped', () {
      final icons = ThemeIcons.parse(<String, Object?>{
        'invented': 1,
        'play': <String, Object?>{},
        'pause': 'not-a-number',
      });

      expect(icons.isEmpty, isTrue);
      expect(icons[ThemeIconKey.play], isNull);
      expect(icons[ThemeIconKey.pause], isNull);
    });

    test('a malformed icons block is ignored, not fatal', () {
      for (final bad in <Object?>[null, 'nope', 7, <Object?>[]]) {
        expect(ThemeIcons.parse(bad).isEmpty, isTrue);
      }
    });

    test('round-trips through toJson', () {
      final icons = ThemeIcons.parse(<String, Object?>{
        'play': 0xE037,
        'like': <String, Object?>{'image': 'icons/heart.png', 'size': 20},
      });

      expect(ThemeIcons.parse(icons.toJson()), icons);
    });

    test('every slot has a json name', () {
      for (final slot in ThemeIconKey.values) {
        expect(ThemeIconKey.fromJsonName(slot.jsonName), slot);
      }
      expect(ThemeIconKey.fromJsonName('nope'), isNull);
    });

    group('active variants', () {
      test('without an active twin the active state reuses the glyph', () {
        // Rails toggle outline/filled; a skin whose font has no filled
        // variant must not silently snap back to Material.
        final icon = ThemeIcons.parse(<String, Object?>{
          'play': 0xE037,
        })[ThemeIconKey.play]!;

        expect(icon.codePointFor(active: false), 0xE037);
        expect(icon.codePointFor(active: true), 0xE037);
      });

      test('an active twin is used only when active', () {
        final icon = ThemeIcons.parse(<String, Object?>{
          'like': <String, Object?>{
            'codePoint': 0xE87E,
            'activeCodePoint': 0xE87D,
          },
        })[ThemeIconKey.like]!;

        expect(icon.codePointFor(active: false), 0xE87E);
        expect(icon.codePointFor(active: true), 0xE87D);
      });

      test('declaring only an active variant still renders', () {
        // The author clearly meant this slot to use their artwork, so falling
        // back to Material for the normal state would be wrong.
        final icons = ThemeIcons.parse(<String, Object?>{
          'play': <String, Object?>{'activeGlyph': '0xE002'},
        });
        final icon = icons[ThemeIconKey.play]!;

        expect(icon.isRenderable(active: false), isTrue);
        expect(icon.codePointFor(active: false), 0xE002);
        expect(icon.codePointFor(active: true), 0xE002);
      });

      test('an active colour wins over the normal one', () {
        final icon = ThemeIcons.parse(<String, Object?>{
          'like': <String, Object?>{
            'codePoint': 0xE87E,
            'color': '#AABBCC',
            'activeColor': '#FF6B3D',
          },
        })[ThemeIconKey.like]!;

        expect(icon.colorFor(active: false), const Color(0xFFAABBCC));
        expect(icon.colorFor(active: true), const Color(0xFFFF6B3D));
      });

      test('an active image is used only when active', () {
        final icon = ThemeIcons.parse(<String, Object?>{
          'queue': <String, Object?>{
            'image': 'icons/queue.png',
            'activeImage': 'icons/queue-on.png',
          },
        })[ThemeIconKey.queue]!;

        expect(icon.imageFor(active: false), 'icons/queue.png');
        expect(icon.imageFor(active: true), 'icons/queue-on.png');
      });

      test('active fields round-trip through toJson', () {
        final icons = ThemeIcons.parse(<String, Object?>{
          'like': <String, Object?>{
            'codePoint': 0xE87E,
            'activeCodePoint': 0xE87D,
            'activeColor': '#FF6B3D',
          },
        });

        expect(ThemeIcons.parse(icons.toJson()), icons);
      });
    });
  });

  group('the manifest reads an icon font', () {
    ThemePackage parse(Map<String, Object?> raw) {
      return const ThemeManifestParser().tryParse(<String, Object?>{
        'id': 'demo',
        ...raw,
      }, source: ThemeSource.builtIn)!;
    }

    test('ships a font and gets a namespaced family', () {
      final package = parse(<String, Object?>{
        'assets': <String, Object?>{
          'icons': <String, Object?>{'font': 'icons/set.ttf'},
        },
      });

      // Namespaced so two skins cannot collide over one family, and so a
      // skin cannot shadow the app's own glyphs.
      expect(package.assets.iconFont, 'icons/set.ttf');
      expect(package.iconsFontFamily, startsWith('robyne_builtin_demo_icons'));
    });

    test('a declared family name is still namespaced', () {
      final package = parse(<String, Object?>{
        'assets': <String, Object?>{
          'icons': <String, Object?>{
            'font': 'icons/set.ttf',
            'fontFamily': 'MaterialIcons',
          },
        },
      });

      final family = package.iconsFontFamily!;
      expect(family, startsWith('robyne_builtin_demo_icons_'));
      expect(family, contains('MaterialIcons'));
      // The dangerous part: it must not *be* the family it named.
      expect(family, isNot('MaterialIcons'));
    });

    test('no icon font means no icon family', () {
      final package = parse(<String, Object?>{});

      expect(package.assets.iconFont, isNull);
      expect(package.iconsFontFamily, isNull);
    });

    test('icons travel through copyWith', () {
      final package = parse(<String, Object?>{
        'icons': <String, Object?>{'play': 0xE037},
      });

      expect(package.icons[ThemeIconKey.play]?.codePoint, 0xE037);
      expect(package.copyWith().icons[ThemeIconKey.play]?.codePoint, 0xE037);
    });

    test('the loader and the renderer agree on the family name', () {
      // They used to compute it separately, and disagreed: the manifest was
      // pre-namespaced and the loader namespaced it again, so a shipped icon
      // font registered under a family no widget ever drew with. One source
      // of truth is the fix; this is the guard.
      final package = parse(<String, Object?>{
        'assets': <String, Object?>{
          'icons': <String, Object?>{
            'font': 'icons/set.ttf',
            'fontFamily': 'MySet',
          },
        },
      });

      expect(ThemeFontLoader.iconFamilyFor(package), package.iconsFontFamily);
      // And the namespace appears exactly once.
      final family = package.iconsFontFamily!;
      expect('robyne_'.allMatches(family).length, 1);
      expect('_icons'.allMatches(family).length, 1);
    });

    test('an icon image cannot address anything outside the skin', () {
      // Icon artwork is resolved through ThemeAssetResolver, which is the
      // boundary every other skin asset crosses. A traversal reference must
      // come back null rather than a path pointing at the filesystem.
      const resolver = ThemeAssetResolver();
      final package = parse(<String, Object?>{
        'assets': <String, Object?>{
          'icons': <String, Object?>{'font': 'icons/set.ttf'},
        },
      });

      return Future<void>(() async {
        for (final hostile in <String>[
          '../../../../etc/passwd',
          '..\\..\\windows\\system32\\config\\sam',
          '/etc/shadow',
          'C:\\Windows\\win.ini',
        ]) {
          final path = await resolver.resolveFilePath(package, hostile);
          expect(
            path,
            anyOf(isNull, startsWith('assets/themes/xuan/')),
            reason: '$hostile must not resolve outside the skin',
          );
        }
      });
    });
  });
}
