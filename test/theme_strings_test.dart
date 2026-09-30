import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/domain/theme_strings.dart';
import 'package:robyne/core/theme/infrastructure/theme_manifest_parser.dart';
import 'package:robyne/core/theme/infrastructure/theme_manifest.dart';

/// `strings` lets a skin rename the shell chrome it already composes.
///
/// The set is closed on purpose: this is a skin capability, not a localisation
/// system, and feature pages keep their own copy.
void main() {
  group('theme strings', () {
    test('an undeclared slot falls back to the neutral default', () {
      const strings = ThemeStrings.empty();

      expect(strings.isEmpty, isTrue);
      expect(strings.resolve(ThemeStringKey.navLibrary), 'Library');
      expect(strings.declared(ThemeStringKey.navLibrary), isNull);
    });

    test('a declared slot wins over the default', () {
      final strings = ThemeStrings.parse(<String, Object?>{
        'nav.library': '内容库',
      });

      expect(strings.resolve(ThemeStringKey.navLibrary), '内容库');
      // Unrelated slots still fall back, so a skin declares only what it wants.
      expect(strings.resolve(ThemeStringKey.navDiscover), 'Discover');
    });

    test('every key round-trips through its json name', () {
      for (final key in ThemeStringKey.values) {
        expect(ThemeStringKey.fromJsonKey(key.jsonKey), key);
      }
    });

    test('unknown keys are dropped rather than fatal', () {
      final strings = ThemeStrings.parse(<String, Object?>{
        'nav.library': '内容库',
        'nav.invented': 'nope',
        '': 'nope',
      });

      expect(strings.resolve(ThemeStringKey.navLibrary), '内容库');
      expect(strings.isEmpty, isFalse);
    });

    test('non-text values are dropped', () {
      final strings = ThemeStrings.parse(<String, Object?>{
        'nav.library': <String>['nope'],
        'nav.discover': null,
      });

      expect(strings.isEmpty, isTrue);
    });

    test('text is trimmed and length-capped', () {
      final strings = ThemeStrings.parse(<String, Object?>{
        'nav.library': '  ${'x' * 200}  ',
      });

      expect(strings.resolve(ThemeStringKey.navLibrary).length, 64);
    });

    test('equality ignores declaration order', () {
      final a = ThemeStrings.parse(<String, Object?>{
        'nav.library': '内容库',
        'nav.discover': '发现',
      });
      final b = ThemeStrings.parse(<String, Object?>{
        'nav.discover': '发现',
        'nav.library': '内容库',
      });

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('round-trips through toJson', () {
      final strings = ThemeStrings.parse(<String, Object?>{
        'nav.library': '内容库',
        'queue.count': '{count} 首',
      });

      expect(ThemeStrings.parse(strings.toJson()), strings);
    });
  });

  group('the manifest reads strings', () {
    test('a skin can declare chrome text', () {
      final package = parseThemeManifest(<String, Object?>{
        'id': 'test',
        'strings': <String, Object?>{'nav.library': '内容库'},
      }, source: ThemeSource.user)!;

      expect(package.strings.resolve(ThemeStringKey.navLibrary), '内容库');
    });

    test('a manifest without strings uses the defaults', () {
      final package = parseThemeManifest(<String, Object?>{
        'id': 'test',
      }, source: ThemeSource.user)!;

      expect(package.strings.isEmpty, isTrue);
      expect(package.strings.resolve(ThemeStringKey.navLibrary), 'Library');
    });

    test('a malformed strings block is ignored, not fatal', () {
      final package = parseThemeManifest(<String, Object?>{
        'id': 'test',
        'strings': 'nope',
      }, source: ThemeSource.user)!;

      expect(package.strings.isEmpty, isTrue);
    });

    test('copyWith carries strings', () {
      final package = parseThemeManifest(<String, Object?>{
        'id': 'test',
      }, source: ThemeSource.user)!;
      final renamed = package.copyWith(
        strings: ThemeStrings.parse(<String, Object?>{'nav.settings': '偏好设置'}),
      );

      expect(renamed.strings.resolve(ThemeStringKey.navSettings), '偏好设置');
      expect(package.strings.resolve(ThemeStringKey.navSettings), 'Settings');
    });
  });

  group('flagship《玄》', () {
    test('names its own chrome in the design language', () {
      final file = File('assets/themes/xuan/theme.json');
      final decoded =
          jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final package = const ThemeManifestParser().tryParse(
        decoded,
        source: ThemeSource.builtIn,
      )!;

      // These are the labels the design sheets actually draw; hard-coding
      // English in the shell is what made the rail disagree with the mockup.
      expect(package.strings.resolve(ThemeStringKey.navDiscover), '发现');
      expect(package.strings.resolve(ThemeStringKey.navLibrary), '内容库');
      expect(package.strings.resolve(ThemeStringKey.navSettings), '设置');
      expect(package.strings.resolve(ThemeStringKey.queueTitle), '当前播放');
      expect(package.strings.resolve(ThemeStringKey.playerVolume), '音量');
      expect(package.strings.resolve(ThemeStringKey.searchHint), '搜索歌曲、歌手、专辑');
      expect(
        package.strings.resolve(ThemeStringKey.discoverRankingEntry),
        '插件榜单',
      );
      expect(package.strings.resolve(ThemeStringKey.trayQueue), '队列');
      expect(
        package.strings.resolve(ThemeStringKey.settingsTrayCloseAction),
        '关闭按钮行为',
      );
      expect(
        package.strings.resolve(ThemeStringKey.settingsTrayCloseAsk),
        '每次询问',
      );
    });

    test('covers every navigation slot it renders', () {
      final file = File('assets/themes/xuan/theme.json');
      final decoded =
          jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final package = const ThemeManifestParser().tryParse(
        decoded,
        source: ThemeSource.builtIn,
      )!;

      for (final key in <ThemeStringKey>[
        ThemeStringKey.navSearch,
        ThemeStringKey.navDiscover,
        ThemeStringKey.navLibrary,
        ThemeStringKey.navNowPlaying,
        ThemeStringKey.navLiked,
        ThemeStringKey.navPlaylists,
        ThemeStringKey.navDownloads,
        ThemeStringKey.navPlugins,
        ThemeStringKey.navSettings,
        ThemeStringKey.navSectionPlaylists,
        ThemeStringKey.tabDiscover,
        ThemeStringKey.tabLibrary,
        ThemeStringKey.tabSearch,
        ThemeStringKey.tabMine,
      ]) {
        expect(
          package.strings.declared(key),
          isNotNull,
          reason: '${key.jsonKey} should be declared so the rail is coherent',
        );
      }
    });
  });
}
