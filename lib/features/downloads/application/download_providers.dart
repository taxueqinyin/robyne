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
import '../domain/download_audio_format.dart';
import '../domain/download_task.dart';
import '../infrastructure/download_audio_transcoder.dart';
import '../infrastructure/download_file_namer.dart';
import '../infrastructure/download_repository.dart';

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  return DownloadRepository(
    database: ref.watch(appDatabaseProvider),
    legacyMigration: ref.watch(legacyStorageMigrationProvider),
  );
});

final downloadAudioTranscoderProvider = Provider<DownloadAudioTranscoder>((
  ref,
) {
  return FfmpegDownloadAudioTranscoder();
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

    String? temporaryDownloadPath;
    String? temporaryConversionPath;
    try {
      final sourceResult = await _mediaSourceFromPluginItem(item);
      final source = switch (sourceResult) {
        Ok(:final value) => value,
        Failure(:final error) => throw _DownloadException(error),
      };
      final settings = await ref.read(settingsRepositoryProvider).load();
      final sourceUri = Uri.tryParse(source.url);
      final filePath = await _downloadPath(
        item,
        source,
        downloadsDirectoryPath: settings.downloadsDirectoryPath,
        audioFormat: settings.downloadAudioFormat,
      );
      final needsTranscode = _needsTranscode(
        settings.downloadAudioFormat,
        source,
        sourceUri,
      );
      final downloadPath = needsTranscode
          ? _temporaryDownloadPath(filePath, sourceUri)
          : filePath;
      if (needsTranscode) {
        temporaryDownloadPath = downloadPath;
        temporaryConversionPath = _temporaryConversionPath(filePath);
      }

      await _dio.download(
        source.url,
        downloadPath,
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

      if (needsTranscode) {
        task = _copyTask(
          task,
          status: DownloadStatus.converting,
          progress: 1,
          sourceUrl: source.url,
          filePath: filePath,
          updatedAt: DateTime.now(),
        );
        await _saveAndPublish(task);

        final conversionPath = temporaryConversionPath!;
        await ref
            .read(downloadAudioTranscoderProvider)
            .transcode(
              inputPath: downloadPath,
              outputPath: conversionPath,
              format: settings.downloadAudioFormat,
              metadata: _metadataFor(item),
            );
        await _replaceFile(conversionPath, filePath);
        await _deleteIfExists(downloadPath);
        temporaryDownloadPath = null;
        temporaryConversionPath = null;
      }

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
      if (temporaryDownloadPath != null) {
        await _deleteIfExists(temporaryDownloadPath);
      }
      if (temporaryConversionPath != null) {
        await _deleteIfExists(temporaryConversionPath);
      }
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

  Future<String> _downloadPath(
    PlaybackItem item,
    MediaSource source, {
    required String downloadsDirectoryPath,
    required DownloadAudioFormat audioFormat,
  }) async {
    final directory = Directory(downloadsDirectoryPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final uri = Uri.tryParse(source.url);
    final fileName = downloadFileNameForItem(
      item,
      uri,
      targetExtension: audioFormat.extension,
    );
    return p.join(directory.path, fileName);
  }

  bool _needsTranscode(
    DownloadAudioFormat format,
    MediaSource source,
    Uri? sourceUri,
  ) {
    if (format == DownloadAudioFormat.original) {
      return false;
    }
    final targetExtension = format.extension;
    final sourceExtension = p.extension(sourceUri?.path ?? '').toLowerCase();
    if (targetExtension != null && sourceExtension == targetExtension) {
      return false;
    }

    final mimeType = source.mimeType?.toLowerCase();
    return switch (format) {
      DownloadAudioFormat.mp3 =>
        mimeType != 'audio/mpeg' && mimeType != 'audio/mp3',
      DownloadAudioFormat.wav =>
        mimeType != 'audio/wav' &&
            mimeType != 'audio/x-wav' &&
            mimeType != 'audio/wave',
      DownloadAudioFormat.original => false,
    };
  }

  String _temporaryDownloadPath(String outputPath, Uri? sourceUri) {
    final sourceExtension = p.extension(sourceUri?.path ?? '');
    final extension = sourceExtension.isEmpty ? '.audio' : sourceExtension;
    return '$outputPath.download$extension';
  }

  String _temporaryConversionPath(String outputPath) {
    final extension = p.extension(outputPath);
    final basename = p.basenameWithoutExtension(outputPath);
    return p.join(p.dirname(outputPath), '$basename.converted$extension');
  }

  Map<String, String> _metadataFor(PlaybackItem item) {
    return <String, String>{
      'title': item.title,
      if (item.artist != null) 'artist': item.artist!,
      if (item.album != null) 'album': item.album!,
    };
  }

  Future<void> _replaceFile(String sourcePath, String targetPath) async {
    final target = File(targetPath);
    if (await target.exists()) {
      await target.delete();
    }
    await File(sourcePath).rename(targetPath);
  }

  Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
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
