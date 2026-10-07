import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/database/app_database.dart' as db;
import 'package:robyne/core/result/result.dart';
import 'package:robyne/core/storage/local_file_store.dart';
import 'package:robyne/features/plugin/domain/plugin_repository.dart';
import 'package:robyne/features/plugin/domain/plugin_runtime.dart';
import 'package:robyne/features/plugin/infrastructure/local_plugin_repository.dart';
import 'package:robyne/features/plugin/infrastructure/music_free_compat_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

void main() {
  test('partial list failure still reports every plugin that landed', () async {
    _setMockPreferences();
    final harness = await _Harness.start(
      manifest: jsonEncode(<String, Object?>{
        'plugins': <Object?>[
          <String, Object?>{'name': 'A', 'url': '/a.js'},
          <String, Object?>{'name': 'B', 'url': '/missing.js'},
          <String, Object?>{'name': 'C', 'url': '/c.js'},
        ],
      }),
      sources: <String, String>{
        '/a.js': _pluginSource(platform: 'Kuwo', version: '1.0.0'),
        '/c.js': _pluginSource(platform: 'Kugou', version: '1.0.0'),
      },
    );
    addTearDown(harness.close);

    final result = await harness.repository.importPluginBatchFromUrl(
      '${harness.baseUrl}/plugins.json',
    );

    // The bug: this used to be a Failure, so the UI discarded the successes.
    expect(result.successCount, 2);
    expect(result.importedCount, 2);
    expect(result.errors, hasLength(1));
    expect(result.errors.first.code, 'plugin.download_failed');

    final plugins = (await harness.repository.listPlugins() as Ok).value;
    expect(plugins, hasLength(2));
  });

  test('all-failing list reports zero successes', () async {
    _setMockPreferences();
    final harness = await _Harness.start(
      manifest: '{"plugins": [{"url": "/missing.js"}]}',
      sources: const <String, String>{},
    );
    addTearDown(harness.close);

    final result = await harness.repository.importPluginBatchFromUrl(
      '${harness.baseUrl}/plugins.json',
    );
    expect(result.successCount, 0);
    expect(result.errors, hasLength(1));
  });

  test('single plugin URL still yields a one-item batch', () async {
    _setMockPreferences();
    final harness = await _Harness.start(
      manifest: _pluginSource(platform: 'Solo', version: '1.0.0'),
      sources: const <String, String>{},
    );
    addTearDown(harness.close);

    final result = await harness.repository.importPluginBatchFromUrl(
      '${harness.baseUrl}/plugins.json',
    );
    expect(result.importedCount, 1);
    expect(result.errors, isEmpty);
  });

  test('already-installed plugin reports as skipped', () async {
    _setMockPreferences();
    final harness = await _Harness.start(
      manifest: jsonEncode(<String, Object?>{
        'plugins': <Object?>[
          <String, Object?>{'url': '/a.js'},
        ],
      }),
      sources: <String, String>{
        '/a.js': _pluginSource(platform: 'Kuwo', version: '1.0.0'),
      },
    );
    addTearDown(harness.close);

    await harness.repository.importPluginBatchFromUrl(
      '${harness.baseUrl}/plugins.json',
    );
    final second = await harness.repository.importPluginBatchFromUrl(
      '${harness.baseUrl}/plugins.json',
    );
    expect(second.importedCount, 0);
    expect(second.skippedCount, 1);
    expect(second.errors, isEmpty);
  });

  test('invalid URL surfaces one error with no successes', () async {
    _setMockPreferences();
    final harness = await _Harness.start(
      manifest: '{"plugins": []}',
      sources: const <String, String>{},
    );
    addTearDown(harness.close);

    final result = await harness.repository.importPluginBatchFromUrl(
      'file:///etc/passwd',
    );
    expect(result.successCount, 0);
    expect(result.errors.single.code, 'plugin.url_invalid');
  });

  test('progress is reported as entries complete', () async {
    _setMockPreferences();
    final harness = await _Harness.start(
      manifest: jsonEncode(<String, Object?>{
        'plugins': <Object?>[
          <String, Object?>{'name': 'A', 'url': '/a.js'},
          <String, Object?>{'name': 'C', 'url': '/c.js'},
        ],
      }),
      sources: <String, String>{
        '/a.js': _pluginSource(platform: 'Kuwo', version: '1.0.0'),
        '/c.js': _pluginSource(platform: 'Kugou', version: '1.0.0'),
      },
    );
    addTearDown(harness.close);

    final snapshots = <PluginImportProgressSnapshot>[];
    await harness.repository.importPluginBatchFromUrl(
      '${harness.baseUrl}/plugins.json',
      onProgress: snapshots.add,
    );

    expect(snapshots, isNotEmpty);
    expect(snapshots.last.total, 2);
    expect(snapshots.last.completed, 2);
    expect(snapshots.last.importedCount, 2);
  });
}

class _Harness {
  _Harness._({
    required this.repository,
    required this.baseUrl,
    required HttpServer server,
    required Directory directory,
    required db.AppDatabase database,
  }) : _server = server,
       _directory = directory,
       _database = database;

  static Future<_Harness> start({
    required String manifest,
    required Map<String, String> sources,
  }) async {
    final directory = await Directory.systemTemp.createTemp(
      'robyne_url_batch_test_',
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      server.forEach((request) async {
        final path = request.uri.path;
        if (path == '/plugins.json') {
          request.response.headers.contentType = ContentType(
            'application',
            'json',
            charset: 'utf-8',
          );
          request.response.write(manifest);
        } else {
          final source = sources[path];
          if (source == null) {
            request.response.statusCode = HttpStatus.notFound;
          } else {
            request.response.headers.contentType = ContentType(
              'application',
              'javascript',
              charset: 'utf-8',
            );
            request.response.write(source);
          }
        }
        await request.response.close();
      }),
    );

    final database = db.AppDatabase.memory();
    final repository = LocalPluginRepository(
      fileStore: LocalFileStore(baseDirectory: directory),
      database: database,
      preferences: SharedPreferencesAsync(),
      runtimeFactory: _FakeRuntimeFactory(),
      compatAdapter: MusicFreeCompatAdapter(),
    );
    return _Harness._(
      repository: repository,
      baseUrl: 'http://${server.address.host}:${server.port}',
      server: server,
      directory: directory,
      database: database,
    );
  }

  final LocalPluginRepository repository;
  final String baseUrl;
  final HttpServer _server;
  final Directory _directory;
  final db.AppDatabase _database;

  Future<void> close() async {
    await _server.close();
    await _database.close();
    await _directory.delete(recursive: true);
  }
}

String _pluginSource({required String platform, String? version}) {
  return jsonEncode(<String, Object?>{
    'platform': platform,
    'version': version,
    'supportedSearchType': <Object?>['music'],
    'userVariables': <Object?>[],
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
