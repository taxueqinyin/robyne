import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/network/plugin_http_client.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/plugin/infrastructure/music_free_compat_adapter.dart';
import 'package:robyne/features/plugin/infrastructure/quickjs_plugin_runtime.dart';

void main() {
  test(
    'dispose waits for timed-out Dart bridge calls before releasing QuickJS',
    () async {
      final bridgeCompleter = Completer<void>();
      final runtime = QuickJsPluginRuntime(
        httpClient: _ControlledPluginHttpClient(bridgeCompleter),
      );
      addTearDown(runtime.dispose);

      final loaded = await runtime.loadPlugin('''
      const axios = require('axios');
      module.exports = {
        platform: 'slow-demo',
        async search() {
          await axios.get('https://example.com/slow');
          return { isEnd: true, data: [] };
        }
      };
    ''');
      expect(loaded, isA<Ok<Map<String, Object?>>>());

      final searched = await runtime.callMethod(
        'search',
        const <Object?>[],
        timeout: const Duration(milliseconds: 50),
      );
      expect(searched, isA<Failure<Object?>>());

      final disposeFuture = runtime.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bridgeCompleter.isCompleted, isFalse);

      bridgeCompleter.complete();
      await disposeFuture.timeout(const Duration(seconds: 5));
    },
    skip: Platform.environment['RUN_PLUGIN_SPIKE'] != 'true',
    timeout: const Timeout(Duration(seconds: 10)),
  );

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
    'env.getUserVariables returns values provided by Dart',
    () async {
      final runtime = QuickJsPluginRuntime(httpClient: PluginHttpClient());
      addTearDown(runtime.dispose);

      final loaded = await runtime.loadPlugin(
        '''
      module.exports = {
        platform: 'variables-demo',
        async search() {
          return env.getUserVariables();
        }
      };
    ''',
        userVariables: const <String, String>{
          'music_u': 'cookie-value',
          'enabled': 'true',
        },
      );
      expect(loaded, isA<Ok<Map<String, Object?>>>());

      final result = await runtime.callMethod('search', const <Object?>[]);
      final value = (result as Ok<Object?>).value as Map;
      expect(value['music_u'], 'cookie-value');
      expect(value['enabled'], 'true');
    },
    skip: Platform.environment['RUN_PLUGIN_SPIKE'] != 'true',
  );

  test(
    'loads and calls bundled MusicFree test plugins',
    () async {
      final vendorSource = await File(
        'assets/js/musicfree_vendor.js',
      ).readAsString();

      final failures = <String>[];
      for (final path in <String>[
        'test_files/fixture-a.js',
        'test_files/fixture-b.js',
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

  test(
    'loads metadata for every plugin fixture without invoking network methods',
    () async {
      final vendorSource = await File(
        'assets/js/musicfree_vendor.js',
      ).readAsString();
      final pluginFiles =
          Directory('test_files')
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.js'))
              .toList()
            ..sort((left, right) => left.path.compareTo(right.path));

      expect(pluginFiles, isNotEmpty);

      final failures = <String>[];
      for (final file in pluginFiles) {
        // Printed only when RUN_PLUGIN_SPIKE is enabled, to identify fixtures
        // that fail during QuickJS top-level evaluation.
        // ignore: avoid_print
        print('loading plugin fixture ${file.path}');
        final runtime = QuickJsPluginRuntime(
          httpClient: PluginHttpClient(),
          vendorSource: vendorSource,
        );
        addTearDown(runtime.dispose);

        final loaded = await runtime.loadPlugin(await file.readAsString());
        loaded.fold<void>(
          (metadata) {
            final platform = metadata['platform'];
            if (platform is! String || platform.isEmpty) {
              failures.add('${file.path}: missing platform');
            }
          },
          (error) {
            failures.add('${file.path}: $error cause=${error.cause}');
          },
        );
      }

      if (failures.isNotEmpty) {
        fail(failures.join('\n'));
      }
    },
    skip: Platform.environment['RUN_PLUGIN_SPIKE'] != 'true',
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'reports search and media compatibility for music plugin fixtures',
    () async {
      final vendorSource = await File(
        'assets/js/musicfree_vendor.js',
      ).readAsString();
      final adapter = MusicFreeCompatAdapter();
      final pluginFiles =
          Directory('test_files')
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.js'))
              .toList()
            ..sort((left, right) => left.path.compareTo(right.path));

      expect(pluginFiles, isNotEmpty);

      for (final file in pluginFiles) {
        final source = await file.readAsString();
        final runtime = QuickJsPluginRuntime(
          httpClient: PluginHttpClient(),
          vendorSource: vendorSource,
        );
        addTearDown(runtime.dispose);

        final loaded = await runtime.loadPlugin(source);
        final metadata = loaded.fold<Map<String, Object?>?>((value) => value, (
          error,
        ) {
          // ignore: avoid_print
          print(
            '${file.path}: metadata failed: ${error.code} ${error.message}',
          );
          return null;
        });
        if (metadata == null) {
          await runtime.dispose();
          continue;
        }

        final platform = metadata['platform'];
        if (platform is! String) {
          // ignore: avoid_print
          print('${file.path}: skipped, missing platform metadata');
          await runtime.dispose();
          continue;
        }

        final searched = await runtime.callMethod('search', const <Object?>[
          '周杰伦',
          1,
          'music',
        ], timeout: const Duration(seconds: 75));
        if (searched case Failure<Object?>(:final error)) {
          // ignore: avoid_print
          print(
            '${file.path} [$platform]: search failed: '
            '${error.code} ${error.message} cause=${error.cause}',
          );
          await runtime.dispose();
          continue;
        }

        final searchValue = (searched as Ok<Object?>).value;
        if (searchValue == null) {
          // ignore: avoid_print
          print(
            '${file.path} [$platform]: search returned null for music type',
          );
          await runtime.dispose();
          continue;
        }

        final searchResult = adapter.searchResultFromPluginValue(
          searchValue,
          pluginId: platform,
          platform: platform,
          page: 1,
        );
        final items = searchResult.fold((value) => value.items, (error) {
          // ignore: avoid_print
          print(
            '${file.path} [$platform]: search adapt failed: '
            '${error.code} ${error.message} cause=${error.cause}',
          );
          return const [];
        });
        if (items.isEmpty) {
          // ignore: avoid_print
          print('${file.path} [$platform]: search returned no items');
          await runtime.dispose();
          continue;
        }

        final media = await runtime.callMethod('getMediaSource', <Object?>[
          items.first.raw,
          'standard',
        ], timeout: const Duration(seconds: 75));
        media.fold<void>(
          (value) {
            final mediaSource = adapter.mediaSourceFromPluginValue(value);
            mediaSource.fold<void>(
              (source) {
                // ignore: avoid_print
                print(
                  '${file.path} [$platform]: search ok (${items.length}), '
                  'media ok (${source.url.length} chars)',
                );
              },
              (error) {
                // ignore: avoid_print
                print(
                  '${file.path} [$platform]: media adapt failed: '
                  '${error.code} ${error.message} cause=${error.cause}',
                );
              },
            );
          },
          (error) {
            // ignore: avoid_print
            print(
              '${file.path} [$platform]: media failed: '
              '${error.code} ${error.message} cause=${error.cause}',
            );
          },
        );
        await runtime.dispose();
      }
    },
    skip: Platform.environment['RUN_PLUGIN_SPIKE'] != 'true',
    timeout: const Timeout(Duration(minutes: 12)),
  );
}

class _ControlledPluginHttpClient extends PluginHttpClient {
  _ControlledPluginHttpClient(this._completer);

  final Completer<void> _completer;

  @override
  Future<Map<String, Object?>> request(Map<String, Object?> config) async {
    await _completer.future;
    return <String, Object?>{
      'data': <String, Object?>{},
      'status': 200,
      'statusText': 'OK',
      'headers': <String, Object?>{},
      'requestOptions': <String, Object?>{
        'uri': (config['url'] ?? '').toString(),
      },
    };
  }
}
