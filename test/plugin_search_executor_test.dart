import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/infrastructure/quickjs_plugin_runtime.dart';

void main() {
  test(
    'QuickJS search executor runs plugin search in a background isolate',
    () async {
      final executor = QuickJsIsolatePluginSearchExecutor(
        vendorSourceLoader: () async => null,
      );
      final plugin = PluginDefinition(
        id: 'plugin:test',
        platform: 'Test',
        sourcePath: 'test.js',
        enabled: true,
        installedAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final result = await executor.search(
        plugin: plugin,
        source: '''
        module.exports = {
          platform: 'Test',
          search(keyword, page, type) {
            return {
              page,
              isEnd: true,
              data: [{ id: '1', title: keyword + '-' + type }]
            };
          }
        };
      ''',
        keyword: 'hello',
        page: 1,
        searchType: 'music',
      );

      if (result case Failure<Object?>(:final error)) {
        fail('${error.code}: ${error.message} cause=${error.cause}');
      }
      expect(result, isA<Ok<Object?>>());
      final value = (result as Ok<Object?>).value as Map;
      expect(
        (value['data'] as List).single,
        containsPair('title', 'hello-music'),
      );
    },
    skip: Platform.environment['RUN_PLUGIN_SPIKE'] != 'true',
  );
}
