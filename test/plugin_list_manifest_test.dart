import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/plugin/domain/plugin_list_manifest.dart';

void main() {
  group('parse', () {
    test('reads the music.nairocy.com shape', () {
      final result = PluginListManifest.parse('''
{
  "plugins": [
    {"name": "source-a", "url": "https://example.com/a.js", "id": 1},
    {"name": "碳酸Meting", "url": "https://example.com/b.js", "id": 2}
  ]
}
''');
      final manifest = (result as Ok<PluginListManifest?>).value!;
      expect(manifest.entries, hasLength(2));
      expect(manifest.entries[0].url, 'https://example.com/a.js');
      expect(manifest.entries[0].name, 'source-a');
      expect(manifest.entries[0].label, 'source-a (https://example.com/a.js)');
    });

    test('accepts a bare array and bare strings', () {
      final bareArray = PluginListManifest.parse(
        '["https://example.com/a.js", "https://example.com/b.js"]',
      );
      expect(
        (bareArray as Ok<PluginListManifest?>).value!.entries.map(
          (entry) => entry.url,
        ),
        <String>['https://example.com/a.js', 'https://example.com/b.js'],
      );

      final bareStrings = PluginListManifest.parse(
        '["https://example.com/a.js"]',
      );
      expect(
        (bareStrings as Ok<PluginListManifest?>).value!.entries.single.url,
        'https://example.com/a.js',
      );
    });

    test('accepts common key aliases', () {
      final result = PluginListManifest.parse('''
{"list": [{"title": "A", "src": "https://example.com/a.js"}]}
''');
      final entry = (result as Ok<PluginListManifest?>).value!.entries.single;
      expect(entry.url, 'https://example.com/a.js');
      expect(entry.name, 'A');
    });

    test('resolves relative URLs against the manifest location', () {
      final result = PluginListManifest.parse(
        '{"plugins": [{"url": "plugins/a.js"}]}',
        base: Uri.parse('https://example.com/lists/plugins.json'),
      );
      expect(
        (result as Ok<PluginListManifest?>).value!.entries.single.url,
        'https://example.com/lists/plugins/a.js',
      );
    });

    test('drops duplicates and non-http entries', () {
      final result = PluginListManifest.parse('''
{
  "plugins": [
    {"url": "https://example.com/a.js"},
    {"url": "https://example.com/a.js"},
    {"url": "file:///etc/passwd"},
    {"url": ""},
    {"url": null},
    {"name": "no url"},
    "https://example.com/b.js"
  ]
}
''');
      expect(
        (result as Ok<PluginListManifest?>).value!.entries.map(
          (entry) => entry.url,
        ),
        <String>['https://example.com/a.js', 'https://example.com/b.js'],
      );
    });

    test('returns null for JavaScript plugin sources', () {
      expect(
        (PluginListManifest.parse('module.exports = {};')
                as Ok<PluginListManifest?>)
            .value,
        isNull,
      );
      expect(
        (PluginListManifest.parse('!function(){}();')
                as Ok<PluginListManifest?>)
            .value,
        isNull,
      );
    });

    test('returns null for JSON that is not a plugin list', () {
      expect(
        (PluginListManifest.parse('{"platform": "x", "version": "1.0.0"}')
                as Ok<PluginListManifest?>)
            .value,
        isNull,
      );
      expect(
        (PluginListManifest.parse('{"plugins": "nope"}')
                as Ok<PluginListManifest?>)
            .value,
        isNull,
      );
    });

    test('returns null for malformed JSON instead of throwing', () {
      expect(
        (PluginListManifest.parse('{"plugins": [') as Ok<PluginListManifest?>)
            .value,
        isNull,
      );
      expect(
        (PluginListManifest.parse('') as Ok<PluginListManifest?>).value,
        isNull,
      );
    });

    test('caps the number of entries', () {
      final entries = <String>[
        for (var index = 0; index < 250; index += 1)
          '{"url": "https://example.com/$index.js"}',
      ];
      final result = PluginListManifest.parse(
        '{"plugins": [${entries.join(',')}]}',
      );
      expect(
        (result as Ok<PluginListManifest?>).value!.entries,
        hasLength(200),
      );
    });

    test('reports an empty plugins array as an empty manifest', () {
      final result = PluginListManifest.parse('{"plugins": []}');
      final manifest = (result as Ok<PluginListManifest?>).value!;
      expect(manifest.isEmpty, isTrue);
      expect(manifest.length, 0);
    });
  });
}
