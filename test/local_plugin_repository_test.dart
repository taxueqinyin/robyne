import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/database/app_database.dart' as db;
import 'package:robyne/core/result/result.dart';
import 'package:robyne/core/storage/local_file_store.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/domain/plugin_runtime.dart';
import 'package:robyne/features/plugin/infrastructure/local_plugin_repository.dart';
import 'package:robyne/features/plugin/infrastructure/music_free_compat_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

void main() {
  test('imports plugin from URL after metadata validation', () async {
    _setMockPreferences();
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_plugin_repo_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(
      server.forEach((request) async {
        request.response.headers.contentType = ContentType(
          'application',
          'javascript',
          charset: 'utf-8',
        );
        request.response.write(
          _pluginSource(
            platform: 'URL Plugin',
            version: '1.0.0',
            author: 'Robyne',
            supportedSearchType: const <Object?>['music'],
          ),
        );
        await request.response.close();
      }),
    );

    final repository = LocalPluginRepository(
      fileStore: LocalFileStore(baseDirectory: tempDirectory),
      preferences: SharedPreferencesAsync(),
      runtimeFactory: _FakeRuntimeFactory(),
      compatAdapter: MusicFreeCompatAdapter(),
    );

    final imported = await repository.importPluginFromUrl(
      'http://${server.address.host}:${server.port}/plugin.js',
    );
    expect(imported, isA<Ok>());
    final definition = (imported as Ok).value;
    expect(definition.platform, 'URL Plugin');
    expect(await File(definition.sourcePath).exists(), isTrue);

    final listed = await repository.listPlugins();
    final plugins = (listed as Ok).value;
    expect(plugins, hasLength(1));
    expect(plugins.single.platform, 'URL Plugin');
  });

  test('updates plugin user variable values', () async {
    _setMockPreferences();
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_plugin_repo_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(
      server.forEach((request) async {
        request.response.write(
          _pluginSource(
            platform: 'URL Plugin',
            version: '1.0.0',
            author: 'Robyne',
            userVariables: const <Object?>[
              <String, Object?>{'key': 'token', 'name': 'Token'},
            ],
          ),
        );
        await request.response.close();
      }),
    );

    final repository = LocalPluginRepository(
      fileStore: LocalFileStore(baseDirectory: tempDirectory),
      preferences: SharedPreferencesAsync(),
      runtimeFactory: _FakeRuntimeFactory(),
      compatAdapter: MusicFreeCompatAdapter(),
    );
    final imported = await repository.importPluginFromUrl(
      'http://${server.address.host}:${server.port}/plugin.js',
    );
    final definition = (imported as Ok).value;

    final updated = await repository.updateUserVariableValues(
      definition.id,
      <String, String>{'token': ' abc ', 'ignored': 'nope'},
    );
    final updatedDefinition = (updated as Ok).value;
    expect(updatedDefinition.userVariableValues, <String, String>{
      'token': 'abc',
    });

    final listed = await repository.listPlugins();
    final plugins = (listed as Ok).value;
    expect(plugins.single.userVariableValues, <String, String>{'token': 'abc'});
  });

  test('rejects non-http plugin URL', () async {
    _setMockPreferences();
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_plugin_repo_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });

    final repository = LocalPluginRepository(
      fileStore: LocalFileStore(baseDirectory: tempDirectory),
      preferences: SharedPreferencesAsync(),
      runtimeFactory: _FakeRuntimeFactory(),
      compatAdapter: MusicFreeCompatAdapter(),
    );

    final imported = await repository.importPluginFromUrl('file:///tmp/a.js');
    expect(imported, isA<Failure>());
    expect((imported as Failure).error.code, 'plugin.url_invalid');
  });

  test('a dragged order survives a read back from the database', () async {
    _setMockPreferences();
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_plugin_repo_test_',
    );
    final database = db.AppDatabase.memory();
    addTearDown(database.close);
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final files = <File>[
      for (var index = 0; index < 3; index += 1)
        File('${tempDirectory.path}/plugin$index.js'),
    ];
    for (var index = 0; index < files.length; index += 1) {
      await files[index].writeAsString(
        _pluginSource(
          platform: 'Source $index',
          author: 'Author $index',
          version: '1.0.0',
        ),
      );
    }

    final repository = LocalPluginRepository(
      fileStore: LocalFileStore(baseDirectory: tempDirectory),
      database: database,
      preferences: SharedPreferencesAsync(),
      runtimeFactory: _FakeRuntimeFactory(),
      compatAdapter: MusicFreeCompatAdapter(),
    );
    for (final file in files) {
      await repository.importPluginFromPath(file.path);
    }

    final installed = (await repository.listPlugins() as Ok).value;
    expect(
      installed.map((plugin) => plugin.platform).toList(),
      <String>['Source 0', 'Source 1', 'Source 2'],
    );

    final reordered = await repository.reorderPlugins(<String>[
      installed[2].id,
      installed[0].id,
      installed[1].id,
    ]);
    expect(reordered, isA<Ok>());

    // Read back through the repository rather than trusting the returned list:
    // the ranking has to be in storage, not only in the caller's memory.
    final reloaded = (await repository.listPlugins() as Ok).value;
    expect(
      reloaded.map((plugin) => plugin.platform).toList(),
      <String>['Source 2', 'Source 0', 'Source 1'],
    );
  });

  test('allows same platform with different authors to coexist', () async {
    _setMockPreferences();
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_plugin_repo_test_',
    );
    final database = db.AppDatabase.memory();
    addTearDown(database.close);
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final firstFile = File('${tempDirectory.path}/first.js');
    final secondFile = File('${tempDirectory.path}/second.js');
    await firstFile.writeAsString(
      _pluginSource(platform: 'Shared', author: 'Author A', version: '1.0.0'),
    );
    await secondFile.writeAsString(
      _pluginSource(platform: 'Shared', author: 'Author B', version: '1.0.0'),
    );

    final fileStore = LocalFileStore(baseDirectory: tempDirectory);
    final repository = LocalPluginRepository(
      fileStore: fileStore,
      database: database,
      preferences: SharedPreferencesAsync(),
      runtimeFactory: _FakeRuntimeFactory(),
      compatAdapter: MusicFreeCompatAdapter(),
    );

    final firstImport = await repository.importPluginFromPath(firstFile.path);
    final secondImport = await repository.importPluginFromPath(secondFile.path);
    final listed = await repository.listPlugins();

    expect(firstImport, isA<Ok>());
    expect(secondImport, isA<Ok>());
    expect((listed as Ok).value, hasLength(2));
  });

  test(
    'batch import updates higher version and skips same or lower versions',
    () async {
      _setMockPreferences();
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_plugin_repo_test_',
      );
      final database = db.AppDatabase.memory();
      addTearDown(database.close);
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final firstFile = File('${tempDirectory.path}/first.js');
      final higherFile = File('${tempDirectory.path}/higher.js');
      final lowerFile = File('${tempDirectory.path}/lower.js');
      await firstFile.writeAsString(
        _pluginSource(
          platform: 'Shared',
          author: 'Author A',
          version: '1.0.0',
          userVariables: const <Object?>[
            <String, Object?>{'key': 'token', 'name': 'Token'},
          ],
        ),
      );
      await higherFile.writeAsString(
        _pluginSource(
          platform: 'Shared',
          author: 'Author A',
          version: '1.1.0',
          userVariables: const <Object?>[
            <String, Object?>{'key': 'token', 'name': 'Token'},
          ],
        ),
      );
      await lowerFile.writeAsString(
        _pluginSource(
          platform: 'Shared',
          author: 'Author A',
          version: '1.0.0',
          userVariables: const <Object?>[
            <String, Object?>{'key': 'token', 'name': 'Token'},
          ],
        ),
      );

      final fileStore = LocalFileStore(baseDirectory: tempDirectory);
      final repository = LocalPluginRepository(
        fileStore: fileStore,
        database: database,
        preferences: SharedPreferencesAsync(),
        runtimeFactory: _FakeRuntimeFactory(),
        compatAdapter: MusicFreeCompatAdapter(),
      );

      final firstImport = await repository.importPluginFromPath(firstFile.path);
      final original = (firstImport as Ok<PluginDefinition>).value;
      await repository.setEnabled(original.id, false);
      await repository.updateUserVariableValues(
        original.id,
        const <String, String>{'token': 'abc'},
      );

      final result = await repository.importPluginsFromPaths(<String>[
        higherFile.path,
        lowerFile.path,
      ]);
      final listed = await repository.listPlugins();
      final plugin = ((listed as Ok<List<PluginDefinition>>).value).single;
      final pluginDirectory = await fileStore.pluginsDirectory();
      final copiedPlugins = await pluginDirectory
          .list()
          .where((entity) => entity is File)
          .toList();

      expect(result.importedCount, 0);
      expect(result.updatedCount, 1);
      expect(result.skippedCount, 1);
      expect(result.errors, isEmpty);
      expect(plugin.id, original.id);
      expect(plugin.version, '1.1.0');
      expect(plugin.enabled, isFalse);
      expect(plugin.userVariableValues, const <String, String>{'token': 'abc'});
      expect(plugin.sourcePath, isNot(original.sourcePath));
      expect(await File(original.sourcePath).exists(), isFalse);
      expect(copiedPlugins, hasLength(1));
    },
  );
}

