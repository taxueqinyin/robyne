import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/player/domain/playback_item.dart';
import '../../features/plugin/domain/plugin_definition.dart';
import '../storage/local_file_store.dart';
import 'app_database.dart' as db;

class LegacyStorageMigration {
  LegacyStorageMigration({
    required db.AppDatabase database,
    required LocalFileStore fileStore,
    required SharedPreferencesAsync? preferences,
  }) : _database = database,
       _fileStore = fileStore,
       _preferences = preferences;

  static const _migrationKey = 'legacy_storage_migrated.v1';
  static const _pluginsKey = 'plugins.v1';

  final db.AppDatabase _database;
  final LocalFileStore _fileStore;
  final SharedPreferencesAsync? _preferences;
  Future<void>? _migration;

  Future<void> ensureMigrated() {
    return _migration ??= _migrate();
  }

  Future<void> _migrate() async {
    final alreadyMigrated = await (_database.select(
      _database.appSettings,
    )..where((row) => row.key.equals(_migrationKey))).getSingleOrNull();
    if (alreadyMigrated?.value == 'true') {
      return;
    }

    await _database.transaction(() async {
      await _migratePlugins();
      await _migrateLocalMusic();
      await _migrateAudioCache();
      await _migratePlayerState();
      await _database
          .into(_database.appSettings)
          .insert(
            const db.AppSettingsCompanion(
              key: Value(_migrationKey),
              value: Value('true'),
            ),
            mode: InsertMode.insertOrReplace,
          );
    });
  }

