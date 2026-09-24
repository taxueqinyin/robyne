import 'dart:ui';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/storage/local_file_store.dart';
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/domain/theme_tokens.dart';
import 'package:robyne/core/theme/infrastructure/theme_manifest_parser.dart';
import 'package:robyne/core/theme/infrastructure/theme_repository.dart';
import 'package:robyne/core/theme/infrastructure/token_patcher.dart';

void main() {
  group('TokenPatcher', () {
    const patcher = TokenPatcher();

    test('applies a colour target', () {
      final patched = patcher.apply(
        const ThemeTokens.baseline(),
        <String, Object>{'color.brand.base': '#FF0000'},
      );
      expect(patched.color.brandBase, const Color(0xFFFF0000));
    });

    test('applies a radius target', () {
      final patched = patcher.apply(
        const ThemeTokens.baseline(),
        <String, Object>{'radius.md': 24},
      );
      expect(patched.radius.md, 24);
    });

    test('clamps out-of-range values instead of rejecting them', () {
      final patched = patcher.apply(
        const ThemeTokens.baseline(),
        <String, Object>{'effects.blur': 999},
      );
      expect(patched.effects.blur, 40);
    });

    test('leaves tokens untouched for unknown targets', () {
      const base = ThemeTokens.baseline();
      final patched = patcher.apply(base, <String, Object>{'nonsense.path': 1});
      expect(patched.color.brandBase, base.color.brandBase);
      expect(patched.radius.md, base.radius.md);
    });

    test('ignores malformed values', () {
      const base = ThemeTokens.baseline();
      final patched = patcher.apply(base, <String, Object>{
        'radius.md': 'not a number',
      });
      expect(patched.radius.md, base.radius.md);
    });

    test('applies several targets at once', () {
      final patched = patcher.apply(
        const ThemeTokens.baseline(),
        <String, Object>{
          'color.brand.base': '#00FF00',
          'effects.blur': 12,
          'typography.scale': 1.2,
        },
      );
      expect(patched.color.brandBase, const Color(0xFF00FF00));
      expect(patched.effects.blur, 12);
      expect(patched.typography.scale, 1.2);
    });
  });

  group('FileThemeRepository', () {
    late Directory root;
    late FileThemeRepository repository;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('robyne_theme_repo_');
      repository = FileThemeRepository(
        fileStore: LocalFileStore(baseDirectory: root),
      );
    });

    tearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    test('discovers installed themes', () async {
      final dir = Directory('${root.path}/themes/demo');
      await dir.create(recursive: true);
      await File('${dir.path}/theme.json').writeAsString(
        jsonEncode(<String, Object?>{'id': 'demo', 'name': 'Demo'}),
      );

      final themes = await repository.listThemes();
      expect(themes, hasLength(1));
      expect(themes.first.id, 'demo');
    });

    test('a broken manifest hides only that theme', () async {
      final broken = Directory('${root.path}/themes/broken');
      await broken.create(recursive: true);
      await File('${broken.path}/theme.json').writeAsString('{ not json');

      final good = Directory('${root.path}/themes/good');
      await good.create(recursive: true);
      await File('${good.path}/theme.json').writeAsString(
        jsonEncode(<String, Object?>{'id': 'good', 'name': 'Good'}),
      );

      final themes = await repository.listThemes();
      expect(themes.map((theme) => theme.id), <String>['good']);
    });

    test('deletes an installed theme', () async {
      final dir = Directory('${root.path}/themes/doomed');
      await dir.create(recursive: true);
      await File('${dir.path}/theme.json').writeAsString(
        jsonEncode(<String, Object?>{'id': 'doomed', 'name': 'Doomed'}),
      );

      expect(await repository.deleteTheme('doomed'), isTrue);
      expect(await repository.listThemes(), isEmpty);
      expect(await repository.deleteTheme('doomed'), isFalse);
    });
  });

  group('ThemeSettings', () {
    test('a declared knob patches exactly its target token', () {
      final theme = const ThemeManifestParser().tryParse(
        jsonDecode('''
        {
          "id": "knobby",
          "settings": [
            {"key": "accent", "type": "color", "label": "主色",
             "default": "#F2B749", "target": "color.brand.base"}
          ]
        }
        ''')
            as Object?,
        source: ThemeSource.user,
      );
      expect(theme, isNotNull);
      final setting = theme!.settings.single;
      expect(setting.target, 'color.brand.base');

      final patched = const TokenPatcher().apply(theme.tokens, <String, Object>{
        setting.target!: setting.defaultValue,
      });
      expect(patched.color.brandBase, const Color(0xFFF2B749));
    });
  });
}
