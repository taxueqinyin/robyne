import 'dart:convert';
import 'dart:io';

import '../../../core/errors/app_error.dart';
import '../../../core/result/result.dart';
import '../../../core/storage/local_file_store.dart';
import '../../player/domain/playback_item.dart';

class LocalMusicRepository {
  LocalMusicRepository({required LocalFileStore fileStore})
    : _fileStore = fileStore;

  static const _fileName = 'local_music.v1.json';
  static const _supportedExtensions = <String>{
    'mp3',
    'flac',
    'wav',
    'm4a',
    'aac',
    'ogg',
    'opus',
    'wma',
  };

  final LocalFileStore _fileStore;

  Future<Result<List<PlaybackItem>>> listTracks() async {
    try {
      return Ok(await _readTracks());
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'storage.read_failed',
          message: 'Failed to read local music library.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<Result<List<PlaybackItem>>> importFiles(List<String> paths) async {
    try {
      final imported = <PlaybackItem>[];
      final existing = await _readTracks();
      final byId = <String, PlaybackItem>{
        for (final item in existing) item.id: item,
      };

      for (final path in paths) {
        final file = File(path);
        if (!await file.exists()) {
          return Failure(
            AppError(
              code: 'local.file_missing',
              message: 'Local music file does not exist: $path',
            ),
          );
        }
        if (!_isSupported(path)) {
          continue;
        }

        final item = PlaybackItem.local(path: path);
        if (!byId.containsKey(item.id)) {
          byId[item.id] = item;
          imported.add(item);
        }
      }

      await _writeTracks(byId.values.toList(growable: false));
      return Ok(imported);
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'storage.write_failed',
          message: 'Failed to import local music.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<Result<List<PlaybackItem>>> importFolder(String path) async {
    try {
      final directory = Directory(path);
      if (!await directory.exists()) {
        return Failure(
          AppError(
            code: 'local.folder_missing',
            message: 'Local music folder does not exist: $path',
          ),
        );
      }

      final files = <String>[];
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File && _isSupported(entity.path)) {
          files.add(entity.path);
        }
      }
      files.sort();
      return importFiles(files);
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'storage.read_failed',
          message: 'Failed to scan local music folder.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<Result<void>> removeTrack(String id) async {
    try {
      final tracks = await _readTracks();
      tracks.removeWhere((item) => item.id == id);
      await _writeTracks(tracks);
      return const Ok(null);
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'storage.write_failed',
          message: 'Failed to remove local music.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<List<PlaybackItem>> _readTracks() async {
    final file = await _storageFile();
    if (!await file.exists()) {
      return <PlaybackItem>[];
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) {
      return <PlaybackItem>[];
    }
    return decoded
        .whereType<Map>()
        .map(
          (value) => PlaybackItem.fromJson(
            value.map(
              (key, dynamic mapValue) =>
                  MapEntry(key.toString(), mapValue as Object?),
            ),
          ),
        )
        .toList(growable: true);
  }

  Future<void> _writeTracks(List<PlaybackItem> tracks) async {
    final file = await _storageFile();
    await file.writeAsString(
      jsonEncode(tracks.map((item) => item.toJson()).toList()),
    );
  }

  Future<File> _storageFile() async {
    return File('${(await _fileStore.dataDirectory()).path}/$_fileName');
  }

  static bool _isSupported(String path) {
    final fileName = path.replaceAll(r'\', '/').split('/').last;
    final dot = fileName.lastIndexOf('.');
    if (dot == -1) {
      return false;
    }
    return _supportedExtensions.contains(
      fileName.substring(dot + 1).toLowerCase(),
    );
  }
}
