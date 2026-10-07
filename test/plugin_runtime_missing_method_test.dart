import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/network/plugin_http_client.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/plugin/infrastructure/quickjs_plugin_runtime.dart';

/// Regression cover for the "search crashes the app" report.
///
/// The app calls plugin methods it has not verified exist (`getTopLists`,
/// `getRecommendSheetTags`, …). When one is missing, the old bridge produced a
/// *rejected JS promise*, and the unhandled rejection aborted the isolate —
/// the whole app disappeared. A missing method must come back as an ordinary
/// failure the UI can render, and the runtime must stay usable afterwards.
void main() {
  test(
    'a missing plugin method fails the call without killing the runtime',
    () async {
      final runtime = QuickJsPluginRuntime(httpClient: PluginHttpClient());
      addTearDown(runtime.dispose);

      final loaded = await runtime.loadPlugin('''
      module.exports = {
        platform: 'missing-methods',
        async search() { return { isEnd: true, data: [] }; }
      };
    ''');
      expect(loaded, isA<Ok<Map<String, Object?>>>());

      final missing = await runtime.callMethod(
        'getTopLists',
        const <Object?>[],
      );
      expect(missing, isA<Failure<Object?>>());
      final error = (missing as Failure<Object?>).error;
      expect(error.code, 'plugin.method_not_found');
      expect(error.message, contains('getTopLists'));

      // The decisive assertion: the runtime is still alive. Under the old
      // behaviour this second call never returned, because the isolate had
      // already been torn down by the unhandled rejection.
      final stillWorks = await runtime.callMethod('search', const <Object?>[]);
      expect(stillWorks, isA<Ok<Object?>>());
    },
    skip: Platform.environment['RUN_PLUGIN_SPIKE'] != 'true',
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'a plugin method that throws is reported as a failure',
    () async {
      final runtime = QuickJsPluginRuntime(httpClient: PluginHttpClient());
      addTearDown(runtime.dispose);

      await runtime.loadPlugin('''
      module.exports = {
        platform: 'throwing',
        async getTopLists() { throw new Error('upstream exploded'); }
      };
    ''');

      final result = await runtime.callMethod('getTopLists', const <Object?>[]);
      expect(result, isA<Failure<Object?>>());
      expect(
        (result as Failure<Object?>).error.message,
        contains('upstream exploded'),
      );
    },
    skip: Platform.environment['RUN_PLUGIN_SPIKE'] != 'true',
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
