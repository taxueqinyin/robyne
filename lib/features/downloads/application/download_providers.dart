import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/result/result.dart';
import '../../player/domain/media_source.dart';
import '../../player/domain/playback_item.dart';
import '../../plugin/application/plugin_providers.dart';
import '../../plugin/application/plugin_runtime_config.dart';
import '../../plugin/domain/plugin_definition.dart';
import '../../plugin/domain/plugin_runtime.dart';
import '../../settings/application/settings_providers.dart';
import '../domain/download_task.dart';
import '../infrastructure/download_file_namer.dart';
import '../infrastructure/download_repository.dart';

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  return DownloadRepository(
    database: ref.watch(appDatabaseProvider),
    legacyMigration: ref.watch(legacyStorageMigrationProvider),
  );
});

final downloadControllerProvider =
    AsyncNotifierProvider<DownloadController, List<DownloadTask>>(
      DownloadController.new,
    );

class DownloadController extends AsyncNotifier<List<DownloadTask>> {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
    ),
  );

  @override
  Future<List<DownloadTask>> build() async {
    final repository = ref.watch(downloadRepositoryProvider);
    await repository.markInterruptedDownloadsFailed();
    return repository.listTasks();
  }

  Future<void> startDownload(PlaybackItem item) async {
    if (!item.isPlugin) {
      return;
    }
    final now = DateTime.now();
    var task = DownloadTask(
      id: item.id,
      item: item,
      status: DownloadStatus.queued,
      progress: 0,
      createdAt: now,
      updatedAt: now,
    );
    await _saveAndPublish(task);

    task = _copyTask(
      task,
      status: DownloadStatus.downloading,
      updatedAt: DateTime.now(),
    );
    await _saveAndPublish(task);

    try {
      final sourceResult = await _mediaSourceFromPluginItem(item);
      final source = switch (sourceResult) {
        Ok(:final value) => value,
        Failure(:final error) => throw _DownloadException(error),
      };
      final filePath = await _downloadPath(item, source);
      await _dio.download(
        source.url,
        filePath,
        options: Options(
          headers: source.headers,
          responseType: ResponseType.bytes,
        ),
        onReceiveProgress: (received, total) {
          if (total <= 0) {
            return;
          }
          final progress = (received / total).clamp(0, 1).toDouble();
          state = AsyncData(
            _replace(
              _copyTask(
                task,
                progress: progress,
                sourceUrl: source.url,
                filePath: filePath,
                updatedAt: DateTime.now(),
              ),
            ),
          );
        },
      );

      task = _copyTask(
        task,
        status: DownloadStatus.completed,
        progress: 1,
        sourceUrl: source.url,
        filePath: filePath,
        updatedAt: DateTime.now(),
        completedAt: DateTime.now(),
      );
      await _saveAndPublish(task);
    } catch (error) {
      final message = error is _DownloadException
          ? '${error.error.code}: ${error.error.message}'
          : error.toString();
      task = _copyTask(
        task,
        status: DownloadStatus.failed,
        errorMessage: message,
        updatedAt: DateTime.now(),
      );
      await _saveAndPublish(task);
    }
  }

  Future<void> retry(DownloadTask task) async {
    await startDownload(task.item);
  }

  Future<void> deleteTask(DownloadTask task) async {
    final path = task.filePath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await ref.read(downloadRepositoryProvider).deleteTask(task.id);
    ref.invalidateSelf();
  }

  Future<void> _saveAndPublish(DownloadTask task) async {
    await ref.read(downloadRepositoryProvider).upsertTask(task);
    state = AsyncData(_replace(task));
  }

  List<DownloadTask> _replace(DownloadTask task) {
    final current = state.value ?? const <DownloadTask>[];
    var replaced = false;
    final next = current
        .map((candidate) {
          if (candidate.id == task.id) {
            replaced = true;
            return task;
          }
          return candidate;
        })
        .toList(growable: true);
    if (!replaced) {
      next.insert(0, task);
    }
    return next;
  }

  Future<Result<MediaSource>> _mediaSourceFromPluginItem(
    PlaybackItem item,
  ) async {
    final runtimeFactory = ref.read(pluginRuntimeFactoryProvider);
    final repository = ref.read(pluginRepositoryProvider);
    final compat = ref.read(musicFreeCompatAdapterProvider);

    final pluginsResult = await repository.listPlugins();
    final plugins = pluginsResult.fold(
      (plugins) => plugins,
      (error) => const <PluginDefinition>[],
    );
    PluginDefinition? plugin;
    for (final candidate in plugins) {
      if (candidate.enabled && candidate.platform == item.platform) {
        plugin = candidate;
        break;
      }
    }
    if (plugin == null) {
      return const Failure(
        AppError(
          code: 'plugin.not_found',
          message: 'No enabled plugin can download this item.',
        ),
      );
    }

    PluginRuntime? runtime;
    try {
      runtime = await runtimeFactory.create();
      final loaded = await runtime.loadPlugin(
        await File(plugin.sourcePath).readAsString(),
        userVariables: Map<String, String>.from(plugin.userVariableValues),
      );
      if (loaded case Failure<Map<String, Object?>>(:final error)) {
        return Failure(error);
      }
      final mediaResult = await runtime.callMethod('getMediaSource', <Object?>[
        item.raw,
        'standard',
      ], timeout: pluginMethodTimeout);
      return switch (mediaResult) {
        Ok<Object?>(:final value) => compat.mediaSourceFromPluginValue(value),
        Failure<Object?>(:final error) => Failure(error),
      };
    } finally {
      await runtime?.dispose();
    }
  }

  Future<String> _downloadPath(PlaybackItem item, MediaSource source) async {
    final settings = await ref.read(settingsRepositoryProvider).load();
    final directory = Directory(settings.downloadsDirectoryPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final uri = Uri.tryParse(source.url);
    final fileName = downloadFileNameForItem(item, uri);
    return p.join(directory.path, fileName);
  }

  DownloadTask _copyTask(
    DownloadTask task, {
    DownloadStatus? status,
    double? progress,
    String? sourceUrl,
    String? filePath,
    String? errorMessage,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return DownloadTask(
      id: task.id,
      item: task.item,
      status: status ?? task.status,
      progress: progress ?? task.progress,
      sourceUrl: sourceUrl ?? task.sourceUrl,
      filePath: filePath ?? task.filePath,
      errorMessage: errorMessage,
      createdAt: task.createdAt,
      updatedAt: updatedAt ?? task.updatedAt,
      completedAt: completedAt ?? task.completedAt,
    );
  }
}

class _DownloadException implements Exception {
  const _DownloadException(this.error);

  final AppError error;
}
