import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/domain/theme_regions.dart';
import 'package:robyne/core/theme/infrastructure/theme_exporter.dart';
import 'package:robyne/core/theme/infrastructure/theme_manifest_parser.dart';
import 'package:robyne/core/theme/infrastructure/theme_path_guard.dart';

/// The skins shipped with the app, by folder name.
///
/// Read straight from disk rather than the asset bundle: these tests are
/// about the manifest *files*, and a bundle read would hide a file that is
/// simply missing from `pubspec.yaml` while still letting the app build.
const Map<String, String> _bundledManifests = <String, String>{
  'xuan': 'assets/themes/xuan/theme.json',
};

/// Covers Stage 2 work from `docs/THEME_ROADMAP.md`:
///   D5 (one-click copy of an official skin into a third-party one),
///   D6 (per-form-factor arrangements),
///   D7 (the application owns degradation).
void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('robyne_stage2_');
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  group('D5 one-click copy', () {
    /// A skin that lives on disk, standing in for a built-in one.
    ///
    /// The exporter reads whichever bytes the skin was parsed from, so
    /// exercising it against a real directory is the honest test.
    Future<Directory> writeSkin(
      String id,
      Map<String, Object?> manifest, {
      Map<String, List<int>>? assets,
    }) async {
      final directory = Directory(
        p.join(tempRoot.path, 'skins', ThemePathGuard.directoryName(id)),
      );
      await directory.create(recursive: true);
      await File(
        p.join(directory.path, 'theme.json'),
      ).writeAsString(jsonEncode(manifest));
      for (final entry in (assets ?? const <String, List<int>>{}).entries) {
        final file = File(p.join(directory.path, entry.key));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(entry.value);
      }
      return directory;
    }

    Future<ThemePackage> loadFrom(Directory directory) async {
      final decoded =
          jsonDecode(
                await File(p.join(directory.path, 'theme.json')).readAsString(),
              )
              as Map<String, Object?>;
      return const ThemeManifestParser().tryParse(
        decoded,
        source: ThemeSource.user,
      )!;
    }

    test(
      'a copied skin lands under the shared id -> directory mapping',
      () async {
        final source = await writeSkin('official.dark', <String, Object?>{
          'id': 'official.dark',
          'name': 'Robyne 暗色',
        });
        final package = await loadFrom(source);

        final target = Directory(p.join(tempRoot.path, 'themes'));
        final result = await ThemeExporter(
          themesDirectory: () async => target,
          sourceDirectory: () async => source.parent,
        ).export(package);

        expect(result.isSuccess, isTrue);
        expect(
          p.basename(result.directory!.path),
          ThemePathGuard.directoryName('official.dark'),
        );
        expect(
          await File(p.join(result.directory!.path, 'theme.json')).exists(),
          isTrue,
        );
      },
    );

    test('the copy parses to the same skin as the original', () async {
      // This is the actual D5 acceptance criterion: "behaves identically".
      // Comparing parsed packages catches both a mangled manifest and a
      // silently re-serialised one that would bake in different defaults.
      final manifest = <String, Object?>{
        'id': 'official.midnight',
        'name': '午夜琉璃',
        'mode': 'dark',
        'tokens': <String, Object?>{
          'color': <String, Object?>{
            'brand': <String, Object?>{'base': '#7CC4FF'},
          },
          'effects': <String, Object?>{'blur': 18},
        },
        'layout': <String, Object?>{
          'desktop': <String, Object?>{
            'arrangement': <Object?>[
              <String, Object?>{
                'region': 'navBar',
                'slot': 'left',
                'size': 0.2,
              },
              <String, Object?>{'region': 'content', 'slot': 'center'},
            ],
          },
        },
      };
      final source = await writeSkin('official.midnight', manifest);
      final original = await loadFrom(source);

      final target = Directory(p.join(tempRoot.path, 'themes'));
      final result = await ThemeExporter(
        themesDirectory: () async => target,
        sourceDirectory: () async => source.parent,
      ).export(original);
      expect(result.isSuccess, isTrue);

      final copy = await loadFrom(result.directory!);
      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.mode, original.mode);
      expect(copy.tokens.color.brandBase, original.tokens.color.brandBase);
      expect(copy.tokens.effects.blur, original.tokens.effects.blur);
      expect(
        copy.layout.desktop.arrangement,
        original.layout.desktop.arrangement,
      );
    });

    test('declared assets travel with the skin', () async {
      final source = await writeSkin(
        'asset.skin',
        <String, Object?>{
          'id': 'asset.skin',
          'assets': <String, Object?>{'background': 'art/bg.png'},
        },
        assets: <String, List<int>>{
          'art/bg.png': <int>[1, 2, 3, 4, 5],
        },
      );
      final package = await loadFrom(source);

      final target = Directory(p.join(tempRoot.path, 'themes'));
      final result = await ThemeExporter(
        themesDirectory: () async => target,
        sourceDirectory: () async => source.parent,
      ).export(package);
      expect(result.isSuccess, isTrue);
      expect(
        await File(p.join(result.directory!.path, 'art', 'bg.png')).exists(),
        isTrue,
      );
    });

    test('icon artwork travels with the skin', () async {
      // Per-icon images are referenced from `icons`, not `assets`, so a copy
      // that only walked `assets` silently dropped them — the copy rendered
      // Material glyphs where the original drew its own marks.
      final source = await writeSkin(
        'icon.skin',
        <String, Object?>{
          'id': 'icon.skin',
          'icons': <String, Object?>{
            'play': <String, Object?>{
              'image': 'marks/play.png',
              'activeImage': 'marks/play-on.png',
            },
          },
        },
        assets: <String, List<int>>{
          'marks/play.png': <int>[1, 2, 3],
          'marks/play-on.png': <int>[4, 5, 6],
        },
      );
      final package = await loadFrom(source);

      final target = Directory(p.join(tempRoot.path, 'themes'));
      final result = await ThemeExporter(
        themesDirectory: () async => target,
        sourceDirectory: () async => source.parent,
      ).export(package);

      expect(result.isSuccess, isTrue);
      for (final asset in <String>['marks/play.png', 'marks/play-on.png']) {
        expect(
          await File(p.join(result.directory!.path, asset)).exists(),
          isTrue,
          reason: '$asset must survive the copy',
        );
      }
    });

    test('re-exporting replaces the previous copy', () async {
      final source = await writeSkin('replace.skin', <String, Object?>{
        'id': 'replace.skin',
        'name': '第一版',
      });
      final target = Directory(p.join(tempRoot.path, 'themes'));
      final exporter = ThemeExporter(
        themesDirectory: () async => target,
        sourceDirectory: () async => source.parent,
      );

      final first = await exporter.export(await loadFrom(source));
      expect(first.isSuccess, isTrue);

      await File(p.join(source.path, 'theme.json')).writeAsString(
        jsonEncode(<String, Object?>{'id': 'replace.skin', 'name': '第二版'}),
      );
      final second = await exporter.export(await loadFrom(source));
      expect(second.isSuccess, isTrue);

      final copy = await loadFrom(second.directory!);
      expect(copy.name, '第二版');
    });

    test('a user skin can be re-exported onto itself', () async {
      final source = await writeSkin('self.skin', <String, Object?>{
        'id': 'self.skin',
        'name': 'Self Export',
      });
      final package = await loadFrom(source);

      final result = await ThemeExporter(
        themesDirectory: () async => source.parent,
        sourceDirectory: () async => source.parent,
      ).export(package);

      expect(result.isSuccess, isTrue);
      final reparsed = await loadFrom(source);
      expect(reparsed.name, 'Self Export');
    });

    test('a skin id cannot escape the themes directory', () async {
      // Zip Slip, export flavour: the id is attacker-controlled once a user
      // imports a skin, so the export path must be re-checked.
      final target = Directory(p.join(tempRoot.path, 'themes'));
      await target.create(recursive: true);
      final package = const ThemeManifestParser().tryParse(<String, Object?>{
        'id': '../../../escaped',
      }, source: ThemeSource.user)!;

      final result = await ThemeExporter(
        themesDirectory: () async => target,
      ).export(package);

      // Either refused outright, or written inside the themes directory.
      if (result.isSuccess) {
        expect(
          ThemePathGuard.isWithin(target.path, result.directory!.path),
          isTrue,
        );
      }
    });
  });

  group('bundled skin manifests', () {
    test('no manifest key is declared twice', () {
      // `jsonDecode` silently keeps the last of any repeated key, so a skin
      // carrying two `"desktop"` blocks is valid JSON, parses cleanly, and
      // quietly renders the *other* block. That happened to `official-dark`:
      // a hand-edit added an arrangement above the existing desktop block, so
      // the flagship layout was dead on arrival while every test passed.
      //
      // Decoding cannot see this — the duplicate is gone by then — so the
      // scan runs on the raw text, tracking object nesting by depth.
      for (final manifest in _bundledManifests.entries) {
        final keys = _duplicateKeys(File(manifest.value).readAsStringSync());
        expect(
          keys,
          isEmpty,
          reason:
              '${manifest.key} declares $keys more than once in the same '
              'object; jsonDecode keeps only the last one',
        );
      }
    });

    test('every bundled skin declares a usable arrangement', () {
      // Guards the same failure from the other end: whatever the manifest
      // holds, each form factor must resolve to an arrangement that lays out
      // `content`.
      for (final manifest in _bundledManifests.entries) {
        final decoded =
            jsonDecode(File(manifest.value).readAsStringSync())
                as Map<String, Object?>;
        final layout = decoded['layout'];
        for (final formFactor in RobyneFormFactor.values) {
          final raw =
              layout is Map &&
                  layout[formFactor.name] is Map &&
                  (layout[formFactor.name]! as Map)['arrangement'] is List
              ? (layout[formFactor.name]! as Map)['arrangement']
              : null;
          final arrangement = RobyneArrangement.parse(
            raw,
            formFactor: formFactor,
          );
          expect(
            arrangement.placementFor(RobyneRegion.content),
            isNotNull,
            reason: '${manifest.key} has no content region on $formFactor',
          );
        }
      }
    });

    test('every bundled skin declares flagship component tokens', () {
      // Stage 2 depends on the official skins exercising the component layer
      // the UI reads: nav/player surfaces and the lyric active/inactive pair.
      for (final manifest in _bundledManifests.entries) {
        final decoded =
            jsonDecode(File(manifest.value).readAsStringSync())
                as Map<String, Object?>;
        final tokens = decoded['tokens'];
        expect(tokens, isA<Map<Object?, Object?>>(), reason: manifest.key);
        final components = (tokens as Map)['components'];
        expect(
          components,
          isA<Map<Object?, Object?>>(),
          reason: '${manifest.key} must put components under tokens',
        );
        final componentMap = components as Map;
        expect(componentMap['navBar'], isA<Map<Object?, Object?>>());
        expect(componentMap['playerBar'], isA<Map<Object?, Object?>>());
        expect(componentMap['lyric'], isA<Map<Object?, Object?>>());
      }
    });
  });
}

