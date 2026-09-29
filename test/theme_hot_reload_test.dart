import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/application/theme_hot_reload.dart';

/// Covers the authoring workflow the roadmap chose over an in-app editor:
/// edit `theme.json`, the app notices, and the active skin reloads.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('robyne_hot_reload_');
  });

  tearDown(() async {
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  });

  test('a manifest write triggers exactly one debounced reload', () async {
    var reloads = 0;
    final service = ThemeHotReloadService(
      debounce: const Duration(milliseconds: 60),
      watchRoot: root,
      onReload: () async => reloads += 1,
    );
    await service.start();
    addTearDown(service.dispose);

    // Simulate an editor that writes, truncates, and renames in quick
    // succession: one quiet period, one reload.
    final manifest = File('${root.path}/theme.json');
    await manifest.writeAsString('{"id":"a"}');
    await Future<void>.delayed(const Duration(milliseconds: 15));
    await manifest.writeAsString('{"id":"b"}');
    await Future<void>.delayed(const Duration(milliseconds: 15));
    await manifest.writeAsString('{"id":"c"}');

    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(reloads, 1);
  });

  test('asset edits also trigger a reload', () async {
    var reloads = 0;
    final service = ThemeHotReloadService(
      debounce: const Duration(milliseconds: 40),
      watchRoot: root,
      onReload: () async => reloads += 1,
    );
    await service.start();
    addTearDown(service.dispose);

    await File('${root.path}/cover.png').writeAsBytes(<int>[1, 2, 3]);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(reloads, 1);
  });

  test('editor scratch files are ignored', () async {
    var reloads = 0;
    final service = ThemeHotReloadService(
      debounce: const Duration(milliseconds: 40),
      watchRoot: root,
      onReload: () async => reloads += 1,
    );
    await service.start();
    addTearDown(service.dispose);

    await File('${root.path}/.theme.json.swp').writeAsString('scratch');
    await File('${root.path}/theme.json~').writeAsString('backup');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(reloads, 0);
  });
}
