import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../plugin/application/plugin_providers.dart';
import '../domain/user_settings.dart';
import '../infrastructure/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(
    database: ref.watch(appDatabaseProvider),
    fileStore: ref.watch(localFileStoreProvider),
    legacyMigration: ref.watch(legacyStorageMigrationProvider),
  );
});

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, UserSettings>(
      SettingsController.new,
    );

class SettingsController extends AsyncNotifier<UserSettings> {
  @override
  Future<UserSettings> build() async {
    return ref.watch(settingsRepositoryProvider).load();
  }

  Future<void> setCacheSizeBytes(int bytes) async {
    state = AsyncData(
      await ref.read(settingsRepositoryProvider).setCacheSizeBytes(bytes),
    );
  }

  Future<void> setCacheDirectory(String path) async {
    state = AsyncData(
      await ref.read(settingsRepositoryProvider).setCacheDirectory(path),
    );
  }

  Future<void> setDownloadsDirectory(String path) async {
    state = AsyncData(
      await ref.read(settingsRepositoryProvider).setDownloadsDirectory(path),
    );
  }
}
