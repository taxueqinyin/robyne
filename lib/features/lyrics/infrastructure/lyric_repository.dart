import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/database/legacy_storage_migration.dart';
import '../../player/domain/playback_item.dart';
import '../domain/lyric_document.dart';

class LyricRepository {
  LyricRepository({
    required db.AppDatabase database,
    LegacyStorageMigration? legacyMigration,
  }) : _database = database,
       _legacyMigration = legacyMigration;

  final db.AppDatabase _database;
  final LegacyStorageMigration? _legacyMigration;

  Future<LyricDocument?> loadForItem(PlaybackItem item) async {
    await _legacyMigration?.ensureMigrated();
    final offset = await offsetForItem(item.id);
    if (item.isLocal && item.localPath != null) {
      final embedded = await _embeddedLyric(item.localPath!);
      if (embedded != null) {
        return LyricDocument.parse(
          embedded,
          sourceType: LyricSourceType.embedded,
          offset: offset,
        );
      }

      final sidecar = await _sidecarLyric(item.localPath!);
      if (sidecar != null) {
        return LyricDocument.parse(
          sidecar,
          sourceType: LyricSourceType.sidecar,
          offset: offset,
        );
      }
    }

    final preference = await (_database.select(
      _database.lyricPreferences,
    )..where((row) => row.itemId.equals(item.id))).getSingleOrNull();
    if (preference == null) {
      return null;
    }

    final associatedPath = preference.associatedPath;
    if (associatedPath != null && associatedPath.isNotEmpty) {
      final file = File(associatedPath);
      if (await file.exists()) {
        return LyricDocument.parse(
          await file.readAsString(),
          sourceType: LyricSourceType.localAssociation,
          offset: offset,
        );
      }
    }

    final rawLyric = preference.rawLyric;
    if (rawLyric != null && rawLyric.trim().isNotEmpty) {
      return LyricDocument.parse(
        rawLyric,
        sourceType: LyricSourceType.plugin,
        offset: offset,
      );
    }
    return null;
  }

  Future<Duration> offsetForItem(String itemId) async {
    await _legacyMigration?.ensureMigrated();
    final row =
        await (_database.select(_database.lyricPreferences)
              ..where((preference) => preference.itemId.equals(itemId)))
            .getSingleOrNull();
    return Duration(milliseconds: row?.offsetMs ?? 0);
  }

  Future<void> setOffset(PlaybackItem item, Duration offset) async {
    await _legacyMigration?.ensureMigrated();
    await _upsertPlaybackItem(item);
    await _database
        .into(_database.lyricPreferences)
        .insert(
          db.LyricPreferencesCompanion(
            itemId: Value(item.id),
            offsetMs: Value(offset.inMilliseconds),
            updatedAt: Value(DateTime.now()),
          ),
          onConflict: DoUpdate(
            (old) => db.LyricPreferencesCompanion.custom(
              offsetMs: Constant(offset.inMilliseconds),
              updatedAt: Constant(DateTime.now()),
            ),
          ),
        );
  }

  Future<void> associateLocalFile(PlaybackItem item, String path) async {
    await _legacyMigration?.ensureMigrated();
    await _upsertPlaybackItem(item);
    await _database
        .into(_database.lyricPreferences)
        .insert(
          db.LyricPreferencesCompanion(
            itemId: Value(item.id),
            sourceType: const Value('localAssociation'),
            associatedPath: Value(path),
            rawLyric: const Value(null),
            pluginPlatform: const Value(null),
            pluginItemRawJson: const Value(null),
            updatedAt: Value(DateTime.now()),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> associatePluginLyric({
    required PlaybackItem item,
    required String rawLyric,
    required String pluginPlatform,
    required Map<String, Object?> pluginRaw,
  }) async {
    await _legacyMigration?.ensureMigrated();
    await _upsertPlaybackItem(item);
    final currentOffset = await offsetForItem(item.id);
    await _database
        .into(_database.lyricPreferences)
        .insert(
          db.LyricPreferencesCompanion(
            itemId: Value(item.id),
            sourceType: const Value('plugin'),
            associatedPath: const Value(null),
            pluginPlatform: Value(pluginPlatform),
            pluginItemRawJson: Value(jsonEncode(pluginRaw)),
            rawLyric: Value(rawLyric),
            offsetMs: Value(currentOffset.inMilliseconds),
            updatedAt: Value(DateTime.now()),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> clearAssociation(PlaybackItem item) async {
    await _legacyMigration?.ensureMigrated();
    await (_database.delete(
      _database.lyricPreferences,
    )..where((row) => row.itemId.equals(item.id))).go();
  }

  Future<String?> _embeddedLyric(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return null;
      }
      if (await file.length() < 128) {
        return null;
      }
      final metadata = readMetadata(file, getImage: false);
      final lyric = metadata.lyrics;
      return lyric == null || lyric.trim().isEmpty ? null : lyric;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _sidecarLyric(String path) async {
    final file = File(path);
    final parent = file.parent;
    if (!await parent.exists()) {
      return null;
    }
    final base = _baseName(file.uri.pathSegments.last).toLowerCase();
    final exactCandidates = <File>[
      File('${parent.path}/$base.lrc'),
      File('${parent.path}/$base.txt'),
    ];
    for (final candidate in exactCandidates) {
      if (await candidate.exists()) {
        return candidate.readAsString();
      }
    }
    await for (final entity in parent.list()) {
      if (entity is! File) {
        continue;
      }
      final name = entity.uri.pathSegments.last.toLowerCase();
      if (name == '$base.lrc' || name == '$base.txt') {
        return entity.readAsString();
      }
    }
    return null;
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

  static String _baseName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot <= 0 ? fileName : fileName.substring(0, dot);
  }
}
