import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/infrastructure/quickjs_plugin_runtime.dart';

/// Guards the rule that fixed the app-killing crash.
///
/// Playback, lyrics and downloads used to build a `QuickJsPluginRuntime` on
/// the UI isolate. A native engine there shares Flutter's thread and address
/// space, so a plugin that faults aborts the process with no Dart error —
/// which is why the app vanished mid-search. Every plugin call must now run
/// through an isolate.
void main() {
  test('every QuickJS entry point runs inside an isolate', () {
    final source = File(
      'lib/features/plugin/infrastructure/quickjs_plugin_runtime.dart',
    ).readAsStringSync();

    // The only sanctioned way to build a runtime is from an isolate body.
    final constructions = RegExp(
      r'QuickJsPluginRuntime\(',
    ).allMatches(source).length;
    // One declaration, plus one construction per isolate entry point.
    expect(
      constructions,
      greaterThanOrEqualTo(4),
      reason: 'runtime construction should remain confined to isolate bodies',
    );

    // No feature outside this file may build a runtime directly.
    for (final path in <String>[
      'lib/features/player/application/player_providers.dart',
      'lib/features/lyrics/application/lyrics_providers.dart',
      'lib/features/downloads/application/download_providers.dart',
    ]) {
      final feature = File(path).readAsStringSync();
      expect(
        feature.contains('QuickJsPluginRuntime('),
        isFalse,
        reason: '$path must not build a JS runtime on the main isolate',
      );
      expect(
        feature.contains('runtimeFactory.create()'),
        isFalse,
        reason: '$path must not create a runtime on the main isolate',
      );
    }
  });

  test('the runtime widens the recursion guard before the OS stack is hit', () {
    final source = File(
      'lib/features/plugin/infrastructure/quickjs_plugin_runtime.dart',
    ).readAsStringSync();
    // QuickJS's own guard must trip (as a catchable JS RangeError) before a
    // runaway plugin reaches the real thread stack and aborts the process.
    expect(source.contains('_stackLimitBytes'), isTrue);
    // `memoryLimit` is intentionally absent: this build's native bridge does
    // not export jsSetMemoryLimit, and requesting it breaks every call.
    expect(source.contains('memoryLimit:'), isFalse);
  });

  test('isolated method runner reports a plugin failure, not a crash', () async {
    final runner = QuickJsIsolateMethodRunner(
      vendorSourceLoader: () async => null,
    );
    final plugin = PluginDefinition(
      id: 'p1',
      platform: 'P1',
      sourcePath: 'p1.js',
      enabled: true,
      installedAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    final result = await runner.call(
      plugin: plugin,
      source: 'module.exports = { platform: "P1" };',
      method: 'getMediaSource',
      arguments: const <Object?>[],
    );

    // A missing method must come back as a failure the UI can render.
    expect(result.isFailure, isTrue);
    result.fold<void>(
      (_) => fail('expected a failure for a missing method'),
      // The precise code matters: it is what the UI renders, and a generic
      // isolate error would mean the failure was swallowed on the way out.
      (error) => expect(error.code, 'plugin.method_not_found'),
    );
  },
    skip: Platform.environment['RUN_PLUGIN_SPIKE'] != 'true',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
