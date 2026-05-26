import 'dart:convert';
import 'dart:io';

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
  }) : _fileStore = fileStore,
       _preferences = preferences,
       _runtimeFactory = runtimeFactory,
       _compatAdapter = compatAdapter;

  static const _storageKey = 'plugins.v1';

  final LocalFileStore _fileStore;
  final SharedPreferencesAsync _preferences;
  final PluginRuntimeFactory _runtimeFactory;
  final MusicFreeCompatAdapter _compatAdapter;

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
    PluginRuntime? runtime;
    try {
      final source = await File(path).readAsString();
      runtime = await _runtimeFactory.create();
      final metadataResult = await runtime.loadPlugin(source);
      if (metadataResult case Failure<Map<String, Object?>>(:final error)) {
        return Failure(error);
      }

      final metadata = (metadataResult as Ok<Map<String, Object?>>).value;
      final pluginDirectory = await _fileStore.pluginsDirectory();
      final sourceFile = File(path);
      final destination = File(
        '${pluginDirectory.path}/${DateTime.now().microsecondsSinceEpoch}_${sourceFile.uri.pathSegments.last}',
      );
      await sourceFile.copy(destination.path);

      final definitionResult = _compatAdapter.definitionFromRuntimeMetadata(
        sourcePath: destination.path,
        metadata: metadata,
      );
      if (definitionResult case Failure<PluginDefinition>(:final error)) {
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
          message: 'Failed to import plugin from $path.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      await runtime?.dispose();
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
}
