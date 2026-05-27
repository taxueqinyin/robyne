import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/plugin/application/plugin_providers.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/domain/plugin_runtime.dart';
import 'package:robyne/features/search/application/search_controller.dart';

void main() {
  test('searches all enabled plugins and keeps per-plugin results', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_search_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final pluginAPath = await _writePluginFile(tempDirectory, 'plugin-a.js');
    final pluginBPath = await _writePluginFile(tempDirectory, 'plugin-b.js');
    final disabledPath = await _writePluginFile(
      tempDirectory,
      'plugin-disabled.js',
    );

    final runtimeFactory = _FakePluginRuntimeFactory();
    final container = ProviderContainer(
      overrides: [
        pluginRuntimeFactoryProvider.overrideWithValue(runtimeFactory),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(searchControllerProvider.notifier);
    notifier.updateKeyword('周杰伦');

    await notifier.search(<PluginDefinition>[
      _plugin('plugin-a', 'Source A', pluginAPath),
      _plugin('plugin-b', 'Source B', pluginBPath),
      _plugin('plugin-disabled', 'Disabled', disabledPath, enabled: false),
    ]);

    final state = container.read(searchControllerProvider).value!;
    expect(state.isSearching, isFalse);
    expect(state.pluginResults, hasLength(2));
    expect(state.pluginResults.map((result) => result.platform), <String>[
      'Source A',
      'Source B',
    ]);
    expect(
      state.pluginResults.first.result?.items.single.title,
      'Source A 周杰伦 page 1',
    );
    expect(runtimeFactory.searches, <String>['Source A:1', 'Source B:1']);

    notifier.selectPlugin('plugin-b');
    final selected = container.read(searchControllerProvider).value!;
    expect(selected.selectedPluginResult?.platform, 'Source B');
  });

  test(
    'loadMoreSelected appends the next page for the selected plugin',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_search_test_',
      );
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final pluginAPath = await _writePluginFile(tempDirectory, 'plugin-a.js');
      final pluginBPath = await _writePluginFile(tempDirectory, 'plugin-b.js');
      final runtimeFactory = _FakePluginRuntimeFactory();

      final container = ProviderContainer(
        overrides: [
          pluginRuntimeFactoryProvider.overrideWithValue(runtimeFactory),
        ],
      );
      addTearDown(container.dispose);

      final plugins = <PluginDefinition>[
        _plugin('plugin-a', 'Source A', pluginAPath),
        _plugin('plugin-b', 'Source B', pluginBPath),
      ];
      final notifier = container.read(searchControllerProvider.notifier);
      notifier.updateKeyword('周杰伦');

      await notifier.search(plugins);
      notifier.selectPlugin('plugin-a');
      await notifier.loadMoreSelected(plugins);

      final state = container.read(searchControllerProvider).value!;
      final selected = state.selectedPluginResult!;
      expect(selected.isLoadingMore, isFalse);
      expect(selected.error, isNull);
      expect(selected.result?.page, 2);
      expect(selected.result?.isEnd, isTrue);
      expect(selected.result?.items.map((item) => item.title), <String>[
        'Source A 周杰伦 page 1',
        'Source A 周杰伦 page 2',
      ]);
      expect(runtimeFactory.searches, contains('Source A:2'));
      expect(
        runtimeFactory.searches.where((entry) => entry == 'Source B:2'),
        isEmpty,
      );
    },
  );
}

Future<String> _writePluginFile(Directory directory, String name) async {
  final file = File('${directory.path}/$name');
  await file.writeAsString('// $name');
  return file.path;
}

PluginDefinition _plugin(
  String id,
  String platform,
  String sourcePath, {
  bool enabled = true,
}) {
  return PluginDefinition(
    id: id,
    platform: platform,
    sourcePath: sourcePath,
    enabled: enabled,
    installedAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class _FakePluginRuntimeFactory implements PluginRuntimeFactory {
  final List<String> searches = <String>[];

  @override
  Future<PluginRuntime> create() async {
    return _FakePluginRuntime(searches);
  }
}

class _FakePluginRuntime implements PluginRuntime {
  _FakePluginRuntime(this._searches);

  final List<String> _searches;
  String _platform = 'unknown';

  @override
  Future<Result<Map<String, Object?>>> loadPlugin(
    String source, {
    Map<String, String> userVariables = const <String, String>{},
  }) async {
    final path = source.replaceAll(r'\', '/');
    _platform = path.contains('plugin-a') ? 'Source A' : 'Source B';
    return Ok(<String, Object?>{'platform': _platform});
  }

  @override
  Future<Result<Object?>> callMethod(
    String method,
    List<Object?> arguments, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final page = arguments[1] as int;
    _searches.add('$_platform:$page');
    return Ok(<String, Object?>{
      'page': page,
      'isEnd': page >= 2,
      'data': <Object?>[
        <String, Object?>{
          'id': '$_platform-$page',
          'title': '$_platform ${arguments.first} page $page',
        },
      ],
    });
  }

  @override
  Future<void> dispose() async {}
}
