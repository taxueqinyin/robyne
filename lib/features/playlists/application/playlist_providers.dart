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

/// The playlist currently pinned into the playlists destination.
///
/// `null` is the liked-songs view. Selecting a row in the rail's playlist
/// group sets an id, so manual playlists have a real destination without
/// competing with the liked-songs entry above the divider.
final selectedPlaylistIdProvider =
    NotifierProvider<SelectedPlaylistIdNotifier, String?>(
      SelectedPlaylistIdNotifier.new,
    );

class SelectedPlaylistIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String id) => state = id;

  void showLiked() => state = null;

  /// The `playlists` tab with no specific playlist selected.
  ///
  /// `null` is reserved for the liked-songs view, so this sentinel gives the
  /// rail a way to open the overview without overloading that state.
  void showOverview() => state = overviewPlaylistId;

  /// The saved online collections view.
  void showCollections() => state = overviewCollectionsPlaylistId;
}

const overviewPlaylistId = '__overview__';
const overviewCollectionsPlaylistId = '__collections__';

/// A local collection saved from Discover.
///
/// The repository deliberately stores imported collections as ordinary
/// playlists. Their stable id prefix is the discriminator the UI needs, so no
/// migration or second persistence model is required.
const collectionPlaylistIdPrefix = 'collection:';

bool isCollectionPlaylistId(String id) =>
    id.startsWith(collectionPlaylistIdPrefix);

class PlaylistController extends AsyncNotifier<List<MusicPlaylist>> {
  @override
  Future<List<MusicPlaylist>> build() async {
    return ref.watch(playlistRepositoryProvider).listPlaylists();
  }

  Future<void> createPlaylist(String name) async {
    await ref.read(playlistRepositoryProvider).createPlaylist(name);
    ref.invalidateSelf();
  }

  Future<String> createImportedPlaylist({
    required String name,
    required List<PlaybackItem> items,
    String? id,
    DateTime? createdAt,
  }) async {
    final playlistId = await ref
        .read(playlistRepositoryProvider)
        .createImportedPlaylist(
          name: name,
          items: items,
          id: id,
          createdAt: createdAt,
        );
    ref.invalidateSelf();
    return playlistId;
  }

  Future<bool> containsPlaylistWithName(String name) {
    return ref.read(playlistRepositoryProvider).containsPlaylistWithName(name);
  }

  Future<String?> localPlaylistIdForImportedCollection(String collectionKey) {
    return ref
        .read(playlistRepositoryProvider)
        .localPlaylistIdForImportedCollection(collectionKey);
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
    if (ref.read(selectedPlaylistIdProvider) ==
        PlaylistRepository.favoritesId) {
      ref.read(selectedPlaylistIdProvider.notifier).showLiked();
    }
    ref.invalidateSelf();
  }

  Future<void> saveCollectionAsPlaylist({
    required String name,
    required List<PlaybackItem> items,
    required String collectionKey,
  }) async {
    await ref
        .read(playlistRepositoryProvider)
        .createImportedPlaylist(
          id: PlaylistRepository.importedPlaylistId(collectionKey),
          name: name,
          items: items,
        );
    ref.invalidateSelf();
  }
}
