import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:robyne/core/database/app_database.dart' as db;
import 'package:robyne/core/storage/local_file_store.dart';
import 'package:robyne/features/settings/infrastructure/settings_repository.dart';

void main() {
  test('loads defaults and persists storage settings', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_settings_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final database = db.AppDatabase.memory();
    addTearDown(database.close);
    final repository = SettingsRepository(
      database: database,
      fileStore: LocalFileStore(baseDirectory: tempDirectory),
    );

    final initial = await repository.load();
    expect(initial.cacheSizeBytes, SettingsRepository.defaultCacheSizeBytes);
    expect(initial.cacheDirectoryPath, endsWith('cache'));
    expect(initial.downloadsDirectoryPath, endsWith('downloads'));

    final customCache = Directory(p.join(tempDirectory.path, 'custom-cache'));
    final customDownloads = Directory(
      p.join(tempDirectory.path, 'custom-downloads'),
    );
    await repository.setCacheSizeBytes(256 * 1024 * 1024);
    await repository.setCacheDirectory(customCache.path);
    await repository.setDownloadsDirectory(customDownloads.path);

    final saved = await repository.load();
    expect(saved.cacheSizeBytes, 256 * 1024 * 1024);
    expect(saved.cacheDirectoryPath, customCache.path);
    expect(saved.downloadsDirectoryPath, customDownloads.path);
    expect(await customCache.exists(), isTrue);
    expect(await customDownloads.exists(), isTrue);
  });

  test('normalizes stored Windows-style storage paths', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_settings_path_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final database = db.AppDatabase.memory();
    addTearDown(database.close);
    final repository = SettingsRepository(
      database: database,
      fileStore: LocalFileStore(baseDirectory: tempDirectory),
    );

    final mixedCachePath = '${tempDirectory.path}/mixed-cache';
    await repository.setCacheDirectory(mixedCachePath);

    final saved = await repository.load();
    expect(saved.cacheDirectoryPath, p.normalize(mixedCachePath));
  });
}
