import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/database/legacy_storage_migration.dart';
import '../../player/domain/playback_item.dart';
import '../domain/music_playlist.dart';

class PlaylistRepository {
  PlaylistRepository({
    required db.AppDatabase database,
    LegacyStorageMigration? legacyMigration,
  }) : _database = database,
       _legacyMigration = legacyMigration;

  static const favoritesId = 'favorites';

  final db.AppDatabase _database;
  final LegacyStorageMigration? _legacyMigration;

  Future<List<MusicPlaylist>> listPlaylists() async {
    await _legacyMigration?.ensureMigrated();
    await ensureFavoritesPlaylist();
    final rows =
        await (_database.select(_database.playlists)
              ..orderBy(<OrderingTerm Function(db.$PlaylistsTable)>[
                (row) => OrderingTerm.desc(row.isFavorites),
                (row) => OrderingTerm.asc(row.createdAt),
              ]))
            .get();
    final playlists = <MusicPlaylist>[];
    for (final row in rows) {
      playlists.add(
        MusicPlaylist(
          id: row.id,
          name: row.name,
          isFavorites: row.isFavorites,
          items: await itemsForPlaylist(row.id),
        ),
      );
    }
    return playlists;
  }

  Future<void> ensureFavoritesPlaylist() async {
    await _database
        .into(_database.playlists)
        .insert(
          db.PlaylistsCompanion(
            id: const Value(favoritesId),
            name: const Value('我喜欢'),
            isFavorites: const Value(true),
            createdAt: Value(DateTime.fromMillisecondsSinceEpoch(0)),
            updatedAt: Value(DateTime.now()),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<String> createPlaylist(String name) async {
    await _legacyMigration?.ensureMigrated();
    final id = 'playlist:${DateTime.now().microsecondsSinceEpoch}';
    await _database
        .into(_database.playlists)
        .insert(
          db.PlaylistsCompanion.insert(
            id: id,
            name: name.trim().isEmpty ? 'New playlist' : name.trim(),
            isFavorites: const Value(false),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return id;
  }

  Future<void> deletePlaylist(String id) async {
    await _legacyMigration?.ensureMigrated();
    if (id == favoritesId) {
      return;
    }
    await _database.transaction(() async {
      await (_database.delete(
        _database.playlistItems,
      )..where((row) => row.playlistId.equals(id))).go();
      await (_database.delete(
        _database.playlists,
      )..where((row) => row.id.equals(id))).go();
    });
  }

  Future<void> addItem(String playlistId, PlaybackItem item) async {
    await _legacyMigration?.ensureMigrated();
    await _upsertPlaybackItem(item);
    await _database
        .into(_database.playlistItems)
        .insert(
          db.PlaylistItemsCompanion(
            playlistId: Value(playlistId),
            itemId: Value(item.id),
            position: Value(await _nextPosition(playlistId)),
            addedAt: Value(DateTime.now()),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> removeItem(String playlistId, String itemId) async {
    await _legacyMigration?.ensureMigrated();
    await (_database.delete(_database.playlistItems)..where(
          (row) =>
              row.playlistId.equals(playlistId) & row.itemId.equals(itemId),
        ))
        .go();
  }

  Future<bool> isFavorite(String itemId) async {
    await _legacyMigration?.ensureMigrated();
    await ensureFavoritesPlaylist();
    final row =
        await (_database.select(_database.playlistItems)..where(
              (row) =>
                  row.playlistId.equals(favoritesId) &
                  row.itemId.equals(itemId),
            ))
            .getSingleOrNull();
    return row != null;
  }

  Future<void> toggleFavorite(PlaybackItem item) async {
    await _legacyMigration?.ensureMigrated();
    await ensureFavoritesPlaylist();
    if (await isFavorite(item.id)) {
      await removeItem(favoritesId, item.id);
    } else {
      await addItem(favoritesId, item);
    }
  }

  Future<List<PlaybackItem>> itemsForPlaylist(String playlistId) async {
    final rows =
        await (_database.select(_database.playlistItems)
              ..where((row) => row.playlistId.equals(playlistId))
              ..orderBy(<OrderingTerm Function(db.$PlaylistItemsTable)>[
                (row) => OrderingTerm.asc(row.position),
                (row) => OrderingTerm.asc(row.addedAt),
              ]))
            .get();
    final items = <PlaybackItem>[];
    for (final row in rows) {
      final item =
          await (_database.select(_database.playbackItems)
                ..where((playbackItem) => playbackItem.id.equals(row.itemId)))
              .getSingleOrNull();
      if (item != null) {
        items.add(_itemFromRow(item));
      }
    }
    return items;
  }

  Future<int> _nextPosition(String playlistId) async {
    final rows =
        await (_database.select(_database.playlistItems)
              ..where((row) => row.playlistId.equals(playlistId))
              ..orderBy(<OrderingTerm Function(db.$PlaylistItemsTable)>[
                (row) => OrderingTerm.desc(row.position),
              ])
              ..limit(1))
            .get();
    return rows.isEmpty ? 0 : rows.first.position + 1;
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
