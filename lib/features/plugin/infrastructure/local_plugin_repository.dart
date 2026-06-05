import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/database/legacy_storage_migration.dart';
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
    required SharedPreferencesAsync? preferences,
    db.AppDatabase? database,
    LegacyStorageMigration? legacyMigration,
    required PluginRuntimeFactory runtimeFactory,
    required MusicFreeCompatAdapter compatAdapter,
    Dio? dio,
  }) : _fileStore = fileStore,
       _database = database ?? db.AppDatabase.memory(),
       _legacyMigration = legacyMigration,
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

  static const _maxPluginBytes = 2 * 1024 * 1024;

  final LocalFileStore _fileStore;
  final db.AppDatabase _database;
  final LegacyStorageMigration? _legacyMigration;
  final PluginRuntimeFactory _runtimeFactory;
  final MusicFreeCompatAdapter _compatAdapter;
  final Dio _dio;

  @override
  Future<Result<List<PluginDefinition>>> listPlugins() async {
    try {
      await _legacyMigration?.ensureMigrated();
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
      await _legacyMigration?.ensureMigrated();
      final existing = await _definitionById(id);
      if (existing == null) {
        return const Failure(
          AppError(code: 'plugin.not_found', message: 'Plugin was not found.'),
        );
      }

      final updated = existing.copyWith(
        enabled: enabled,
        updatedAt: DateTime.now(),
      );
      await _upsertDefinition(updated);
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
      await _legacyMigration?.ensureMigrated();
      final existing = await _definitionById(id);
      if (existing == null) {
        return const Failure(
          AppError(code: 'plugin.not_found', message: 'Plugin was not found.'),
        );
      }

      final allowedKeys = existing.userVariables
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
      final updated = existing.copyWith(
        userVariableValues: sanitized,
        updatedAt: DateTime.now(),
      );
      await _upsertDefinition(updated);
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
      await _legacyMigration?.ensureMigrated();
      final removed = await _definitionById(id);
      if (removed == null) {
        return const Failure(
          AppError(code: 'plugin.not_found', message: 'Plugin was not found.'),
        );
      }

      final file = File(removed.sourcePath);
      if (await file.exists()) {
        await file.delete();
      }
      await (_database.delete(
        _database.pluginDefinitionRows,
      )..where((row) => row.id.equals(id))).go();
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
    final rows =
        await (_database.select(_database.pluginDefinitionRows)
              ..orderBy(<OrderingTerm Function(db.$PluginDefinitionRowsTable)>[
                (row) => OrderingTerm.asc(row.installedAt),
              ]))
            .get();
    return rows.map(_definitionFromRow).toList(growable: false);
  }

  Future<PluginDefinition?> _definitionById(String id) async {
    final row = await (_database.select(
      _database.pluginDefinitionRows,
    )..where((plugin) => plugin.id.equals(id))).getSingleOrNull();
    return row == null ? null : _definitionFromRow(row);
  }

  Future<PluginDefinition?> _definitionByPlatform(String platform) async {
    final normalized = platform.trim().toLowerCase();
    final rows = await _database.select(_database.pluginDefinitionRows).get();
    for (final row in rows) {
      if (row.platform.trim().toLowerCase() == normalized) {
        return _definitionFromRow(row);
      }
    }
    return null;
  }

  Future<void> _upsertDefinition(PluginDefinition definition) async {
    await _database
        .into(_database.pluginDefinitionRows)
        .insert(
          _definitionCompanion(definition),
          mode: InsertMode.insertOrReplace,
        );
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
      await _legacyMigration?.ensureMigrated();
      final platform = metadata['platform']?.toString().trim();
      if (platform != null && platform.isNotEmpty) {
        final duplicate = await _definitionByPlatform(platform);
        if (duplicate != null) {
          return Failure(
            AppError(
              code: 'plugin.duplicate',
              message: 'Plugin "${duplicate.platform}" is already imported.',
            ),
          );
        }
      }

      final pluginDirectory = await _fileStore.pluginsDirectory();
      final destination = File(
        p.join(
          pluginDirectory.path,
          '${DateTime.now().microsecondsSinceEpoch}_${_safeFileName(fileName)}',
        ),
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
      await _upsertDefinition(definition);

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

  static PluginDefinition _definitionFromRow(db.PluginDefinitionRow row) {
    return PluginDefinition(
      id: row.id,
      platform: row.platform,
      version: row.version,
      author: row.author,
      description: row.description,
      sourcePath: row.sourcePath,
      enabled: row.enabled,
      installedAt: row.installedAt,
      updatedAt: row.updatedAt,
      supportedSearchTypes: _stringList(row.supportedSearchTypesJson),
      userVariables: _mapList(row.userVariablesJson),
      userVariableValues: _stringMap(row.userVariableValuesJson),
    );
  }

  static db.PluginDefinitionRowsCompanion _definitionCompanion(
    PluginDefinition definition,
  ) {
    return db.PluginDefinitionRowsCompanion(
      id: Value(definition.id),
      platform: Value(definition.platform),
      version: Value(definition.version),
      author: Value(definition.author),
      description: Value(definition.description),
      sourcePath: Value(definition.sourcePath),
      enabled: Value(definition.enabled),
      installedAt: Value(definition.installedAt),
      updatedAt: Value(definition.updatedAt),
      supportedSearchTypesJson: Value(
        jsonEncode(definition.supportedSearchTypes),
      ),
      userVariablesJson: Value(jsonEncode(definition.userVariables)),
      userVariableValuesJson: Value(jsonEncode(definition.userVariableValues)),
    );
  }

  static List<String> _stringList(String rawJson) {
    final decoded = _json(rawJson);
    if (decoded is! List) {
      return const <String>[];
    }
    return decoded.map((value) => value.toString()).toList(growable: false);
  }

  static List<Map<String, Object?>> _mapList(String rawJson) {
    final decoded = _json(rawJson);
    if (decoded is! List) {
      return const <Map<String, Object?>>[];
    }
    return decoded
        .whereType<Map>()
        .map((value) {
          return value.map(
            (key, dynamic mapValue) =>
                MapEntry(key.toString(), mapValue as Object?),
          );
        })
        .toList(growable: false);
  }

  static Map<String, String> _stringMap(String rawJson) {
    final decoded = _json(rawJson);
    if (decoded is! Map) {
      return const <String, String>{};
    }
    return decoded.map(
      (key, dynamic value) => MapEntry(key.toString(), value.toString()),
    );
  }

  static Object? _json(String rawJson) {
    try {
      return jsonDecode(rawJson);
    } catch (_) {
      return null;
    }
  }
}