String _pluginSource({
  required String platform,
  String? version,
  String? author,
  List<Object?> supportedSearchType = const <Object?>['music'],
  List<Object?> userVariables = const <Object?>[],
}) {
  return jsonEncode(<String, Object?>{
    'platform': platform,
    'version': version,
    'author': author,
    'supportedSearchType': supportedSearchType,
    'userVariables': userVariables,
  });
}

void _setMockPreferences() {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  SharedPreferencesAsyncPlatform.instance = _MemoryPreferencesPlatform();
}

class _FakeRuntimeFactory extends PluginRuntimeFactory {
  @override
  Future<PluginRuntime> create() async => _FakeRuntime();
}

class _FakeRuntime implements PluginRuntime {
  @override
  Future<Result<Map<String, Object?>>> loadPlugin(
    String source, {
    Map<String, String> userVariables = const <String, String>{},
  }) async {
    final decoded = jsonDecode(source);
    return Ok(
      (decoded as Map<dynamic, dynamic>).map(
        (key, dynamic value) => MapEntry(key.toString(), value as Object?),
      ),
    );
  }

  @override
  Future<Result<Object?>> callMethod(
    String method,
    List<Object?> arguments, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> dispose() async {}
}

final class _MemoryPreferencesPlatform extends SharedPreferencesAsyncPlatform {
  final Map<String, Object> _values = <String, Object>{};

