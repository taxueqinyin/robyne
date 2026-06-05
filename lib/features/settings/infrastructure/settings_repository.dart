import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart' as db;
import '../../../core/database/legacy_storage_migration.dart';
import '../../../core/storage/local_file_store.dart';
import '../domain/user_settings.dart';

class SettingsRepository {
  SettingsRepository({
    required db.AppDatabase database,
    required LocalFileStore fileStore,
    LegacyStorageMigration? legacyMigration,
  }) : _database = database,
       _fileStore = fileStore,
       _legacyMigration = legacyMigration;

  static const defaultCacheSizeBytes = 1024 * 1024 * 1024;

  static const _cacheSizeKey = 'storage.cache_size_bytes';
  static const _cacheDirectoryKey = 'storage.cache_directory';
  static const _downloadsDirectoryKey = 'storage.downloads_directory';

  final db.AppDatabase _database;
  final LocalFileStore _fileStore;
  final LegacyStorageMigration? _legacyMigration;

  Future<UserSettings> load() async {
    await _legacyMigration?.ensureMigrated();
    final rows = await _database.select(_database.appSettings).get();
    final values = <String, String>{for (final row in rows) row.key: row.value};

    final defaultCacheDirectory = await _fileStore.cacheDirectory();
    final defaultDownloadsDirectory = await _fileStore.downloadsDirectory();
    final cacheDirectory = await _ensureDirectory(
      values[_cacheDirectoryKey],
      fallback: defaultCacheDirectory,
    );
    final downloadsDirectory = await _ensureDirectory(
      values[_downloadsDirectoryKey],
      fallback: defaultDownloadsDirectory,
    );
    if (values[_cacheDirectoryKey] != null &&
        values[_cacheDirectoryKey] != cacheDirectory.path) {
      await _write(_cacheDirectoryKey, cacheDirectory.path);
    }
    if (values[_downloadsDirectoryKey] != null &&
        values[_downloadsDirectoryKey] != downloadsDirectory.path) {
      await _write(_downloadsDirectoryKey, downloadsDirectory.path);
    }

    return UserSettings(
      cacheSizeBytes:
          int.tryParse(values[_cacheSizeKey] ?? '') ?? defaultCacheSizeBytes,
      cacheDirectoryPath: cacheDirectory.path,
      downloadsDirectoryPath: downloadsDirectory.path,
    );
  }

  Future<UserSettings> setCacheSizeBytes(int bytes) async {
    final sanitized = bytes
        .clamp(64 * 1024 * 1024, 50 * 1024 * 1024 * 1024)
        .toInt();
    await _write(_cacheSizeKey, sanitized.toString());
    return load();
  }

  Future<UserSettings> setCacheDirectory(String path) async {
    final directory = await _ensureDirectory(path);
    await _write(_cacheDirectoryKey, directory.path);
    return load();
  }

  Future<UserSettings> setDownloadsDirectory(String path) async {
    final directory = await _ensureDirectory(path);
    await _write(_downloadsDirectoryKey, directory.path);
    return load();
  }

  Future<void> _write(String key, String value) async {
    await _legacyMigration?.ensureMigrated();
    await _database
        .into(_database.appSettings)
        .insert(
          db.AppSettingsCompanion(key: Value(key), value: Value(value)),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<Directory> _ensureDirectory(
    String? path, {
    Directory? fallback,
  }) async {
    final rawPath = path?.trim();
    final normalizedPath = rawPath == null || rawPath.isEmpty
        ? null
        : p.normalize(rawPath);
    final directory = normalizedPath == null || normalizedPath.isEmpty
        ? fallback
        : Directory(normalizedPath);
    final resolved = directory ?? await _fileStore.supportDirectory();
    if (!await resolved.exists()) {
      await resolved.create(recursive: true);
    }
    return resolved;
  }
}
