import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:robyne/core/storage/local_file_store.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/domain/theme_tokens.dart';
import 'package:robyne/core/theme/infrastructure/theme_asset_resolver.dart';
import 'package:robyne/core/theme/infrastructure/theme_importer.dart';
import 'package:robyne/core/theme/infrastructure/theme_manifest_parser.dart';
import 'package:robyne/core/theme/infrastructure/theme_path_guard.dart';
import 'package:robyne/core/theme/infrastructure/theme_repository.dart';

void main() {
  group('ThemePathGuard.sanitizeId', () {
    test('a parent traversal id cannot escape the themes directory', () {
      expect(ThemePathGuard.sanitizeId('..'), isNot('..'));
      expect(ThemePathGuard.sanitizeId('...'), isNot(contains('..')));
      expect(ThemePathGuard.sanitizeId('....'), isNot(contains('..')));
    });

    test('a dot-only id falls back instead of resolving to a directory', () {
      expect(ThemePathGuard.sanitizeId('.'), isNotEmpty);
      expect(ThemePathGuard.sanitizeId('.').contains('..'), isFalse);
      expect(ThemePathGuard.sanitizeId('///'), isNotEmpty);
    });

    test('absolute and separator ids are neutralised', () {
      for (final id in <String>[
        '/etc/passwd',
        r'C:\Windows',
        'a/b',
        '..\\..',
      ]) {
        final safe = ThemePathGuard.sanitizeId(id);
        expect(safe.contains('/'), isFalse, reason: id);
        expect(safe.contains('\\'), isFalse, reason: id);
        expect(safe.contains('..'), isFalse, reason: id);
      }
    });

    test('an ordinary id survives untouched', () {
      expect(ThemePathGuard.sanitizeId('author.theme'), 'author.theme');
    });
  });

  group('ThemePathGuard.sanitizeAsset', () {
    test('rejects parent traversals', () {
      for (final asset in <String>[
        '../../../../etc/passwd',
        'a/../../b',
        '../bg.webp',
      ]) {
        expect(ThemePathGuard.sanitizeAsset(asset), isNull, reason: asset);
      }
    });

    test('rejects absolute paths and UNC shares', () {
      for (final asset in <String>[
        '/etc/passwd',
        r'C:\Users\Alice\private.jpg',
        r'\\attacker.example.com\share\leak.png',
        r'\\?\C:',
      ]) {
        expect(ThemePathGuard.sanitizeAsset(asset), isNull, reason: asset);
      }
    });

    test('accepts an in-package asset', () {
      expect(ThemePathGuard.sanitizeAsset('assets/bg.webp'), 'assets/bg.webp');
    });
  });

  group('ThemePathGuard.sanitizeArchiveEntry', () {
    test('rejects zip slip entries', () {
      for (final name in <String>[
        '../../evil.exe',
        'skin/../../evil.exe',
        r'C:\absolute\evil.exe',
        '/etc/cron.d/evil',
      ]) {
        expect(ThemePathGuard.sanitizeArchiveEntry(name), isNull, reason: name);
      }
    });

    test('accepts an ordinary entry', () {
      expect(ThemePathGuard.sanitizeArchiveEntry('assets/bg.webp'), isNotNull);
    });
  });

  group('FileThemeRepository', () {
    late Directory root;
    late Directory themesRoot;
    late FileThemeRepository repository;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('robyne_theme_sec_');
      repository = FileThemeRepository(
        fileStore: LocalFileStore(baseDirectory: root),
      );
      themesRoot = Directory(p.join(root.path, 'themes'));
    });

    tearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    Future<void> writeSkin(String id, String name) async {
      final dir = Directory(p.join(themesRoot.path, id));
      await dir.create(recursive: true);
      await File(
        p.join(dir.path, 'theme.json'),
      ).writeAsString(jsonEncode(<String, Object?>{'id': id, 'name': name}));
    }

    test(
      'deleting a traversal id cannot touch the support directory',
      () async {
        // A sibling of themes/ that must survive any delete attempt.
        final precious = Directory(p.join(root.path, 'data'));
        await precious.create(recursive: true);
        await File(p.join(precious.path, 'app.db')).writeAsString('precious');

        expect(await repository.deleteTheme('..'), isFalse);
        expect(await repository.deleteTheme('.'), isFalse);
        expect(await repository.deleteTheme('../../data'), isFalse);

        expect(await File(p.join(precious.path, 'app.db')).exists(), isTrue);
        expect(await precious.exists(), isTrue);
      },
    );

    test('deleting a real skin removes only that skin', () async {
      await writeSkin('doomed', 'Doomed');
      await writeSkin('keeper', 'Keeper');

      expect(await repository.deleteTheme('doomed'), isTrue);
      expect((await repository.listThemes()).map((theme) => theme.id), <String>[
        'keeper',
      ]);
    });

    test('an asset reference cannot escape the skin directory', () async {
      await writeSkin('escape', 'Escape');
      final outside = File(p.join(root.path, 'secret.png'));
      await outside.writeAsString('not really a png');

      final theme = await repository.loadTheme('escape');
      expect(theme, isNotNull);

      for (final asset in <String>[
        '../../secret.png',
        '../../../../secret.png',
        outside.path,
        r'\\attacker.example.com\share\leak.png',
      ]) {
        final resolved = await repository.resolveAssetPath(theme!, asset);
        expect(resolved, isNull, reason: asset);
      }
    });

    test('an in-package asset still resolves', () async {
      final dir = Directory(p.join(themesRoot.path, 'art'));
      await dir.create(recursive: true);
      await File(p.join(dir.path, 'theme.json')).writeAsString(
        jsonEncode(<String, Object?>{'id': 'art', 'name': 'Art'}),
      );
      await File(p.join(dir.path, 'bg.png')).writeAsString('png');

      final theme = await repository.loadTheme('art');
      final resolved = await repository.resolveAssetPath(theme!, 'bg.png');
      expect(resolved, isNotNull);
      expect(p.isWithin(dir.path, resolved!), isTrue);
    });
  });

  group('ThemeImporter', () {
    late Directory root;
    late Directory themesRoot;
    late ThemeImporter importer;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('robyne_theme_imp_');
      importer = ThemeImporter(
        themesDirectory: () async {
          themesRoot = Directory(p.join(root.path, 'themes'));
          if (!await themesRoot.exists()) {
            await themesRoot.create(recursive: true);
          }
          return themesRoot;
        },
      );
    });

    tearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    test(
      'a skin whose id is a traversal installs somewhere harmless',
      () async {
        final precious = Directory(p.join(root.path, 'data'));
        await precious.create(recursive: true);
        await File(p.join(precious.path, 'app.db')).writeAsString('precious');

        final source = Directory(p.join(root.path, 'source'));
        await source.create(recursive: true);
        await File(p.join(source.path, 'theme.json')).writeAsString(
          jsonEncode(<String, Object?>{'id': '..', 'name': 'Evil'}),
        );

        await importer.importFrom(source.path);

        expect(await File(p.join(precious.path, 'app.db')).exists(), isTrue);
        expect(await precious.exists(), isTrue);
        expect(await themesRoot.exists(), isTrue);
      },
    );

    test('a zip slip entry is not written outside the temp root', () async {
      final archive = Archive()
        ..addFile(ArchiveFile('theme.json', 2, utf8.encode('{}')))
        ..addFile(ArchiveFile('../../evil.txt', 3, utf8.encode('pwn')))
        ..addFile(ArchiveFile(r'C:\absolute\evil.txt', 3, utf8.encode('pwn')));
      final zip = File(p.join(root.path, 'evil.rtheme'));
      await zip.writeAsBytes(ZipEncoder().encode(archive));

      await importer.importFrom(zip.path);

      // Whatever the importer did, nothing may appear beside the root.
      final escaped = File(p.join(root.parent.path, 'evil.txt'));
      expect(await escaped.exists(), isFalse);
    });
  });

  group('TokenPatcher hardening', () {
    test('a knob cannot point the background at an arbitrary path', () {
      final theme = const ThemeManifestParser().tryParse(
        jsonDecode('''
        {
          "id": "hostile",
          "settings": [
            {"key": "bg", "type": "text", "label": "背景",
             "default": "../../../../secret.png", "target": "background.image"}
          ]
        }
        ''')
            as Object?,
        source: ThemeSource.user,
      );
      expect(theme, isNotNull);
      final values = themeSettingPatchValues(theme!, null);
      expect(values, isEmpty);
    });
  });

  group('Manifest hardening', () {
    test('non-finite numbers never enter the model', () {
      final theme = const ThemeManifestParser().tryParse(
        jsonDecode('''
        {
          "id": "numbers",
          "tokens": { "radius": { "md": "1e999" }, "spacing": { "xs": "1e999" } },
          "layout": {
            "desktop": { "playerBarHeight": "1e999",
                         "sidebar": { "width": "1e999" } }
          }
        }
        ''')
            as Object?,
        source: ThemeSource.user,
      );
      expect(theme, isNotNull);
      expect(theme!.tokens.radius.md, ThemeRadii.baseline().md);
      expect(theme.tokens.spacing.xs, ThemeSpacings.baseline().xs);
      expect(theme.layout.desktop.playerBarHeight.isFinite, isTrue);
      expect(theme.layout.desktop.sidebar.width.isFinite, isTrue);
    });

    test('oversized numbers are clamped, not propagated', () {
      final theme = const ThemeManifestParser().tryParse(
        jsonDecode('''
        { "id": "big", "layout": { "desktop": { "playerBarHeight": 100000 } } }
        ''')
            as Object?,
        source: ThemeSource.user,
      );
      expect(theme!.layout.desktop.playerBarHeight, lessThanOrEqualTo(200));
    });

    test('a background image that escapes is dropped at parse time', () {
      final theme = const ThemeManifestParser().tryParse(
        jsonDecode('''
        { "id": "escapist",
          "tokens": { "background": { "image": "../../../../etc/passwd" } } }
        ''')
            as Object?,
        source: ThemeSource.user,
      );
      expect(theme!.tokens.background.image, isNull);
    });

    test('free text is length capped', () {
      final long = 'x' * 5000;
      final theme = const ThemeManifestParser().tryParse(
        jsonDecode('{"id": "long", "name": "$long", "author": "$long"}')
            as Object?,
        source: ThemeSource.user,
      );
      expect(theme!.name.length, lessThanOrEqualTo(64));
      expect(theme.author.length, lessThanOrEqualTo(64));
    });
  });

  group('Knob targets', () {
    test('the UI map stays keyed by the knob name', () {
      // Regression: the settings controls read values by `key`. Switching
      // this to `target` made every slider snap back to its default.
      final theme = const ThemeManifestParser().tryParse(
        jsonDecode('''
        { "id": "knobby",
          "settings": [
            {"key": "cornerRadius", "type": "range", "label": "圆角",
             "min": 0, "max": 28, "default": 10, "target": "radius.md"}
          ] }
        ''')
            as Object?,
        source: ThemeSource.user,
      )!;

      expect(themeSettingValuesFor(theme, null)['cornerRadius'], 10);
      expect(
        themeSettingValuesFor(theme, <String, Object>{
          'knobby/cornerRadius': 24,
        })['cornerRadius'],
        24,
      );
    });

    test('a knob patches its token target, not its storage key', () {
      final theme = const ThemeManifestParser().tryParse(
        jsonDecode('''
        { "id": "knobby",
          "settings": [
            {"key": "brandColor", "type": "color", "label": "强调色",
             "default": "#F2B749", "target": "color.brand.base"}
          ] }
        ''')
            as Object?,
        source: ThemeSource.user,
      );
      expect(theme, isNotNull);

      // The bundled skins declare key != target, so keying by key would make
      // every knob a no-op.
      final values = themeSettingPatchValues(theme!, null);
      expect(values.containsKey('color.brand.base'), isTrue);
      expect(values.containsKey('brandColor'), isFalse);
    });

    test('a stored override wins over the default', () {
      final theme = const ThemeManifestParser().tryParse(
        jsonDecode('''
        { "id": "knobby",
          "settings": [
            {"key": "brandColor", "type": "color", "label": "强调色",
             "default": "#F2B749", "target": "color.brand.base"}
          ] }
        ''')
            as Object?,
        source: ThemeSource.user,
      )!;
      final values = themeSettingPatchValues(theme, <String, Object>{
        'knobby/brandColor': '#00FF00',
      });
      expect(values['color.brand.base'], '#00FF00');
    });

    test('a knob without a target is skipped rather than mis-applied', () {
      final theme = const ThemeManifestParser().tryParse(
        jsonDecode('''
        { "id": "targetless",
          "settings": [
            {"key": "brandColor", "type": "color", "label": "强调色",
             "default": "#F2B749"}
          ] }
        ''')
            as Object?,
        source: ThemeSource.user,
      )!;
      expect(themeSettingPatchValues(theme, null), isEmpty);
    });

    test('the bundled skins actually move their own tokens', () async {
      // Guards the real bundled manifests rather than a synthetic fixture:
      // every declared knob must resolve to a token target.
      for (final folder in const <String>[
        'official-light',
        'official-dark',
        'official-midnight',
      ]) {
        final file = File('assets/themes/$folder/theme.json');
        expect(await file.exists(), isTrue, reason: folder);
        final theme = const ThemeManifestParser().tryParse(
          jsonDecode(await file.readAsString()) as Object?,
          source: ThemeSource.builtIn,
        )!;
        expect(theme.settings, isNotEmpty, reason: folder);
        for (final setting in theme.settings) {
          expect(setting.target, isNotNull, reason: '$folder.${setting.key}');
        }
        final patch = themeSettingPatchValues(theme, null);
        expect(patch, isNotEmpty, reason: folder);
      }
    });
  });

  group('Asset budget', () {
    test('the documented budget constants exist and are sane', () {
      expect(ThemeAssetResolver.maxAssetBytes, 500 * 1024);
      expect(ThemeAssetResolver.maxPackageBytes, 10 * 1024 * 1024);
    });
  });
}
