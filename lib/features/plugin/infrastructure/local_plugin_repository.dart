import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
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
      // Surface the root cause: the UI only renders the wrapper message.
      debugPrint('listPlugins failed: $error\n$stackTrace');
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
    final requestResult = await _pluginRequestFromPath(path);
    if (requestResult case Failure<_PluginImportRequest>(:final error)) {
      return Failure(error);
    }
    return _importSingleRequest(
      (requestResult as Ok<_PluginImportRequest>).value,
    );
  }

  @override
  Future<PluginImportBatchResult> importPluginsFromPaths(
    List<String> paths, {
    PluginImportProgressCallback? onProgress,
  }) async {
    var stagedImportedCount = 0;
    var stagedUpdatedCount = 0;
    var skippedCount = 0;
    final errors = <AppError>[];
    final plannedImports = <_PlannedPluginImport>[];

    void emitProgress({required int completed, String? currentLabel}) {
      onProgress?.call(
        PluginImportProgressSnapshot(
          total: paths.length,
          completed: completed,
          importedCount: stagedImportedCount,
          updatedCount: stagedUpdatedCount,
          skippedCount: skippedCount,
          failedCount: errors.length,
          currentLabel: currentLabel,
        ),
      );
    }

    emitProgress(completed: 0);
    if (paths.isEmpty) {
      return const PluginImportBatchResult(
        importedCount: 0,
        updatedCount: 0,
        skippedCount: 0,
        errors: <AppError>[],
      );
    }

    try {
      await _legacyMigration?.ensureMigrated();
      final installed = await _readDefinitions();
      final currentByIdentity = <String, PluginDefinition>{
        for (final definition in installed)
          _identityKeyForDefinition(definition): definition,
      };
      final pluginDirectory = await _fileStore.pluginsDirectory();

      for (var index = 0; index < paths.length; index += 1) {
        final path = paths[index];
        emitProgress(completed: index, currentLabel: path);

        final requestResult = await _pluginRequestFromPath(path);
        if (requestResult case Failure<_PluginImportRequest>(:final error)) {
          errors.add(error);
          emitProgress(completed: index + 1, currentLabel: path);
          continue;
        }

        final request = (requestResult as Ok<_PluginImportRequest>).value;
        final planned = await _planImportRequest(
          request: request,
          pluginDirectory: pluginDirectory,
          currentByIdentity: currentByIdentity,
          sequence: index,
        );

        switch (planned.kind) {
          case _PlannedImportKind.imported:
            stagedImportedCount += 1;
            plannedImports.add(planned);
            currentByIdentity[_identityKeyForDefinition(planned.definition!)] =
                planned.definition!;
          case _PlannedImportKind.updated:
            stagedUpdatedCount += 1;
            plannedImports.add(planned);
            currentByIdentity[_identityKeyForDefinition(planned.definition!)] =
                planned.definition!;
          case _PlannedImportKind.skipped:
            skippedCount += 1;
          case _PlannedImportKind.failed:
            errors.add(planned.error!);
        }

        emitProgress(completed: index + 1, currentLabel: path);
      }

      final commitError = await _commitPlannedImports(plannedImports);
      if (commitError != null) {
        errors.add(commitError);
        stagedImportedCount = 0;
        stagedUpdatedCount = 0;
      }

      return PluginImportBatchResult(
        importedCount: stagedImportedCount,
        updatedCount: stagedUpdatedCount,
        skippedCount: skippedCount,
        errors: List<AppError>.unmodifiable(errors),
      );
    } catch (error, stackTrace) {
      errors.add(
        AppError(
          code: 'plugin.load_failed',
          message: 'Failed to import plugin files.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
      return PluginImportBatchResult(
        importedCount: 0,
        updatedCount: 0,
        skippedCount: skippedCount,
        errors: List<AppError>.unmodifiable(errors),
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

      return _importSingleRequest(
        _PluginImportRequest(
          source: rawData,
          fileName: _fileNameFromUri(uri),
          importLabel: uri.toString(),
        ),
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

  Future<Result<PluginDefinition>> _importSingleRequest(
    _PluginImportRequest request,
  ) async {
    try {
      await _legacyMigration?.ensureMigrated();
      final installed = await _readDefinitions();
      final currentByIdentity = <String, PluginDefinition>{
        for (final definition in installed)
          _identityKeyForDefinition(definition): definition,
      };
      final pluginDirectory = await _fileStore.pluginsDirectory();
      final planned = await _planImportRequest(
        request: request,
        pluginDirectory: pluginDirectory,
        currentByIdentity: currentByIdentity,
        sequence: 0,
      );
      switch (planned.kind) {
        case _PlannedImportKind.imported:
        case _PlannedImportKind.updated:
          final commitError = await _commitPlannedImports(
            <_PlannedPluginImport>[planned],
          );
          if (commitError != null) {
            return Failure(commitError);
          }
          return Ok(planned.definition!);
        case _PlannedImportKind.skipped:
          return Failure(
            AppError(
              code: 'plugin.skipped',
              message:
                  planned.skipMessage ??
                  'Plugin is already imported and up to date.',
            ),
          );
        case _PlannedImportKind.failed:
          return Failure(planned.error!);
      }
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'plugin.load_failed',
          message: 'Failed to import plugin from ${request.importLabel}.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<Result<_PluginImportRequest>> _pluginRequestFromPath(
    String path,
  ) async {
    try {
      final sourceFile = File(path);
      final source = await sourceFile.readAsString();
      return Ok(
        _PluginImportRequest(
          source: source,
          fileName: sourceFile.uri.pathSegments.last,
          importLabel: path,
        ),
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

  Future<_PlannedPluginImport> _planImportRequest({
    required _PluginImportRequest request,
    required Directory pluginDirectory,
    required Map<String, PluginDefinition> currentByIdentity,
    required int sequence,
  }) async {
    try {
      final metadataResult = await _runtimeFactory.loadPluginMetadata(
        request.source,
      );
      if (metadataResult case Failure<Map<String, Object?>>(:final error)) {
        return _PlannedPluginImport.failed(error);
      }

      final metadata = (metadataResult as Ok<Map<String, Object?>>).value;
      final destination = File(
        p.join(
          pluginDirectory.path,
          _destinationFileName(sequence, request.fileName),
        ),
      );
      final definitionResult = _compatAdapter.definitionFromRuntimeMetadata(
        sourcePath: destination.path,
        metadata: metadata,
      );
      if (definitionResult case Failure<PluginDefinition>(:final error)) {
        return _PlannedPluginImport.failed(error);
      }

      final parsedDefinition = (definitionResult as Ok<PluginDefinition>).value;
      final identityKey = _identityKeyForDefinition(parsedDefinition);
      final existing = currentByIdentity[identityKey];
      if (existing == null) {
        return _PlannedPluginImport.imported(
          request: request,
          definition: parsedDefinition,
        );
      }

      final decision = _resolveDuplicate(existing, parsedDefinition);
      if (decision.kind == _PlannedImportKind.skipped) {
        return _PlannedPluginImport.skipped(
          decision.message ??
              'Plugin "${existing.platform}" is already up to date.',
        );
      }

      final mergedDefinition = parsedDefinition.copyWith(
        id: existing.id,
        enabled: existing.enabled,
        installedAt: existing.installedAt,
        updatedAt: DateTime.now(),
        userVariableValues: _retainedUserVariableValues(
          existing.userVariableValues,
          parsedDefinition.userVariables,
        ),
      );
      return _PlannedPluginImport.updated(
        request: request,
        previousDefinition: existing,
        definition: mergedDefinition,
      );
    } catch (error, stackTrace) {
      return _PlannedPluginImport.failed(
        AppError(
          code: 'plugin.load_failed',
          message: 'Failed to import plugin from ${request.importLabel}.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  _DuplicateDecision _resolveDuplicate(
    PluginDefinition existing,
    PluginDefinition incoming,
  ) {
    final existingVersion = _normalizedText(existing.version);
    final incomingVersion = _normalizedText(incoming.version);
    final incomingParts = _parseVersionParts(incomingVersion);
    final existingParts = _parseVersionParts(existingVersion);

    if (existingVersion == null || existingVersion.isEmpty) {
      if (incomingParts != null) {
        return const _DuplicateDecision.update();
      }
      return _DuplicateDecision.skipped(_skipMessage(existing));
    }

    if (incomingVersion == null || incomingVersion.isEmpty) {
      return _DuplicateDecision.skipped(_skipMessage(existing));
    }
    if (existingParts == null || incomingParts == null) {
      return _DuplicateDecision.skipped(_skipMessage(existing));
    }

    return _compareVersionParts(incomingParts, existingParts) > 0
        ? const _DuplicateDecision.update()
        : _DuplicateDecision.skipped(_skipMessage(existing));
  }

  Future<AppError?> _commitPlannedImports(
    List<_PlannedPluginImport> plannedImports,
  ) async {
    if (plannedImports.isEmpty) {
      return null;
    }

    final createdPaths = <String>[];
    try {
      await _database.transaction(() async {
        for (final planned in plannedImports) {
          final definition = planned.definition!;
          final destination = File(definition.sourcePath);
          await destination.writeAsString(planned.request!.source);
          createdPaths.add(destination.path);
          await _upsertDefinition(definition);
        }
      });
    } catch (error, stackTrace) {
      for (final path in createdPaths) {
        await _deleteFileIfExists(path);
      }
      return AppError(
        code: 'storage.write_failed',
        message: 'Failed to store imported plugins.',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    for (final planned in plannedImports) {
      final previousDefinition = planned.previousDefinition;
      final nextDefinition = planned.definition!;
      if (planned.kind != _PlannedImportKind.updated ||
          previousDefinition == null ||
          previousDefinition.sourcePath == nextDefinition.sourcePath) {
        continue;
      }
      await _deleteFileIfExists(previousDefinition.sourcePath);
    }
    return null;
  }

  Future<void> _deleteFileIfExists(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup for replaced plugin sources.
    }
  }

  Map<String, String> _retainedUserVariableValues(
    Map<String, String> existingValues,
    List<Map<String, Object?>> userVariables,
  ) {
    final allowedKeys = userVariables
        .map((variable) => variable['key']?.toString())
        .whereType<String>()
        .where((key) => key.isNotEmpty)
        .toSet();
    if (allowedKeys.isEmpty) {
      return const <String, String>{};
    }
    return Map<String, String>.fromEntries(
      existingValues.entries.where((entry) => allowedKeys.contains(entry.key)),
    );
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

  Future<void> _upsertDefinition(PluginDefinition definition) async {
    await _database
        .into(_database.pluginDefinitionRows)
        .insert(
          _definitionCompanion(definition),
          mode: InsertMode.insertOrReplace,
        );
  }

  String _destinationFileName(int sequence, String fileName) {
    return '${DateTime.now().microsecondsSinceEpoch}_${sequence}_${_safeFileName(fileName)}';
  }

  static String _identityKeyForDefinition(PluginDefinition definition) {
    final author = _normalizedText(definition.author) ?? '';
    return '${definition.platform.trim().toLowerCase()}::$author';
  }

  static String? _normalizedText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static List<int>? _parseVersionParts(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (!RegExp(r'^\d+(?:\.\d+)*$').hasMatch(value)) {
      return null;
    }
    return value.split('.').map(int.parse).toList(growable: false);
  }

  static int _compareVersionParts(List<int> left, List<int> right) {
    final maxLength = left.length > right.length ? left.length : right.length;
    for (var index = 0; index < maxLength; index += 1) {
      final leftPart = index < left.length ? left[index] : 0;
      final rightPart = index < right.length ? right[index] : 0;
      if (leftPart != rightPart) {
        return leftPart.compareTo(rightPart);
      }
    }
    return 0;
  }

  static String _skipMessage(PluginDefinition definition) {
    final author = _normalizedText(definition.author);
    final subject = author == null
        ? '"${definition.platform}"'
        : '"${definition.platform}" by "$author"';
    return 'Plugin $subject is already up to date.';
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

class _PluginImportRequest {
  const _PluginImportRequest({
    required this.source,
    required this.fileName,
    required this.importLabel,
  });

  final String source;
  final String fileName;
  final String importLabel;
}

enum _PlannedImportKind { imported, updated, skipped, failed }

class _PlannedPluginImport {
  const _PlannedPluginImport._({
    required this.kind,
    this.request,
    this.definition,
    this.previousDefinition,
    this.error,
    this.skipMessage,
  });

  const _PlannedPluginImport.imported({
    required _PluginImportRequest request,
    required PluginDefinition definition,
  }) : this._(
         kind: _PlannedImportKind.imported,
         request: request,
         definition: definition,
       );

  const _PlannedPluginImport.updated({
    required _PluginImportRequest request,
    required PluginDefinition previousDefinition,
    required PluginDefinition definition,
  }) : this._(
         kind: _PlannedImportKind.updated,
         request: request,
         definition: definition,
         previousDefinition: previousDefinition,
       );

  const _PlannedPluginImport.skipped(String message)
    : this._(kind: _PlannedImportKind.skipped, skipMessage: message);

  const _PlannedPluginImport.failed(AppError error)
    : this._(kind: _PlannedImportKind.failed, error: error);

  final _PlannedImportKind kind;
  final _PluginImportRequest? request;
  final PluginDefinition? definition;
  final PluginDefinition? previousDefinition;
  final AppError? error;
  final String? skipMessage;
}

class _DuplicateDecision {
  const _DuplicateDecision._({required this.kind, this.message});

  const _DuplicateDecision.update() : this._(kind: _PlannedImportKind.updated);

  const _DuplicateDecision.skipped(String message)
    : this._(kind: _PlannedImportKind.skipped, message: message);

  final _PlannedImportKind kind;
  final String? message;
}
