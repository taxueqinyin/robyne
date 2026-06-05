import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../plugin/application/plugin_providers.dart';
import '../../player/domain/playback_item.dart';
import '../infrastructure/local_music_repository.dart';

final localMusicRepositoryProvider = Provider<LocalMusicRepository>((ref) {
  return LocalMusicRepository(
    fileStore: ref.watch(localFileStoreProvider),
    database: ref.watch(appDatabaseProvider),
    legacyMigration: ref.watch(legacyStorageMigrationProvider),
  );
});

final localMusicLibraryProvider =
    AsyncNotifierProvider<LocalMusicLibraryController, List<PlaybackItem>>(
      LocalMusicLibraryController.new,
    );

class LocalMusicLibraryController extends AsyncNotifier<List<PlaybackItem>> {
  @override
  Future<List<PlaybackItem>> build() async {
    final result = await ref.watch(localMusicRepositoryProvider).listTracks();
    return result.fold((tracks) => tracks, (error) => throw error);
  }

  Future<Object?> importFiles(List<String> paths) async {
    final result = await ref
        .read(localMusicRepositoryProvider)
        .importFiles(paths);
    return result.fold((_) {
      ref.invalidateSelf();
      return null;
    }, (error) => error);
  }

  Future<Object?> importFolder(String path) async {
    final result = await ref
        .read(localMusicRepositoryProvider)
        .importFolder(path);
    return result.fold((_) {
      ref.invalidateSelf();
      return null;
    }, (error) => error);
  }

  Future<Object?> remove(String id) async {
    final result = await ref.read(localMusicRepositoryProvider).removeTrack(id);
    return result.fold((_) {
      ref.invalidateSelf();
      return null;
    }, (error) => error);
  }
}
