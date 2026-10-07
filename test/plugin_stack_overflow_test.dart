import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/network/plugin_http_client.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/plugin/infrastructure/quickjs_plugin_runtime.dart';

/// The crash this guards against, in full:
///
/// A plugin recursing without a base case used to smash the host thread's
/// stack, aborting the process. On Windows debug builds MSVC reports it as
/// "Run-Time Check Failure #2 - Stack around the variable 'S639' was
/// corrupted" inside quickjs_c_bridge_plugin.dll, with no Dart exception.
///
/// QuickJS's own `stackSize` guard is the only defence, and it only works if
/// it trips *before* the real thread stack runs out. A guard set at or above
/// the thread's stack size (the old 4MB, or the engine's 1MB default against
/// a 1MB thread) never fires. This test proves an unbounded plugin
/// recursion is contained and reported as a normal failure.
void main() {
  test(
    'runaway plugin recursion fails the call instead of killing the process',
    () async {
      final runtime = QuickJsPluginRuntime(
        httpClient: PluginHttpClient(),
        vendorSource: null,
      );
      addTearDown(runtime.dispose);

      final loaded = await runtime.loadPlugin('''
        module.exports = {
          platform: 'deep-recursion',
          // No base case: drives straight into the guard.
          search() { return recurse(0); }
        };
        function recurse(n) { return recurse(n + 1); }
      ''');
      expect(loaded, isA<Ok<Map<String, Object?>>>());

      // The decisive assertion is that this *returns at all*. Before the fix
      // the process died here; the test never got to run an expectation.
      final result = await runtime.callMethod(
        'search',
        const <Object?>[],
        timeout: const Duration(seconds: 30),
      );
      expect(result, isA<Failure<Object?>>());

      // And the engine survives, so one bad plugin does not poison the rest.
      final again = await runtime.callMethod(
        'search',
        const <Object?>[],
        timeout: const Duration(seconds: 30),
      );
      expect(again, isA<Failure<Object?>>());
    },
    skip: Platform.environment['RUN_PLUGIN_SPIKE'] != 'true',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
