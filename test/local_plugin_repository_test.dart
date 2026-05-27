import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/core/storage/local_file_store.dart';
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
        request.response.write('''
          module.exports = {
            platform: 'URL Plugin',
            version: '1.0.0',
            author: 'Robyne',
            supportedSearchType: ['music']
          };
        ''');
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
        request.response.write('module.exports = {};');
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
}

void _setMockPreferences() {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  SharedPreferencesAsyncPlatform.instance = _MemoryPreferencesPlatform();
}

class _FakeRuntimeFactory implements PluginRuntimeFactory {
  @override
  Future<PluginRuntime> create() async => _FakeRuntime();
}

class _FakeRuntime implements PluginRuntime {
  @override
  Future<Result<Map<String, Object?>>> loadPlugin(
    String source, {
    Map<String, String> userVariables = const <String, String>{},
  }) async {
    return Ok(<String, Object?>{
      'platform': 'URL Plugin',
      'version': '1.0.0',
      'author': 'Robyne',
      'supportedSearchType': <Object?>['music'],
      'userVariables': <Object?>[
        <String, Object?>{'key': 'token', 'name': 'Token'},
      ],
    });
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
