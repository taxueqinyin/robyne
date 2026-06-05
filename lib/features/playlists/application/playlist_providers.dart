import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/domain/playback_item.dart';
import '../../plugin/application/plugin_providers.dart';
import '../domain/music_playlist.dart';
import '../infrastructure/playlist_repository.dart';

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  return PlaylistRepository(
    database: ref.watch(appDatabaseProvider),
    legacyMigration: ref.watch(legacyStorageMigrationProvider),
  );
});

final playlistControllerProvider =
    AsyncNotifierProvider<PlaylistController, List<MusicPlaylist>>(
      PlaylistController.new,
    );

class PlaylistController extends AsyncNotifier<List<MusicPlaylist>> {
  @override
  Future<List<MusicPlaylist>> build() async {
    return ref.watch(playlistRepositoryProvider).listPlaylists();
  }

  Future<void> createPlaylist(String name) async {
    await ref.read(playlistRepositoryProvider).createPlaylist(name);
    ref.invalidateSelf();
  }

  Future<void> deletePlaylist(String id) async {
    await ref.read(playlistRepositoryProvider).deletePlaylist(id);
    ref.invalidateSelf();
  }

  Future<void> addItem(String playlistId, PlaybackItem item) async {
    await ref.read(playlistRepositoryProvider).addItem(playlistId, item);
    ref.invalidateSelf();
  }

  Future<void> removeItem(String playlistId, String itemId) async {
    await ref.read(playlistRepositoryProvider).removeItem(playlistId, itemId);
    ref.invalidateSelf();
  }

  Future<void> toggleFavorite(PlaybackItem item) async {
    await ref.read(playlistRepositoryProvider).toggleFavorite(item);
    ref.invalidateSelf();
  }
}