  Future<void> _migratePlugins() async {
    final preferences = _preferences;
    if (preferences == null) {
      return;
    }
    final raw = await preferences.getString(_pluginsKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    final decoded = _decodeJson(raw);
    if (decoded is! List) {
      return;
    }
    for (final value in decoded.whereType<Map>()) {
      try {
        final plugin = PluginDefinition.fromJson(_objectMap(value));
        await _database
            .into(_database.pluginDefinitionRows)
            .insert(_pluginCompanion(plugin), mode: InsertMode.insertOrReplace);
      } catch (_) {
        // Ignore malformed legacy entries so one bad plugin doesn't block boot.
      }
    }
  }

  Future<void> _migrateLocalMusic() async {
    final file = await _dataFile('local_music.v1.json');
    final decoded = await _decodeJsonFile(file);
    if (decoded is! List) {
      return;
    }
    for (final value in decoded.whereType<Map>()) {
      try {
        final item = PlaybackItem.fromJson(_objectMap(value));
        await _upsertPlaybackItem(item);
        await _database
            .into(_database.localLibraryTracks)
            .insert(
              db.LocalLibraryTracksCompanion(
                itemId: Value(item.id),
                addedAt: Value(DateTime.now()),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      } catch (_) {
        // Skip malformed legacy tracks and keep migrating the rest.
      }
    }
  }

  Future<void> _migrateAudioCache() async {
    final file = await _cacheFile('audio_cache.v1.json');
    final decoded = await _decodeJsonFile(file);
    if (decoded is! List) {
      return;
    }
    for (final value in decoded.whereType<Map>()) {
      try {
        final raw = _objectMap(value);
        final itemId = raw['itemId']?.toString();
        if (itemId == null || itemId.isEmpty) {
          continue;
        }
        await _upsertPlaybackItem(_placeholderItem(itemId));
        await _database
            .into(_database.audioCacheEntries)
            .insert(
              db.AudioCacheEntriesCompanion(
                itemId: Value(itemId),
                sourceUrl: Value(raw['sourceUrl']?.toString() ?? ''),
                path: Value(raw['path']?.toString() ?? ''),
                size: Value(_intValue(raw['size']) ?? 0),
                createdAt: Value(_dateValue(raw['createdAt'])),
                lastAccessedAt: Value(_dateValue(raw['lastAccessedAt'])),
              ),
              mode: InsertMode.insertOrReplace,
            );
      } catch (_) {
        // Skip malformed legacy cache rows and keep migrating the rest.
      }
    }
  }

  Future<void> _migratePlayerState() async {
    final file = await _dataFile('player_state.v1.json');
    final decoded = await _decodeJsonFile(file);
    if (decoded is! Map) {
      return;
    }
    final raw = _objectMap(decoded);
    final queue = _playbackItems(raw['queue']);
    final history = _historyEntries(raw['history']);
    final currentItem = raw['currentItem'] is Map
        ? _playbackItemOrNull(raw['currentItem'] as Map)
        : null;

    for (final item in <PlaybackItem>[
      ...queue,
      ...history.map((entry) => entry.item),
      ?currentItem,
    ]) {
      await _upsertPlaybackItem(item);
    }

    await _database.delete(_database.queueEntries).go();
    for (var index = 0; index < queue.length; index += 1) {
      await _database
          .into(_database.queueEntries)
          .insert(
            db.QueueEntriesCompanion(
              position: Value(index),
              itemId: Value(queue[index].id),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }

    await _database.delete(_database.playbackHistoryRows).go();
    for (final entry in history) {
      await _database
          .into(_database.playbackHistoryRows)
          .insert(
            db.PlaybackHistoryRowsCompanion.insert(
              itemId: entry.item.id,
              playedAt: entry.playedAt,
            ),
          );
    }

    await _database
        .into(_database.playerStateRows)
        .insert(
          db.PlayerStateRowsCompanion(
            id: const Value(1),
            currentItemId: Value(currentItem?.id),
            playbackMode: Value(
              raw['playbackMode']?.toString().isNotEmpty == true
                  ? raw['playbackMode'].toString()
                  : 'sequence',
            ),
            volume: Value(
              raw['volume'] is num ? (raw['volume']! as num).toDouble() : 100,
            ),
            lastPositionMs: Value(_intValue(raw['lastPositionMs']) ?? 0),
            lastDurationMs: Value(_intValue(raw['lastDurationMs']) ?? 0),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<Object?> _decodeJsonFile(File file) async {
    try {
      if (!await file.exists()) {
        return null;
      }
      return _decodeJson(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  Object? _decodeJson(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<File> _dataFile(String fileName) async {
    return File('${(await _fileStore.dataDirectory()).path}/$fileName');
  }

  Future<File> _cacheFile(String fileName) async {
    return File('${(await _fileStore.cacheDirectory()).path}/$fileName');
  }

  Future<void> _upsertPlaybackItem(PlaybackItem item) async {
    await _database
        .into(_database.playbackItems)
        .insert(_playbackItemCompanion(item), mode: InsertMode.insertOrReplace);
  }

  static db.PlaybackItemsCompanion _playbackItemCompanion(PlaybackItem item) {
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

  static db.PluginDefinitionRowsCompanion _pluginCompanion(
    PluginDefinition plugin,
  ) {
    return db.PluginDefinitionRowsCompanion(
      id: Value(plugin.id),
      platform: Value(plugin.platform),
      version: Value(plugin.version),
      author: Value(plugin.author),
      description: Value(plugin.description),
      sourcePath: Value(plugin.sourcePath),
      enabled: Value(plugin.enabled),
      installedAt: Value(plugin.installedAt),
      updatedAt: Value(plugin.updatedAt),
      supportedSearchTypesJson: Value(jsonEncode(plugin.supportedSearchTypes)),
      userVariablesJson: Value(jsonEncode(plugin.userVariables)),
      userVariableValuesJson: Value(jsonEncode(plugin.userVariableValues)),
    );
  }

  static PlaybackItem _placeholderItem(String id) {
    final parts = id.split(':');
    if (parts.length >= 3 && parts.first == 'plugin') {
      return PlaybackItem.plugin(
        platform: parts[1],
        musicId: parts.sublist(2).join(':'),
        title: parts.sublist(2).join(':'),
        raw: const <String, Object?>{},
      );
    }
    return PlaybackItem(
      id: id,
      type: PlaybackItemType.local,
      title: id,
      raw: const <String, Object?>{},
    );
  }

  static List<PlaybackItem> _playbackItems(Object? value) {
    if (value is! List) {
      return const <PlaybackItem>[];
    }
    return value
        .whereType<Map>()
        .map(_playbackItemOrNull)
        .whereType<PlaybackItem>()
        .toList(growable: false);
  }

  static List<PlaybackHistoryEntry> _historyEntries(Object? value) {
    if (value is! List) {
      return const <PlaybackHistoryEntry>[];
    }
    return value
        .whereType<Map>()
        .map(_historyEntryOrNull)
        .whereType<PlaybackHistoryEntry>()
        .toList(growable: false);
  }

  static PlaybackItem? _playbackItemOrNull(Map<dynamic, dynamic> value) {
    try {
      return PlaybackItem.fromJson(_objectMap(value));
    } catch (_) {
      return null;
    }
  }

  static PlaybackHistoryEntry? _historyEntryOrNull(
    Map<dynamic, dynamic> value,
  ) {
    try {
      return PlaybackHistoryEntry.fromJson(_objectMap(value));
    } catch (_) {
      return null;
    }
  }

  static int? _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static DateTime _dateValue(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static Map<String, Object?> _objectMap(Map<dynamic, dynamic> value) {
    return value.map(
      (key, dynamic mapValue) => MapEntry(key.toString(), mapValue as Object?),
    );
  }
}
