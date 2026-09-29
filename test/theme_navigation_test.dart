import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:io';

import 'package:robyne/core/theme/domain/theme_navigation.dart';
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/domain/theme_regions.dart';
import 'package:robyne/core/theme/infrastructure/theme_manifest_parser.dart';

/// `navigation.hidden` lets a skin drop a navigation entry it duplicates.
///
/// The flagship needs this because its rail listed `playlists` *and* a
/// playlist group beneath it: two controls, one destination.
void main() {
  group('navigation.hidden', () {
    test('nothing is hidden by default', () {
      const navigation = ThemeNavigation.empty();

      expect(navigation.isEmpty, isTrue);
      for (final entry in ThemeNavEntry.values) {
        expect(navigation.isHidden(entry, RobyneFormFactor.desktop), isFalse);
        expect(navigation.isHidden(entry, RobyneFormFactor.mobile), isFalse);
      }
    });

    test('a hidden entry is hidden only where declared', () {
      final navigation = ThemeNavigation.parse(<String, Object?>{
        'desktop': <Object?>['playlists'],
      });

      expect(
        navigation.isHidden(ThemeNavEntry.playlists, RobyneFormFactor.desktop),
        isTrue,
      );
      // The phone's four-slot tab bar keeps it: hiding it there too would need
      // a separate declaration.
      expect(
        navigation.isHidden(ThemeNavEntry.playlists, RobyneFormFactor.mobile),
        isFalse,
      );
    });

    test('settings can never be hidden', () {
      final navigation = ThemeNavigation.parse(<String, Object?>{
        'desktop': <Object?>['settings'],
        'mobile': <Object?>['settings'],
      });

      // Stranding the user out of the appearance panel is not a skin
      // capability.
      expect(
        navigation.isHidden(ThemeNavEntry.settings, RobyneFormFactor.desktop),
        isFalse,
      );
      expect(
        navigation.isHidden(ThemeNavEntry.settings, RobyneFormFactor.mobile),
        isFalse,
      );
    });

    test('unknown names are ignored', () {
      final navigation = ThemeNavigation.parse(<String, Object?>{
        'desktop': <Object?>['playlists', 'invented'],
      });

      expect(
        navigation.isHidden(ThemeNavEntry.playlists, RobyneFormFactor.desktop),
        isTrue,
      );
    });

    test('malformed input yields no hiding', () {
      expect(ThemeNavigation.parse(null).isEmpty, isTrue);
      expect(ThemeNavigation.parse('nope').isEmpty, isTrue);
      expect(
        ThemeNavigation.parse(<String, Object?>{
          'desktop': 'playlists',
        }).isEmpty,
        isTrue,
      );
    });

    test('round-trips through toJson', () {
      final navigation = ThemeNavigation.parse(<String, Object?>{
        'desktop': <Object?>['playlists'],
        'mobile': <Object?>['downloads'],
      });

      expect(ThemeNavigation.parse(navigation.toJson()), navigation);
    });

    test('every destination has a json name', () {
      for (final entry in ThemeNavEntry.values) {
        expect(ThemeNavEntry.fromJsonName(entry.jsonName), entry);
      }
      expect(ThemeNavEntry.fromJsonName('nope'), isNull);
    });
  });

  group('navigation order', () {
    List<ThemeNavEntry> sample() => <ThemeNavEntry>[
      ThemeNavEntry.search,
      ThemeNavEntry.discover,
      ThemeNavEntry.library,
    ];

    test('no order declared leaves the built-in sequence untouched', () {
      const navigation = ThemeNavigation.empty();

      expect(
        navigation.applyOrder(
          sample(),
          RobyneFormFactor.desktop,
          (entry) => entry,
        ),
        sample(),
      );
    });

    test('mentioned entries lead, the rest keep their order behind them', () {
      // A prefix, not a permutation: the skin says what it cares about and
      // does not have to restate a list it mostly agrees with.
      final navigation = ThemeNavigation.parse(<String, Object?>{
        'desktopOrder': <Object?>['library'],
      });

      final ordered = navigation
          .applyOrder(sample(), RobyneFormFactor.desktop, (entry) => entry)
          .map((entry) => entry.jsonName)
          .toList();
      expect(ordered, <String>['library', 'search', 'discover']);
    });

    test('order is per form factor', () {
      final navigation = ThemeNavigation.parse(<String, Object?>{
        'desktopOrder': <Object?>['library'],
      });

      expect(
        navigation
            .applyOrder(sample(), RobyneFormFactor.desktop, (entry) => entry)
            .first,
        ThemeNavEntry.library,
      );
      // The phone is undeclared, so it keeps the built-in sequence.
      expect(
        navigation
            .applyOrder(sample(), RobyneFormFactor.mobile, (entry) => entry)
            .first,
        ThemeNavEntry.search,
      );
    });

    test('unknown names and duplicates drop out', () {
      final navigation = ThemeNavigation.parse(<String, Object?>{
        'desktopOrder': <Object?>['invented', 'library', 'library'],
      });

      final ordered = navigation
          .applyOrder(sample(), RobyneFormFactor.desktop, (entry) => entry)
          .map((entry) => entry.jsonName)
          .toList();
      expect(ordered, <String>['library', 'search', 'discover']);
    });

    test('hiding still wins over ordering', () {
      // `applyOrder` only ever sees the surface's already-filtered selection,
      // so an entry the skin hid cannot be ordered back into view.
      final navigation = ThemeNavigation.parse(<String, Object?>{
        'desktop': <Object?>['discover'],
        'desktopOrder': <Object?>['discover', 'library'],
      });

      final shown = <ThemeNavEntry>[
        for (final entry in sample())
          if (!navigation.isHidden(entry, RobyneFormFactor.desktop)) entry,
      ];
      final ordered = navigation
          .applyOrder(shown, RobyneFormFactor.desktop, (entry) => entry)
          .map((entry) => entry.jsonName)
          .toList();
      expect(ordered, <String>['library', 'search']);
      expect(ordered.contains('discover'), isFalse);
    });

    test('an entry absent from the surface cannot be ordered in', () {
      final navigation = ThemeNavigation.parse(<String, Object?>{
        'desktopOrder': <Object?>['plugins'],
      });

      final ordered = navigation
          .applyOrder(sample(), RobyneFormFactor.desktop, (entry) => entry)
          .map((entry) => entry.jsonName)
          .toList();
      // `plugins` is not in this surface's selection, so nothing appears.
      expect(ordered, <String>['search', 'discover', 'library']);
    });

    test('round-trips through toJson', () {
      final navigation = ThemeNavigation.parse(<String, Object?>{
        'desktopOrder': <Object?>['library', 'discover'],
        'mobileOrder': <Object?>['discover'],
      });

      expect(ThemeNavigation.parse(navigation.toJson()), navigation);
    });

    test('malformed order yields no reordering', () {
      for (final bad in <Object?>[null, 'library', 7]) {
        final navigation = ThemeNavigation.parse(<String, Object?>{
          'desktopOrder': bad,
        });
        expect(navigation.desktopOrder, isEmpty);
      }
    });
  });

  group('flagship《玄》', () {
    ThemePackage xuan() {
      final decoded =
          jsonDecode(File('assets/themes/xuan/theme.json').readAsStringSync())
              as Map<String, Object?>;
      return const ThemeManifestParser().tryParse(
        decoded,
        source: ThemeSource.builtIn,
      )!;
    }

    test('declares the rail order the design sheets draw', () {
      final navigation = xuan().navigation;

      // `docs/design/mockups/index.html` draws the rail as
      // 发现 → 内容库 → 我的音乐 → 下载管理. Search and now-playing live in
      // the top bar and the player bar respectively, and the playlist group
      // is folded into 我的音乐.
      expect(navigation.desktopOrder, <ThemeNavEntry>[
        ThemeNavEntry.discover,
        ThemeNavEntry.library,
        ThemeNavEntry.playlists,
        ThemeNavEntry.downloads,
      ]);
      expect(navigation.desktop, <ThemeNavEntry>{
        ThemeNavEntry.search,
        ThemeNavEntry.nowPlaying,
      });
    });

    test('the declared order leaves no built-in entry behind', () {
      final navigation = xuan().navigation;

      // A prefix, not a permutation: the two entries the skin hides
      // (search, nowPlaying) never render, but `applyOrder` is not the
      // hiding mechanism — `isHidden` is. Ordering the visible set keeps
      // the two hidden ones out without losing any visible entry.
      final all = <ThemeNavEntry>[...ThemeNavEntry.values]
          .where(
            (entry) =>
                entry != ThemeNavEntry.search &&
                entry != ThemeNavEntry.nowPlaying,
          )
          .toList();
      final ordered = navigation.applyOrder(
        all,
        RobyneFormFactor.desktop,
        (entry) => entry,
      );

      expect(ordered.length, all.length);
      expect(ordered.take(4), navigation.desktopOrder);
      expect(ordered.toSet(), all.toSet());
    });
  });
}