/// Keys declared more than once inside the same JSON object, by path.
///
/// Operates on the raw text because the duplicate is the one thing a decoded
/// map cannot report: `jsonDecode` has already collapsed it by then. A tiny
/// hand-rolled scanner is enough here, since a manifest is only ever the
/// output of `JsonEncoder` or a text editor, not adversarial JSON.
List<String> _duplicateKeys(String source) {
  final duplicates = <String>[];
  // Stack of (path, keys-seen-so-far), one frame per open container. Arrays
  // push a frame with a null key set so their elements cannot be mistaken
  // for members of the enclosing object.
  final stack = <_JsonScope>[];
  final buffer = StringBuffer();
  var inString = false;
  var escaped = false;
  var pendingColon = false;

  for (var index = 0; index < source.length; index += 1) {
    final char = source[index];
    if (inString) {
      if (escaped) {
        escaped = false;
        buffer.write(char);
      } else if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
      } else {
        buffer.write(char);
      }
      continue;
    }
    switch (char) {
      case '"':
        // Every string is a candidate key; the following ':' decides. A value
        // string is cleared when its comma or bracket arrives instead.
        if (pendingColon) {
          buffer.clear();
        }
        inString = true;
        buffer.clear();
      case ':':
        if (pendingColon) {
          break;
        }
        pendingColon = true;
        final scope = stack.isEmpty ? null : stack.last;
        if (scope != null && scope.isObject) {
          final key = buffer.toString();
          if (!scope.keys.add(key)) {
            duplicates.add(<String>[...scope.path, key].join('.'));
          }
          // Keep the key: the value's '{' opens the child frame named after
          // it. Scalars are cleared by the following ',' or '}'.
          scope.childPath = <String>[...scope.path, key];
        }
      case '{':
      case '[':
        final scope = stack.isEmpty ? null : stack.last;
        stack.add(
          _JsonScope(char == '{', scope?.childPath ?? const <String>[]),
        );
        buffer.clear();
        pendingColon = false;
      case '}':
      case ']':
        if (stack.isNotEmpty) {
          stack.removeLast();
        }
        buffer.clear();
        pendingColon = false;
      case ',':
        buffer.clear();
        pendingColon = false;
      default:
        break;
    }
  }
  return duplicates;
}

/// One open `{` or `[` while scanning a manifest for duplicate keys.
class _JsonScope {
  _JsonScope(this.isObject, this.path);

  /// The dotted path of keys that led here.
  final List<String> path;

  /// The path the next child frame should inherit: this frame's path plus the
  /// key of the value being opened. Cleared once consumed.
  List<String>? childPath;

  /// Arrays hold positional values, so only object frames track keys.
  final bool isObject;

  final Set<String> keys = <String>{};
}