  @override
  Future<void> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    _values[key] = value;
  }

  @override
  Future<String?> getString(
    String key,
    SharedPreferencesOptions options,
  ) async {
    final value = _values[key];
    return value is String ? value : null;
  }

  @override
  Future<Map<String, Object>> getPreferences(
    GetPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    final allowList = parameters.filter.allowList;
    return Map<String, Object>.fromEntries(
      _values.entries.where(
        (entry) => allowList == null || allowList.contains(entry.key),
      ),
    );
  }

  @override
  Future<Set<String>> getKeys(
    GetPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    final allowList = parameters.filter.allowList;
    return _values.keys
        .where((key) => allowList == null || allowList.contains(key))
        .toSet();
  }

  @override
  Future<void> clear(
    ClearPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    final allowList = parameters.filter.allowList;
    if (allowList == null) {
      _values.clear();
      return;
    }
    for (final key in allowList) {
      _values.remove(key);
    }
  }

  @override
  Future<void> setBool(
    String key,
    bool value,
    SharedPreferencesOptions options,
  ) async {
    _values[key] = value;
  }

  @override
  Future<bool?> getBool(String key, SharedPreferencesOptions options) async {
    final value = _values[key];
    return value is bool ? value : null;
  }

  @override
  Future<void> setDouble(
    String key,
    double value,
    SharedPreferencesOptions options,
  ) async {
    _values[key] = value;
  }

  @override
  Future<double?> getDouble(
    String key,
    SharedPreferencesOptions options,
  ) async {
    final value = _values[key];
    return value is double ? value : null;
  }

  @override
  Future<void> setInt(
    String key,
    int value,
    SharedPreferencesOptions options,
  ) async {
    _values[key] = value;
  }

  @override
  Future<int?> getInt(String key, SharedPreferencesOptions options) async {
    final value = _values[key];
    return value is int ? value : null;
  }

  @override
  Future<void> setStringList(
    String key,
    List<String> value,
    SharedPreferencesOptions options,
  ) async {
    _values[key] = value;
  }

  @override
  Future<List<String>?> getStringList(
    String key,
    SharedPreferencesOptions options,
  ) async {
    final value = _values[key];
    return value is List<String> ? value : null;
  }
}
