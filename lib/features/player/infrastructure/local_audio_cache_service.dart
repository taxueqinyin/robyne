import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart' as db;
import '../../../core/database/legacy_storage_migration.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/result/result.dart';
import '../../../core/storage/local_file_store.dart';
import '../domain/media_source.dart';
import '../domain/playback_item.dart';

abstract interface class AudioDownloader {
  Future<List<int>> download(MediaSource source);
}

class DioAudioDownloader implements AudioDownloader {
  DioAudioDownloader({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(minutes: 5),
            ),
          );

  final Dio _dio;

  @override
  Future<List<int>> download(MediaSource source) async {
    final response = await _dio.get<List<int>>(
      source.url,
      options: Options(
        headers: source.headers,
        responseType: ResponseType.bytes,
        validateStatus: (_) => true,
      ),
    );
    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300 || response.data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Audio download failed with HTTP $statusCode.',
      );
    }
    return response.data!;
  }
}

class LocalAudioCacheService {
  LocalAudioCacheService({
    required LocalFileStore fileStore,
    db.AppDatabase? database,
    LegacyStorageMigration? legacyMigration,
    AudioDownloader? downloader,
    Future<int> Function()? maxBytesReader,
    Future<Directory> Function()? cacheDirectoryReader,
    this.maxBytes = 1024 * 1024 * 1024,
  }) : _fileStore = fileStore,
       _database = database ?? db.AppDatabase.memory(),
       _legacyMigration = legacyMigration,
       _downloader = downloader ?? DioAudioDownloader(),
       _maxBytesReader = maxBytesReader,
       _cacheDirectoryReader = cacheDirectoryReader;

  final LocalFileStore _fileStore;
  final db.AppDatabase _database;
  final LegacyStorageMigration? _legacyMigration;
  final AudioDownloader _downloader;
  final Future<int> Function()? _maxBytesReader;
  final Future<Directory> Function()? _cacheDirectoryReader;
  final int maxBytes;
  DateTime _lastCacheClock = DateTime.fromMillisecondsSinceEpoch(0);

