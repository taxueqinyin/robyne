import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

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
    AudioDownloader? downloader,
    this.maxBytes = 1024 * 1024 * 1024,
  }) : _fileStore = fileStore,
       _downloader = downloader ?? DioAudioDownloader();

  static const _indexFileName = 'audio_cache.v1.json';

  final LocalFileStore _fileStore;
  final AudioDownloader _downloader;
  final int maxBytes;

  Future<Result<MediaSource?>> resolveCached(PlaybackItem item) async {
    try {
      if (!item.isPlugin) {
        return const Ok(null);
      }
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
      entries[item.id] = entry.copyWith(lastAccessedAt: DateTime.now());
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
      final bytes = await _downloader.download(source);
      final directory = await _cacheFilesDirectory();
      final file = File('${directory.path}/${_safeFileName(item.id)}');
      await file.writeAsBytes(bytes, flush: true);

      final now = DateTime.now();
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
    final file = await _indexFile();
    if (!await file.exists()) {
      return <String, _CacheEntry>{};
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) {
      return <String, _CacheEntry>{};
    }
    final entries = <String, _CacheEntry>{};
    for (final value in decoded.whereType<Map>()) {
      final entry = _CacheEntry.fromJson(
        value.map(
          (key, dynamic mapValue) =>
              MapEntry(key.toString(), mapValue as Object?),
        ),
      );
      entries[entry.itemId] = entry;
    }
    return entries;
  }

  Future<void> _writeEntries(Map<String, _CacheEntry> entries) async {
    final file = await _indexFile();
    await file.writeAsString(
      jsonEncode(entries.values.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> _trim(
    Map<String, _CacheEntry> entries, {
    required String keepItemId,
  }) async {
    var total = entries.values.fold<int>(0, (sum, entry) => sum + entry.size);
    if (total <= maxBytes) {
      return;
    }

    final ordered = entries.values.toList()
      ..sort((a, b) => a.lastAccessedAt.compareTo(b.lastAccessedAt));
    for (final entry in ordered) {
      if (total <= maxBytes) {
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

  Future<File> _indexFile() async {
    return File('${(await _fileStore.cacheDirectory()).path}/$_indexFileName');
  }

  Future<Directory> _cacheFilesDirectory() async {
    final directory = Directory(
      '${(await _fileStore.cacheDirectory()).path}/audio',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static String _safeFileName(String value) {
    return '${base64Url.encode(utf8.encode(value)).replaceAll('=', '')}.audio';
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

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'itemId': itemId,
      'sourceUrl': sourceUrl,
      'path': path,
      'size': size,
      'createdAt': createdAt.toIso8601String(),
      'lastAccessedAt': lastAccessedAt.toIso8601String(),
    };
  }

  static _CacheEntry fromJson(Map<String, Object?> json) {
    return _CacheEntry(
      itemId: json['itemId']?.toString() ?? '',
      sourceUrl: json['sourceUrl']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      size: json['size'] is num ? (json['size']! as num).toInt() : 0,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastAccessedAt:
          DateTime.tryParse(json['lastAccessedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
