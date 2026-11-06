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

  /// SQLite builds before 3.32 allow 999 bound variables per statement.
  static const int _queryBatchSize = 500;

  final db.AppDatabase _database;
  final LegacyStorageMigration? _legacyMigration;

  /// Loads every playlist and its tracks in a fixed number of queries.
  ///
  /// The association rows keep the authoritative order, while the playback
  /// rows are fetched once and decoded once per unique song. Sharing a song
  /// between playlists must produce two references to the same list position
  /// without a second database lookup or JSON decode.
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
    final associations = await _allPlaylistAssociations();
    final referencedIds = <String>{
      for (final association in associations) association.itemId,
    };
    final playbackRows = await _playbackItemsById(referencedIds);
    final itemsById = <String, PlaybackItem>{
      for (final row in playbackRows) row.id: _itemFromRow(row),
    };
    final grouped = <String, List<PlaybackItem>>{};
    for (final association in associations) {
      final item = itemsById[association.itemId];
      if (item != null) {
        (grouped[association.playlistId] ??= <PlaybackItem>[]).add(item);
      }
    }
    return <MusicPlaylist>[
      for (final row in rows)
        MusicPlaylist(
          id: row.id,
          name: row.name,
          description: row.description,
          coverUrl: row.coverUrl,
          isFavorites: row.isFavorites,
          items: grouped[row.id] ?? const <PlaybackItem>[],
        ),
    ];
  }

  Future<List<db.PlaybackItem>> _playbackItemsById(Set<String> ids) async {
    if (ids.isEmpty) {
      return const <db.PlaybackItem>[];
    }
    final idList = ids.toList(growable: false);
    final rows = <db.PlaybackItem>[];
    for (var start = 0; start < idList.length; start += _queryBatchSize) {
      final chunk = idList.skip(start).take(_queryBatchSize).toList();
      rows.addAll(
        await (_database.select(
          _database.playbackItems,
        )..where((row) => row.id.isIn(chunk))).get(),
      );
    }
    return rows;
  }

  Future<List<db.PlaylistItem>> _allPlaylistAssociations() {
    return (_database.select(_database.playlistItems)
          ..orderBy(<OrderingTerm Function(db.$PlaylistItemsTable)>[
            (row) => OrderingTerm.asc(row.playlistId),
            (row) => OrderingTerm.asc(row.position),
            (row) => OrderingTerm.asc(row.addedAt),
          ]))
        .get();
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
    return createImportedPlaylist(name: name, items: const <PlaybackItem>[]);
  }

  /// Creates a normal local playlist and inserts the supplied tracks.
  ///
  /// Imported collections use the same tables and same rows as a playlist the
  /// user created by hand; there is no second "online collection" type to
  /// special-case later.
  Future<String> createImportedPlaylist({
    required String name,
    required List<PlaybackItem> items,
    String? id,
    DateTime? createdAt,
    String description = '',
    String? coverUrl,
  }) async {
    await _legacyMigration?.ensureMigrated();
    final playlistId =
        id ?? 'playlist:${DateTime.now().microsecondsSinceEpoch}';
    final now = createdAt ?? DateTime.now();
    await _database.transaction(() async {
      await _database
          .into(_database.playlists)
          .insert(
            db.PlaylistsCompanion.insert(
              id: playlistId,
              name: name.trim().isEmpty ? 'New playlist' : name.trim(),
              description: Value(description.trim()),
              coverUrl: Value(_trimmedOrNull(coverUrl)),
              isFavorites: const Value(false),
              createdAt: Value(now),
              updatedAt: Value(DateTime.now()),
            ),
            mode: InsertMode.insertOrReplace,
          );
      for (var index = 0; index < items.length; index += 1) {
        final item = items[index];
        await _upsertPlaybackItem(item);
        await _database
            .into(_database.playlistItems)
            .insert(
              db.PlaylistItemsCompanion(
                playlistId: Value(playlistId),
                itemId: Value(item.id),
                position: Value(index),
                addedAt: Value(DateTime.now()),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
    return playlistId;
  }

  /// Copies any legacy favourite-collection pointers into ordinary local
  /// playlists.
  ///
  /// The old store kept a plugin id and a raw payload, not the tracks. A
  /// migration at this layer cannot call the plugin, so it leaves those rows
  /// untouched; the live favourite action now writes `PlaylistItems`, which is
  /// the one local source of truth this page reads.
  Future<void> ensureFavoritesPlaylistContains(
    String playlistId,
    List<PlaybackItem> items,
  ) async {
    for (final item in items) {
      await addItem(playlistId, item);
    }
  }

  Future<bool> containsPlaylistWithName(String name) async {
    await _legacyMigration?.ensureMigrated();
    final normalized = name.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final row =
        await (_database.select(_database.playlists)
              ..where((row) => row.name.equals(normalized))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  Future<String?> localPlaylistIdForImportedCollection(
    String collectionKey,
  ) async {
    await _legacyMigration?.ensureMigrated();
    final row =
        await (_database.select(_database.playlists)
              ..where(
                (row) => row.id.equals(_importedPlaylistId(collectionKey)),
              )
              ..limit(1))
            .getSingleOrNull();
    return row?.id;
  }

  static String importedPlaylistId(String collectionKey) =>
      _importedPlaylistId(collectionKey);

  static String _importedPlaylistId(String collectionKey) {
    var hash = 2166136261;
    for (final unit in collectionKey.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }
    return 'collection:${hash.toRadixString(16)}';
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
    await removeItems(playlistId, <String>{itemId});
  }

  Future<void> removeItems(String playlistId, Set<String> itemIds) async {
    await _legacyMigration?.ensureMigrated();
    if (itemIds.isEmpty) {
      return;
    }
    await (_database.delete(_database.playlistItems)..where(
          (row) => row.playlistId.equals(playlistId) & row.itemId.isIn(itemIds),
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
    final associations =
        await (_database.select(_database.playlistItems)
              ..where((row) => row.playlistId.equals(playlistId))
              ..orderBy(<OrderingTerm Function(db.$PlaylistItemsTable)>[
                (row) => OrderingTerm.asc(row.position),
                (row) => OrderingTerm.asc(row.addedAt),
              ]))
            .get();
    if (associations.isEmpty) {
      return const <PlaybackItem>[];
    }
    final ids = associations.map((row) => row.itemId).toSet();
    final playbackRows = await _playbackItemsById(ids);
    final itemsById = <String, PlaybackItem>{
      for (final row in playbackRows) row.id: _itemFromRow(row),
    };
    return <PlaybackItem>[
      for (final association in associations) ?itemsById[association.itemId],
    ];
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

  Future<void> updatePlaylistInfo(
    String id, {
    required String name,
    required String description,
    String? coverUrl,
  }) async {
    final normalizedName = name.trim();
    await (_database.update(
      _database.playlists,
    )..where((row) => row.id.equals(id))).write(
      db.PlaylistsCompanion(
        name: Value(normalizedName.isEmpty ? 'New playlist' : normalizedName),
        description: Value(description.trim()),
        coverUrl: Value(_trimmedOrNull(coverUrl)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  static String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
