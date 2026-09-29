import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/domain/theme_home.dart';
import 'package:robyne/core/theme/domain/theme_regions.dart';

/// `layout.home` is the skin system's answer to "the design's phone board and
/// desktop board are different pages". These tests pin the composition rules
/// the authoring guide promises.
void main() {
  group('layout.home.blocks', () {
    test('a bare list is used by both form factors', () {
      final home = ThemeHomeLayout.parse(<Object?>['hero', 'recent']);

      expect(home.resolve(RobyneFormFactor.desktop), <ThemeHomeBlock>[
        ThemeHomeBlock.hero,
        ThemeHomeBlock.recent,
      ]);
      expect(home.resolve(RobyneFormFactor.mobile), <ThemeHomeBlock>[
        ThemeHomeBlock.hero,
        ThemeHomeBlock.recent,
      ]);
    });

    test('a form factor can override the shared list', () {
      final home = ThemeHomeLayout.parse(<String, Object?>{
        'blocks': <Object?>['hero', 'recommendations', 'recent'],
        'mobile': <String, Object?>{
          'blocks': <Object?>['quickActions', 'hero', 'favorites'],
        },
      });

      expect(home.resolve(RobyneFormFactor.mobile), <ThemeHomeBlock>[
        ThemeHomeBlock.quickActions,
        ThemeHomeBlock.hero,
        ThemeHomeBlock.favorites,
      ]);
      // Only `mobile` was written, so the desktop keeps the shared list.
      expect(home.resolve(RobyneFormFactor.desktop), <ThemeHomeBlock>[
        ThemeHomeBlock.hero,
        ThemeHomeBlock.recommendations,
        ThemeHomeBlock.recent,
      ]);
    });

    test('a form factor may also be given a bare list', () {
      final home = ThemeHomeLayout.parse(<String, Object?>{
        'mobile': <Object?>['hero'],
      });

      expect(home.resolve(RobyneFormFactor.mobile), <ThemeHomeBlock>[
        ThemeHomeBlock.hero,
      ]);
    });

    test('unknown block names are dropped, not fatal', () {
      final home = ThemeHomeLayout.parse(<Object?>[
        'hero',
        'not-a-block',
        'recent',
        'hero',
      ]);

      expect(home.resolve(RobyneFormFactor.desktop), <ThemeHomeBlock>[
        ThemeHomeBlock.hero,
        ThemeHomeBlock.recent,
      ]);
    });

    test('malformed input falls back to the flagship baseline', () {
      const baseline = ThemeHomeLayout.baseline();

      expect(ThemeHomeLayout.parse(null), baseline);
      expect(ThemeHomeLayout.parse('hero'), baseline);
      expect(ThemeHomeLayout.parse(<Object?>[]), baseline);
      expect(
        ThemeHomeLayout.parse(<String, Object?>{'mobile': 'hero'}),
        baseline,
      );
    });

    test('an empty override never blanks a form factor', () {
      final home = ThemeHomeLayout.parse(<String, Object?>{
        'blocks': <Object?>['hero', 'recent'],
        'mobile': <String, Object?>{'blocks': <Object?>[]},
      });

      expect(home.resolve(RobyneFormFactor.mobile), <ThemeHomeBlock>[
        ThemeHomeBlock.hero,
        ThemeHomeBlock.recent,
      ]);
    });

    test('the flagship baseline composes both boards', () {
      const baseline = ThemeHomeLayout.baseline();

      expect(
        baseline.resolve(RobyneFormFactor.desktop),
        contains(ThemeHomeBlock.recommendations),
      );
      expect(
        baseline.resolve(RobyneFormFactor.mobile),
        contains(ThemeHomeBlock.quickActions),
      );
    });

    test('round-trips through toJson', () {
      final home = ThemeHomeLayout.parse(<String, Object?>{
        'blocks': <Object?>['hero'],
        'desktop': <Object?>['hero', 'recent'],
        'mobile': <Object?>['hero', 'favorites'],
      });

      expect(ThemeHomeLayout.parse(home.toJson()), home);
    });

    test('equality distinguishes a desktop-only override', () {
      final sharedOnly = ThemeHomeLayout.parse(<Object?>['hero', 'recent']);
      final withOverride = ThemeHomeLayout.parse(<String, Object?>{
        'blocks': <Object?>['hero', 'recent'],
        'desktop': <Object?>['hero'],
      });

      // Resolving identically is not the same as declaring the same thing:
      // an override that happens to match today must survive a round trip.
      expect(withOverride, isNot(sharedOnly));
      expect(withOverride.resolve(RobyneFormFactor.desktop), <ThemeHomeBlock>[
        ThemeHomeBlock.hero,
      ]);
    });
  });
}
