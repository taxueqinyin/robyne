import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/database/legacy_storage_migration.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/result/result.dart';
import '../../../core/storage/local_file_store.dart';
import '../../player/domain/playback_item.dart';

class LocalMusicRepository {
  LocalMusicRepository({
    required LocalFileStore fileStore,
    db.AppDatabase? database,
    LegacyStorageMigration? legacyMigration,
  }) : _database = database ?? db.AppDatabase.memory(),
       _legacyMigration = legacyMigration;

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

  final db.AppDatabase _database;
  final LegacyStorageMigration? _legacyMigration;

  Future<Result<List<PlaybackItem>>> listTracks() async {
    try {
      await _legacyMigration?.ensureMigrated();
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
      await _legacyMigration?.ensureMigrated();
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
          await _upsertTrack(item);
        }
      }

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
      await _legacyMigration?.ensureMigrated();
      await (_database.delete(
        _database.localLibraryTracks,
      )..where((row) => row.itemId.equals(id))).go();
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
    final rows =
        await (_database.select(_database.localLibraryTracks)
              ..orderBy(<OrderingTerm Function(db.$LocalLibraryTracksTable)>[
                (row) => OrderingTerm.asc(row.addedAt),
              ]))
            .get();
    final tracks = <PlaybackItem>[];
    for (final row in rows) {
      final item = await (_database.select(
        _database.playbackItems,
      )..where((item) => item.id.equals(row.itemId))).getSingleOrNull();
      if (item != null) {
        tracks.add(_itemFromRow(item));
      }
    }
    return tracks;
  }

  Future<void> _upsertTrack(PlaybackItem item) async {
    await _database.transaction(() async {
      await _database
          .into(_database.playbackItems)
          .insert(_itemCompanion(item), mode: InsertMode.insertOrReplace);
      await _database
          .into(_database.localLibraryTracks)
          .insert(
            db.LocalLibraryTracksCompanion(
              itemId: Value(item.id),
              addedAt: Value(DateTime.now()),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    });
  }

  static db.PlaybackItemsCompanion _itemCompanion(PlaybackItem item) {
    return db.PlaybackItemsCompanion(
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
    );
  }

  static PlaybackItem _itemFromRow(db.PlaybackItem row) {
    return PlaybackItem(
      id: row.id,
      type: PlaybackItemType.values.firstWhere(
        (type) => type.name == row.type,
        orElse: () => PlaybackItemType.local,
      ),
      title: row.title,
      platform: row.platform,
      musicId: row.musicId,
      localPath: row.localPath,
      artist: row.artist,
      album: row.album,
      duration: row.durationMs == null
          ? null
          : Duration(milliseconds: row.durationMs!),
      artworkUrl: row.artworkUrl,
      raw: _jsonMap(row.rawJson),
    );
  }

  static Map<String, Object?> _jsonMap(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) {
        return decoded.map(
          (key, dynamic value) => MapEntry(key.toString(), value as Object?),
        );
      }
    } catch (_) {}
    return const <String, Object?>{};
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