  Future<Result<MediaSource?>> resolveCached(PlaybackItem item) async {
    try {
      if (!item.isPlugin) {
        return const Ok(null);
      }
      await _legacyMigration?.ensureMigrated();
      final entries = await _readEntries();
      final entry = entries[item.id];
      if (entry == null) {
        return const Ok(null);
      }
      final file = File(entry.path);
      if (!await file.exists()) {
        entries.remove(item.id);
        await _writeEntries(entries);
        return const Ok(null);
      }
      entries[item.id] = entry.copyWith(lastAccessedAt: _nextClock());
      await _writeEntries(entries);
      return Ok(MediaSource(url: file.path));
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'cache.read_failed',
          message: 'Failed to resolve audio cache.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<Result<MediaSource>> resolve(
    PlaybackItem item,
    MediaSource remote,
  ) async {
    final cached = await resolveCached(item);
    switch (cached) {
      case Ok<MediaSource?>(:final value):
        if (value == null) {
          return Ok(remote);
        }
        return Ok(
          MediaSource(
            url: value.url,
            quality: remote.quality,
            mimeType: remote.mimeType,
            raw: remote.raw,
          ),
        );
      case Failure<MediaSource?>(:final error):
        return Failure(error);
    }
  }

  Future<Result<void>> cache(PlaybackItem item, MediaSource source) async {
    if (!item.isPlugin) {
      return const Ok(null);
    }
    try {
      await _legacyMigration?.ensureMigrated();
      final bytes = await _downloader.download(source);
      final directory = await _cacheFilesDirectory();
      final file = File(p.join(directory.path, _safeFileName(item.id)));
      await file.writeAsBytes(bytes, flush: true);
      await _upsertPlaybackItem(item);

      final now = _nextClock();
      final entries = await _readEntries();
      entries[item.id] = _CacheEntry(
        itemId: item.id,
        sourceUrl: source.url,
        path: file.path,
        size: bytes.length,
        createdAt: now,
        lastAccessedAt: now,
      );
      await _trim(entries, keepItemId: item.id);
      await _writeEntries(entries);
      return const Ok(null);
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'cache.write_failed',
          message: 'Failed to cache audio source.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<Map<String, _CacheEntry>> _readEntries() async {
    final entries = <String, _CacheEntry>{};
    final rows = await _database.select(_database.audioCacheEntries).get();
    for (final row in rows) {
      entries[row.itemId] = _CacheEntry(
        itemId: row.itemId,
        sourceUrl: row.sourceUrl,
        path: row.path,
        size: row.size,
        createdAt: row.createdAt,
        lastAccessedAt: row.lastAccessedAt,
      );
    }
    return entries;
  }

  Future<void> _writeEntries(Map<String, _CacheEntry> entries) async {
    await _database.transaction(() async {
      await _database.delete(_database.audioCacheEntries).go();
      for (final entry in entries.values) {
        await _database
            .into(_database.audioCacheEntries)
            .insert(
              db.AudioCacheEntriesCompanion(
                itemId: Value(entry.itemId),
                sourceUrl: Value(entry.sourceUrl),
                path: Value(entry.path),
                size: Value(entry.size),
                createdAt: Value(entry.createdAt),
                lastAccessedAt: Value(entry.lastAccessedAt),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  Future<void> _trim(
    Map<String, _CacheEntry> entries, {
    required String keepItemId,
  }) async {
    var total = entries.values.fold<int>(0, (sum, entry) => sum + entry.size);
    final effectiveMaxBytes = await _effectiveMaxBytes();
    if (total <= effectiveMaxBytes) {
      return;
    }

    final ordered = entries.values.toList()
      ..sort((a, b) => a.lastAccessedAt.compareTo(b.lastAccessedAt));
    for (final entry in ordered) {
      if (total <= effectiveMaxBytes) {
        break;
      }
      if (entry.itemId == keepItemId && entries.length > 1) {
        continue;
      }
      final file = File(entry.path);
      if (await file.exists()) {
        await file.delete();
      }
      entries.remove(entry.itemId);
      total -= entry.size;
    }
  }

  Future<Directory> _cacheFilesDirectory() async {
    final configuredDirectory = await _cacheDirectoryReader?.call();
    if (configuredDirectory != null) {
      final audioDirectory = Directory(
        p.join(configuredDirectory.path, 'audio'),
      );
      if (!await audioDirectory.exists()) {
        await audioDirectory.create(recursive: true);
      }
      return audioDirectory;
    }
    final directory = Directory(
      p.join((await _fileStore.cacheDirectory()).path, 'audio'),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<int> _effectiveMaxBytes() async {
    return await _maxBytesReader?.call() ?? maxBytes;
  }

  static String _safeFileName(String value) {
    return '${base64Url.encode(utf8.encode(value)).replaceAll('=', '')}.audio';
  }

  DateTime _nextClock() {
    final now = DateTime.now();
    final minimum = _lastCacheClock.add(const Duration(seconds: 1));
    if (now.isAfter(minimum)) {
      _lastCacheClock = now;
    } else {
      _lastCacheClock = minimum;
    }
    return _lastCacheClock;
  }

  Future<void> _upsertPlaybackItem(PlaybackItem item) async {
    await _database
        .into(_database.playbackItems)
        .insert(
          db.PlaybackItemsCompanion(
            id: Value(item.id),
            type: Value(item.type.name),
            title: Value(item.title),
            platform: Value(item.platform),
            musicId: Value(item.musicId),
            localPath: Value(item.localPath),
            artist: Value(item.artist),
            album: Value(item.album),
            durationMs: Value(item.duration?.inMilliseconds),
            artworkUrl: Value(item.artworkUrl),
            rawJson: Value(jsonEncode(item.raw)),
            updatedAt: Value(DateTime.now()),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }
}

class _CacheEntry {
  const _CacheEntry({
    required this.itemId,
    required this.sourceUrl,
    required this.path,
    required this.size,
    required this.createdAt,
    required this.lastAccessedAt,
  });

  final String itemId;
  final String sourceUrl;
  final String path;
  final int size;
  final DateTime createdAt;
  final DateTime lastAccessedAt;

  _CacheEntry copyWith({DateTime? lastAccessedAt}) {
    return _CacheEntry(
      itemId: itemId,
      sourceUrl: sourceUrl,
      path: path,
      size: size,
      createdAt: createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    );
  }
}
