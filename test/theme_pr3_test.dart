import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/domain/theme_layout.dart';
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/infrastructure/theme_manifest_parser.dart';

void main() {
  const parser = ThemeManifestParser();

  group('ThemeLayout parsing', () {
    test('defaults to the official baseline when layout is absent', () {
      final theme = parser.tryParse(
        jsonDecode('{"id": "plain"}') as Object?,
        source: ThemeSource.user,
      );
      expect(theme!.layout.desktop.sidebar.position, ThemeSidebarPosition.left);
      expect(theme.layout.mobile.navigation, ThemeMobileNavigation.bottomTabs);
      expect(theme.layout.content.listStyle, ThemeListStyle.list);
    });

    test('parses desktop and mobile independently', () {
      final theme = parser.tryParse(
        jsonDecode('''
        {
          "id": "split",
          "layout": {
            "desktop": {
              "sidebar": { "position": "right", "width": 140, "labelMode": "selected" },
              "playerBarHeight": 84
            },
            "mobile": { "navigation": "bottomTabs", "playerBarCompact": false },
            "content": { "listStyle": "card", "density": "comfortable" }
          }
        }
        ''')
            as Object?,
        source: ThemeSource.user,
      );
      expect(theme, isNotNull);
      expect(
        theme!.layout.desktop.sidebar.position,
        ThemeSidebarPosition.right,
      );
      expect(theme.layout.desktop.sidebar.width, 140);
      expect(
        theme.layout.desktop.sidebar.labelMode,
        ThemeRailLabelMode.selected,
      );
      expect(theme.layout.desktop.playerBarHeight, 84);
      expect(theme.layout.mobile.playerBarCompact, false);
      expect(theme.layout.content.listStyle, ThemeListStyle.card);
      expect(theme.layout.content.density, ThemeDensity.comfortable);
    });

    test('one form factor can be omitted and inherits the baseline', () {
      final theme = parser.tryParse(
        jsonDecode('''
        { "id": "partial", "layout": { "mobile": { "playerBarHeight": 56 } } }
        ''')
            as Object?,
        source: ThemeSource.user,
      );
      expect(theme!.layout.mobile.playerBarHeight, 56);
      // Desktop untouched.
      expect(theme.layout.desktop.playerBarHeight, 72);
      expect(theme.layout.desktop.sidebar.position, ThemeSidebarPosition.left);
    });

    test('widens the rail automatically when labels are shown', () {
      final withLabels = ThemeSidebarLayout.baseline().copyWith(
        width: 80,
        labelMode: ThemeRailLabelMode.all,
      );
      final noLabels = ThemeSidebarLayout.baseline().copyWith(
        width: 80,
        labelMode: ThemeRailLabelMode.none,
      );
      expect(withLabels.effectiveWidth, greaterThan(noLabels.effectiveWidth));
      expect(noLabels.effectiveWidth, 80);
    });

    test('ignores unknown layout values', () {
      final theme = parser.tryParse(
        jsonDecode('''
        {
          "id": "junk",
          "layout": {
            "desktop": { "sidebar": { "position": "sideways", "width": "wide" } }
          }
        }
        ''')
            as Object?,
        source: ThemeSource.user,
      );
      expect(theme!.layout.desktop.sidebar.position, ThemeSidebarPosition.left);
      expect(theme.layout.desktop.sidebar.width, 80);
    });
  });

  group('Built-in skins', () {
    test('every bundled skin declares a layout', () {
      // Guards the sample skins stay complete for authors to copy.
      for (final id in const <String>[
        'official.light',
        'official.dark',
        'official.midnight',
      ]) {
        final folder = id.replaceAll('.', '-');
        final raw = bundledThemeJson(folder);
        expect(raw, isNotNull, reason: '$id is missing theme.json');
        final theme = parser.tryParse(
          jsonDecode(raw!) as Object?,
          source: ThemeSource.builtIn,
          fallbackId: id,
        );
        expect(theme, isNotNull, reason: '$id failed to parse');
        expect(theme!.layout, isA<ThemeLayout>(), reason: '$id has no layout');
      }
    });
  });
}

/// Reads a bundled skin manifest from the file system during tests.
String? bundledThemeJson(String folder) {
  final file = File('assets/themes/$folder/theme.json');
  return file.existsSync() ? file.readAsStringSync() : null;
}
