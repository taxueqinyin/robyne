import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/database/legacy_storage_migration.dart';
import '../../../core/storage/local_file_store.dart';
import '../domain/playback_item.dart';
import 'player_providers.dart';

class PlayerStateRepository {
  PlayerStateRepository({
    db.AppDatabase? database,
    LocalFileStore? fileStore,
    LegacyStorageMigration? legacyMigration,
  }) : _database = database ?? db.AppDatabase.memory(),
       _legacyMigration = legacyMigration;

  final db.AppDatabase _database;
  final LegacyStorageMigration? _legacyMigration;

  Future<PlayerControllerState> load() async {
    await _legacyMigration?.ensureMigrated();
    try {
      final stateRow = await (_database.select(
        _database.playerStateRows,
      )..where((row) => row.id.equals(1))).getSingleOrNull();
      final queueRows =
          await (_database.select(_database.queueEntries)
                ..orderBy(<OrderingTerm Function(db.$QueueEntriesTable)>[
                  (row) => OrderingTerm.asc(row.position),
                ]))
              .get();
      final queue = <PlaybackItem>[];
      for (final row in queueRows) {
        final item = await _itemById(row.itemId);
        if (item != null) {
          queue.add(item);
        }
      }

      final historyRows =
          await (_database.select(_database.playbackHistoryRows)
                ..orderBy(<OrderingTerm Function(db.$PlaybackHistoryRowsTable)>[
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();
      final history = <PlaybackHistoryEntry>[];
      for (final row in historyRows) {
        final item = await _itemById(row.itemId);
        if (item != null) {
          history.add(PlaybackHistoryEntry(item: item, playedAt: row.playedAt));
        }
      }

      final currentItem = stateRow?.currentItemId == null
          ? null
          : await _itemById(stateRow!.currentItemId!);

      return PlayerControllerState(
        queue: queue,
        history: history,
        currentItem: currentItem,
        playbackMode: PlaybackMode.values.firstWhere(
          (mode) => mode.name == stateRow?.playbackMode,
          orElse: () => PlaybackMode.sequence,
        ),
        volume: stateRow?.volume ?? 100,
        lastPosition: Duration(milliseconds: stateRow?.lastPositionMs ?? 0),
        lastDuration: Duration(milliseconds: stateRow?.lastDurationMs ?? 0),
      );
    } catch (_) {
      return const PlayerControllerState();
    }
  }

  Future<void> save(PlayerControllerState state) async {
    await _legacyMigration?.ensureMigrated();
    await _database.transaction(() async {
      for (final item in <PlaybackItem>[
        ...state.queue,
        ...state.history.map((entry) => entry.item),
        if (state.currentItem != null) state.currentItem!,
      ]) {
        await _upsertItem(item);
      }

      await _database
          .into(_database.playerStateRows)
          .insert(
            db.PlayerStateRowsCompanion(
              id: const Value(1),
              currentItemId: Value(state.currentItem?.id),
              playbackMode: Value(state.playbackMode.name),
              volume: Value(state.volume),
              lastPositionMs: Value(state.lastPosition.inMilliseconds),
              lastDurationMs: Value(state.lastDuration.inMilliseconds),
            ),
            mode: InsertMode.insertOrReplace,
          );

      await _database.delete(_database.queueEntries).go();
      for (var index = 0; index < state.queue.length; index += 1) {
        await _database
            .into(_database.queueEntries)
            .insert(
              db.QueueEntriesCompanion(
                position: Value(index),
                itemId: Value(state.queue[index].id),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }

      await _database.delete(_database.playbackHistoryRows).go();
      for (final entry in state.history) {
        await _database
            .into(_database.playbackHistoryRows)
            .insert(
              db.PlaybackHistoryRowsCompanion.insert(
                itemId: entry.item.id,
                playedAt: entry.playedAt,
              ),
            );
      }
    });
  }

  Future<void> savePlaybackProgress(PlayerControllerState state) async {
    await _legacyMigration?.ensureMigrated();
    await _database.transaction(() async {
      final item = state.currentItem;
      if (item != null) {
        await _upsertItem(item);
      }
      await _database
          .into(_database.playerStateRows)
          .insert(
            db.PlayerStateRowsCompanion(
              id: const Value(1),
              currentItemId: Value(item?.id),
              playbackMode: Value(state.playbackMode.name),
              volume: Value(state.volume),
              lastPositionMs: Value(state.lastPosition.inMilliseconds),
              lastDurationMs: Value(state.lastDuration.inMilliseconds),
            ),
            mode: InsertMode.insertOrReplace,
          );
    });
  }

  Future<void> clearHistory() async {
    await _legacyMigration?.ensureMigrated();
    await _database.delete(_database.playbackHistoryRows).go();
  }

  Future<void> _upsertItem(PlaybackItem item) async {
    await _database
        .into(_database.playbackItems)
        .insert(_itemCompanion(item), mode: InsertMode.insertOrReplace);
  }

  Future<PlaybackItem?> _itemById(String id) async {
    final row = await (_database.select(
      _database.playbackItems,
    )..where((item) => item.id.equals(id))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _itemFromRow(row);
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
    final raw = _jsonMap(row.rawJson);
    return PlaybackItem(
      id: row.id,
      type: PlaybackItemType.values.firstWhere(
        (type) => type.name == row.type,
        orElse: () => PlaybackItemType.plugin,
      ),
      title: row.title,
      pluginId: PlaybackItem.pluginIdFromStorage(row.id, row.musicId),
      platform: row.platform,
      musicId: row.musicId,
      localPath: row.localPath,
      artist: row.artist,
      album: row.album,
      duration: row.durationMs == null
          ? null
          : Duration(milliseconds: row.durationMs!),
      artworkUrl: row.artworkUrl,
      raw: raw,
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
    } catch (_) {
      // Bad legacy JSON should not prevent playback state loading.
    }
    return const <String, Object?>{};
  }
}
