import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/database/legacy_storage_migration.dart';
import '../../player/domain/playback_item.dart';
import '../domain/download_task.dart';

class DownloadRepository {
  DownloadRepository({
    required db.AppDatabase database,
    LegacyStorageMigration? legacyMigration,
  }) : _database = database,
       _legacyMigration = legacyMigration;

  final db.AppDatabase _database;
  final LegacyStorageMigration? _legacyMigration;

  Future<List<DownloadTask>> listTasks() async {
    await _legacyMigration?.ensureMigrated();
    final rows =
        await (_database.select(_database.downloadTasks)
              ..orderBy(<OrderingTerm Function(db.$DownloadTasksTable)>[
                (row) => OrderingTerm.desc(row.updatedAt),
              ]))
            .get();
    final tasks = <DownloadTask>[];
    for (final row in rows) {
      final item =
          await (_database.select(_database.playbackItems)
                ..where((playbackItem) => playbackItem.id.equals(row.itemId)))
              .getSingleOrNull();
      if (item != null) {
        tasks.add(_taskFromRows(row, item));
      }
    }
    return tasks;
  }

  Future<DownloadTask?> completedForItem(String itemId) async {
    await _legacyMigration?.ensureMigrated();
    final row =
        await (_database.select(_database.downloadTasks)
              ..where(
                (task) =>
                    task.itemId.equals(itemId) &
                    task.status.equals(DownloadStatus.completed.name),
              )
              ..limit(1))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }
    final item =
        await (_database.select(_database.playbackItems)
              ..where((playbackItem) => playbackItem.id.equals(row.itemId)))
            .getSingleOrNull();
    return item == null ? null : _taskFromRows(row, item);
  }

  Future<void> markInterruptedDownloadsFailed() async {
    await _legacyMigration?.ensureMigrated();
    final now = DateTime.now();
    await (_database.update(_database.downloadTasks)..where(
          (task) =>
              task.status.equals(DownloadStatus.queued.name) |
              task.status.equals(DownloadStatus.downloading.name) |
              task.status.equals(DownloadStatus.converting.name),
        ))
        .write(
          db.DownloadTasksCompanion(
            status: Value(DownloadStatus.failed.name),
            errorMessage: const Value('Download interrupted.'),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> upsertTask(DownloadTask task) async {
    await _legacyMigration?.ensureMigrated();
    await _upsertPlaybackItem(task.item);
    await _database
        .into(_database.downloadTasks)
        .insert(_taskCompanion(task), mode: InsertMode.insertOrReplace);
  }

  Future<void> deleteTask(String id) async {
    await _legacyMigration?.ensureMigrated();
    await (_database.delete(
      _database.downloadTasks,
    )..where((task) => task.id.equals(id))).go();
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

  static DownloadTask _taskFromRows(db.DownloadTask row, db.PlaybackItem item) {
    return DownloadTask(
      id: row.id,
      item: _itemFromRow(item),
      status: DownloadStatus.values.firstWhere(
        (status) => status.name == row.status,
        orElse: () => DownloadStatus.failed,
      ),
      progress: row.progress,
      sourceUrl: row.sourceUrl,
      filePath: row.filePath,
      errorMessage: row.errorMessage,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      completedAt: row.completedAt,
    );
  }

  static db.DownloadTasksCompanion _taskCompanion(DownloadTask task) {
    return db.DownloadTasksCompanion(
      id: Value(task.id),
      itemId: Value(task.item.id),
      status: Value(task.status.name),
      progress: Value(task.progress),
      sourceUrl: Value(task.sourceUrl),
      filePath: Value(task.filePath),
      errorMessage: Value(task.errorMessage),
      createdAt: Value(task.createdAt),
      updatedAt: Value(task.updatedAt),
      completedAt: Value(task.completedAt),
    );
  }

  static PlaybackItem _itemFromRow(db.PlaybackItem row) {
    return PlaybackItem(
      id: row.id,
      type: PlaybackItemType.values.firstWhere(
        (type) => type.name == row.type,
        orElse: () => PlaybackItemType.plugin,
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
}
