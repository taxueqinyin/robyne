import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/domain/theme_layout.dart';
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/domain/theme_regions.dart';
import 'package:robyne/core/theme/infrastructure/theme_manifest_parser.dart';

/// `layout` parsing, now that the arrangement is the only live declaration.
///
/// The pre-arrangement knobs (`sidebar.*`, `playerBarHeight`,
/// `playerBarPosition`, `mobile.navigation`) were removed along with their
/// fields: they were parsed but read by no widget, so a skin could declare a
/// 72dp player bar and a 0.09 arrangement ratio and be silently ignored on
/// one of them. These cases cover what actually renders.
void main() {
  const parser = ThemeManifestParser();

  group('ThemeLayout parsing', () {
    test('defaults to the official baseline when layout is absent', () {
      final theme = parser.tryParse(
        jsonDecode('{"id": "plain"}') as Object?,
        source: ThemeSource.user,
      );
      expect(theme!.layout.desktop.arrangement, RobyneArrangement.desktop);
      expect(theme.layout.mobile.arrangement, RobyneArrangement.mobile);
      expect(theme.layout.content.listStyle, ThemeListStyle.list);
    });

    test('parses desktop and mobile independently', () {
      final theme = parser.tryParse(
        jsonDecode('''
        {
          "id": "split",
          "layout": {
            "desktop": {
              "arrangement": [
                { "region": "navBar", "slot": "right", "size": 0.18 },
                { "region": "content", "slot": "center" }
              ]
            },
            "mobile": {
              "arrangement": [
                { "region": "content", "slot": "center" },
                { "region": "navBar", "slot": "bottom", "size": 0.09 }
              ]
            },
            "content": { "listStyle": "card", "density": "comfortable" }
          }
        }
        ''')
            as Object?,
        source: ThemeSource.user,
      );
      expect(theme, isNotNull);

      // Each form factor keeps its own arrangement; neither leaks into the
      // other, which is the whole point of D6.
      expect(
        theme!.layout.desktop.arrangement.placements.first.slot,
        RobyneSlot.right,
      );
      expect(
        theme.layout.mobile.arrangement.placements.last.slot,
        RobyneSlot.bottom,
      );
      expect(theme.layout.content.listStyle, ThemeListStyle.card);
      expect(theme.layout.content.density, ThemeDensity.comfortable);
    });

    test('one form factor can be omitted and inherits the baseline', () {
      // The inheritance promise from `THEME_AUTHORING.md`: write only the
      // shape you care about, the other keeps the official default.
      final theme = parser.tryParse(
        jsonDecode('''
        { "id": "partial", "layout": { "mobile": { "arrangement": [
            { "region": "content", "slot": "center" },
            { "region": "navBar", "slot": "top", "size": 0.08 }
          ] } } }
        ''')
            as Object?,
        source: ThemeSource.user,
      );

      // Assert on the navBar placement, not on position: the parser stores
      // placements in canonical region order, so "last" is not what was
      // written last.
      expect(
        theme!.layout.mobile.arrangement.placements
            .firstWhere((placement) => placement.region == RobyneRegion.navBar)
            .slot,
        RobyneSlot.top,
      );
      // Desktop untouched.
      expect(theme.layout.desktop.arrangement, RobyneArrangement.desktop);
    });

    test('an illegal slot is repaired into the official layout', () {
      // Mobile has no `left` slot: 400dp cannot hold a side rail.
      final theme = parser.tryParse(
        jsonDecode('''
        { "id": "junk", "layout": { "mobile": { "arrangement": [
            { "region": "navBar", "slot": "left", "size": 0.18 },
            { "region": "content", "slot": "center" }
          ] } } }
        ''')
            as Object?,
        source: ThemeSource.user,
      );

      expect(theme!.layout.mobile.arrangement, RobyneArrangement.mobile);
    });

    test('a dropped content region falls back to the official layout', () {
      // `content` can never be sacrificed (D7); an arrangement without it is
      // not a layout, so it is repaired rather than honoured.
      final theme = parser.tryParse(
        jsonDecode('''
        { "id": "nocol", "layout": { "desktop": { "arrangement": [
            { "region": "navBar", "slot": "left", "size": 0.18 }
          ] } } }
        ''')
            as Object?,
        source: ThemeSource.user,
      );

      expect(theme!.layout.desktop.arrangement, RobyneArrangement.desktop);
    });
  });

  group('Built-in skins', () {
    test('every bundled skin declares a layout', () {
      // The flagship ships as the single built-in skin 《玄》; it is the
      // reference package authors copy and edit, so it must stay complete.
      const id = 'xuan';
      final raw = bundledThemeJson(id);
      expect(raw, isNotNull, reason: '$id is missing theme.json');
      final theme = parser.tryParse(
        jsonDecode(raw!) as Object?,
        source: ThemeSource.builtIn,
        fallbackId: id,
      );
      expect(theme, isNotNull, reason: '$id failed to parse');
      expect(theme!.layout, isA<ThemeLayout>(), reason: '$id has no layout');
      expect(theme.layout.home.blocks, isNotEmpty);
    });
  });
}

/// Reads a bundled skin manifest from the file system during tests.
String? bundledThemeJson(String folder) {
  final file = File('assets/themes/$folder/theme.json');
  return file.existsSync() ? file.readAsStringSync() : null;
}
