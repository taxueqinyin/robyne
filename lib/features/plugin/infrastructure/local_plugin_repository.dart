import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/result/result.dart';
import '../../../core/storage/local_file_store.dart';
import '../domain/plugin_definition.dart';
import '../domain/plugin_repository.dart';
import '../domain/plugin_runtime.dart';
import 'music_free_compat_adapter.dart';

class LocalPluginRepository implements PluginRepository {
  LocalPluginRepository({
    required LocalFileStore fileStore,
    required SharedPreferencesAsync preferences,
    required PluginRuntimeFactory runtimeFactory,
    required MusicFreeCompatAdapter compatAdapter,
    Dio? dio,
  }) : _fileStore = fileStore,
       _preferences = preferences,
       _runtimeFactory = runtimeFactory,
       _compatAdapter = compatAdapter,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 20),
               receiveTimeout: const Duration(seconds: 30),
             ),
           );

  static const _storageKey = 'plugins.v1';
  static const _maxPluginBytes = 2 * 1024 * 1024;

  final LocalFileStore _fileStore;
  final SharedPreferencesAsync _preferences;
  final PluginRuntimeFactory _runtimeFactory;
  final MusicFreeCompatAdapter _compatAdapter;
  final Dio _dio;

  @override
  Future<Result<List<PluginDefinition>>> listPlugins() async {
    try {
      return Ok(await _readDefinitions());
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'storage.read_failed',
          message: 'Failed to read installed plugins.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<PluginDefinition>> importPluginFromPath(String path) async {
    try {
      final source = await File(path).readAsString();
      final sourceFile = File(path);
      return await _importPluginSource(
        source: source,
        fileName: sourceFile.uri.pathSegments.last,
        importLabel: path,
      );
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'plugin.load_failed',
          message: 'Failed to import plugin from $path.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<PluginDefinition>> importPluginFromUrl(String url) async {
    try {
      final uri = Uri.tryParse(url.trim());
      if (uri == null || !uri.hasAbsolutePath) {
        return const Failure(
          AppError(
            code: 'plugin.url_invalid',
            message: 'Enter a valid plugin URL.',
          ),
        );
      }
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return const Failure(
          AppError(
            code: 'plugin.url_invalid',
            message: 'Plugin URL must start with http:// or https://.',
          ),
        );
      }

      final response = await _dio.get<Object?>(
        uri.toString(),
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );
      final statusCode = response.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        return Failure(
          AppError(
            code: 'plugin.download_failed',
            message: 'Plugin download failed with HTTP $statusCode.',
          ),
        );
      }

      final rawData = response.data;
      if (rawData is! String || rawData.trim().isEmpty) {
        return const Failure(
          AppError(
            code: 'plugin.download_failed',
            message: 'Plugin URL did not return a JavaScript text response.',
          ),
        );
      }
      final sourceBytes = utf8.encode(rawData).length;
      if (sourceBytes > _maxPluginBytes) {
        return const Failure(
          AppError(
            code: 'plugin.download_too_large',
            message: 'Plugin file is too large.',
          ),
        );
      }

      return await _importPluginSource(
        source: rawData,
        fileName: _fileNameFromUri(uri),
        importLabel: uri.toString(),
      );
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'plugin.download_failed',
          message: 'Failed to download plugin from $url.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<PluginDefinition>> setEnabled(String id, bool enabled) async {
    try {
      final definitions = await _readDefinitions();
      final index = definitions.indexWhere((plugin) => plugin.id == id);
      if (index == -1) {
        return const Failure(
          AppError(code: 'plugin.not_found', message: 'Plugin was not found.'),
        );
      }

      final updated = definitions[index].copyWith(
        enabled: enabled,
        updatedAt: DateTime.now(),
      );
      definitions[index] = updated;
      await _writeDefinitions(definitions);
      return Ok(updated);
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'storage.write_failed',
          message: 'Failed to update plugin status.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<PluginDefinition>> updateUserVariableValues(
    String id,
    Map<String, String> values,
  ) async {
    try {
      final definitions = await _readDefinitions();
      final index = definitions.indexWhere((plugin) => plugin.id == id);
      if (index == -1) {
        return const Failure(
          AppError(code: 'plugin.not_found', message: 'Plugin was not found.'),
        );
      }

      final allowedKeys = definitions[index].userVariables
          .map((variable) => variable['key']?.toString())
          .whereType<String>()
          .toSet();
      final sanitized = Map<String, String>.fromEntries(
        values.entries
            .where(
              (entry) => allowedKeys.isEmpty || allowedKeys.contains(entry.key),
            )
            .map((entry) => MapEntry(entry.key, entry.value.trim())),
      );
      final updated = definitions[index].copyWith(
        userVariableValues: sanitized,
        updatedAt: DateTime.now(),
      );
      definitions[index] = updated;
      await _writeDefinitions(definitions);
      return Ok(updated);
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'storage.write_failed',
          message: 'Failed to update plugin user variables.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> deletePlugin(String id) async {
    try {
      final definitions = await _readDefinitions();
      final index = definitions.indexWhere((plugin) => plugin.id == id);
      if (index == -1) {
        return const Failure(
          AppError(code: 'plugin.not_found', message: 'Plugin was not found.'),
        );
      }

      final removed = definitions.removeAt(index);
      final file = File(removed.sourcePath);
      if (await file.exists()) {
        await file.delete();
      }
      await _writeDefinitions(definitions);
      return const Ok(null);
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'storage.write_failed',
          message: 'Failed to delete plugin.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<List<PluginDefinition>> _readDefinitions() async {
    final raw = await _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return <PluginDefinition>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <PluginDefinition>[];
    }

    return decoded
        .whereType<Map<String, Object?>>()
        .map(PluginDefinition.fromJson)
        .toList();
  }

  Future<void> _writeDefinitions(List<PluginDefinition> definitions) async {
    final raw = jsonEncode(
      definitions.map((definition) => definition.toJson()).toList(),
    );
    await _preferences.setString(_storageKey, raw);
  }

  Future<Result<PluginDefinition>> _importPluginSource({
    required String source,
    required String fileName,
    required String importLabel,
  }) async {
    PluginRuntime? runtime;
    try {
      runtime = await _runtimeFactory.create();
      final metadataResult = await runtime.loadPlugin(source);
      if (metadataResult case Failure<Map<String, Object?>>(:final error)) {
        return Failure(error);
      }

      final metadata = (metadataResult as Ok<Map<String, Object?>>).value;
      final pluginDirectory = await _fileStore.pluginsDirectory();
      final destination = File(
        '${pluginDirectory.path}/${DateTime.now().microsecondsSinceEpoch}_${_safeFileName(fileName)}',
      );
      await destination.writeAsString(source);

      final definitionResult = _compatAdapter.definitionFromRuntimeMetadata(
        sourcePath: destination.path,
        metadata: metadata,
      );
      if (definitionResult case Failure<PluginDefinition>(:final error)) {
        if (await destination.exists()) {
          await destination.delete();
        }
        return Failure(error);
      }

      final definition = (definitionResult as Ok<PluginDefinition>).value;
      final definitions = await _readDefinitions();
      definitions.removeWhere((plugin) => plugin.id == definition.id);
      definitions.add(definition);
      await _writeDefinitions(definitions);

      return Ok(definition);
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'plugin.load_failed',
          message: 'Failed to import plugin from $importLabel.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      await runtime?.dispose();
    }
  }

  static String _fileNameFromUri(Uri uri) {
    final lastSegment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    if (lastSegment.toLowerCase().endsWith('.js')) {
      return lastSegment;
    }
    return 'plugin.js';
  }

  static String _safeFileName(String fileName) {
    final normalized = fileName.trim().isEmpty ? 'plugin.js' : fileName.trim();
    return normalized.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }
}
