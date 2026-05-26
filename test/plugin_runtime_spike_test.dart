import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/network/plugin_http_client.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/plugin/infrastructure/quickjs_plugin_runtime.dart';

void main() {
  test(
    'QuickJS bridge can load demo plugin and await Dart HTTP bridge',
    () async {
      final vendorSource = await File(
        'assets/js/musicfree_vendor.js',
      ).readAsString();
      final runtime = QuickJsPluginRuntime(
        httpClient: PluginHttpClient(),
        vendorSource: vendorSource,
      );
      addTearDown(runtime.dispose);

      final loaded = await runtime.loadPlugin('''
      const axios = require('axios');
      module.exports = {
        platform: 'demo',
        version: '0.1.0',
        supportedSearchType: ['music'],
        async search(query, page, type) {
          const res = await axios.get('https://httpbin.org/json');
          return { isEnd: true, data: [{ id: '1', title: query, rawTitle: res.data.slideshow.title }] };
        },
        async getMediaSource() {
          return { url: 'https://example.com/a.mp3', headers: { Referer: 'https://example.com' } };
        }
      };
    ''');

      expect(loaded, isA<Ok<Map<String, Object?>>>());
      final searched = await runtime.callMethod('search', <Object?>[
        '周杰伦',
        1,
        'music',
      ], timeout: const Duration(seconds: 20));
      final value = searched.fold((result) => result, (error) => throw error);
      expect(value, isA<Map>());
      expect((value as Map)['data'], isA<List>());
    },
    skip: Platform.environment['RUN_PLUGIN_SPIKE'] != 'true',
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'loads and calls bundled MusicFree test plugins',
    () async {
      final vendorSource = await File(
        'assets/js/musicfree_vendor.js',
      ).readAsString();

      final failures = <String>[];
      for (final path in <String>[
        'test_files/bilibili.js',
        'test_files/网易云.js',
      ]) {
        final runtime = QuickJsPluginRuntime(
          httpClient: PluginHttpClient(),
          vendorSource: vendorSource,
        );
        addTearDown(runtime.dispose);

        final source = await File(path).readAsString();
        final loaded = await runtime.loadPlugin(source);
        expect(loaded, isA<Ok<Map<String, Object?>>>(), reason: path);

        final searched = await runtime.callMethod('search', <Object?>[
          '周杰伦',
          1,
          'music',
        ], timeout: const Duration(seconds: 75));
        final searchError = searched.fold<String?>(
          (_) => null,
          (error) => '$path search failed: $error cause=${error.cause}',
        );
        if (searchError != null) {
          failures.add(searchError);
          continue;
        }
        final searchValue = (searched as Ok<Object?>).value;
        expect(searchValue, isA<Map>(), reason: '$path search');
        final items = (searchValue as Map)['data'];
        expect(items, isA<List>(), reason: '$path search data');
        expect(items as List, isNotEmpty, reason: '$path search items');

        final media = await runtime.callMethod('getMediaSource', <Object?>[
          items.first,
          'standard',
        ], timeout: const Duration(seconds: 75));
        final mediaError = media.fold<String?>(
          (_) => null,
          (error) => '$path media failed: $error cause=${error.cause}',
        );
        if (mediaError != null) {
          failures.add(mediaError);
          continue;
        }
        final mediaValue = (media as Ok<Object?>).value;
        expect(mediaValue, isA<Map>(), reason: '$path media');
        expect(
          (mediaValue as Map)['url'],
          isA<String>(),
          reason: '$path media url',
        );
      }
      if (failures.isNotEmpty) {
        fail(failures.join('\n'));
      }
    },
    skip: Platform.environment['RUN_PLUGIN_SPIKE'] != 'true',
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
