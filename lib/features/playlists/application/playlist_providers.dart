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

  /// Applies a mutation result to the already-loaded snapshot.
  ///
  /// A reload is only needed before the first build or after an error. Keeping
  /// the other playlists and their decoded tracks intact is what makes a
  /// favourite toggle or one-row deletion cheap on large libraries.
  void _patch(
    List<MusicPlaylist> Function(List<MusicPlaylist> playlists) patch,
  ) {
    final current = state;
    if (current case AsyncData<List<MusicPlaylist>>(:final value)) {
      state = AsyncData<List<MusicPlaylist>>(patch(value));
    } else {
      ref.invalidateSelf();
    }
  }

  List<MusicPlaylist> _replace(
    List<MusicPlaylist> playlists,
    String id,
    MusicPlaylist Function(MusicPlaylist playlist) update,
  ) {
    return <MusicPlaylist>[
      for (final playlist in playlists)
        if (playlist.id == id) update(playlist) else playlist,
    ];
  }

  Future<void> createPlaylist(String name) async {
    await createImportedPlaylist(name: name, items: const <PlaybackItem>[]);
  }

  Future<String> createImportedPlaylist({
    required String name,
    required List<PlaybackItem> items,
    String? id,
    DateTime? createdAt,
    String description = '',
    String? coverUrl,
  }) async {
    final repository = ref.read(playlistRepositoryProvider);
    final playlistId = await repository.createImportedPlaylist(
      name: name,
      items: items,
      id: id,
      createdAt: createdAt,
      description: description,
      coverUrl: coverUrl,
    );
    final created = MusicPlaylist(
      id: playlistId,
      name: name.trim().isEmpty ? 'New playlist' : name.trim(),
      description: description.trim(),
      coverUrl: _trimmedOrNull(coverUrl),
      isFavorites: false,
      items: List<PlaybackItem>.unmodifiable(items),
    );
    _patch(
      (playlists) => <MusicPlaylist>[
        ...playlists.where((playlist) => playlist.id != playlistId),
        created,
      ],
    );
    return playlistId;
  }

  Future<void> updatePlaylistInfo(
    String id, {
    required String name,
    required String description,
    String? coverUrl,
  }) async {
    final normalizedName = name.trim().isEmpty ? 'New playlist' : name.trim();
    final normalizedDescription = description.trim();
    final normalizedCover = _trimmedOrNull(coverUrl);
    await ref
        .read(playlistRepositoryProvider)
        .updatePlaylistInfo(
          id,
          name: normalizedName,
          description: normalizedDescription,
          coverUrl: normalizedCover,
        );
    _patch(
      (playlists) => _replace(
        playlists,
        id,
        (playlist) => playlist.copyWith(
          name: normalizedName,
          description: normalizedDescription,
          coverUrl: normalizedCover,
        ),
      ),
    );
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
    if (id == PlaylistRepository.favoritesId) {
      return;
    }
    await ref.read(playlistRepositoryProvider).deletePlaylist(id);
    _patch(
      (playlists) => playlists
          .where((playlist) => playlist.id != id)
          .toList(growable: false),
    );
  }

  Future<void> addItem(String playlistId, PlaybackItem item) async {
    final repository = ref.read(playlistRepositoryProvider);
    final alreadyAdded = await repository
        .itemsForPlaylist(playlistId)
        .then((items) => items.any((candidate) => candidate.id == item.id));
    if (alreadyAdded) {
      return;
    }
    await repository.addItem(playlistId, item);
    _patch(
      (playlists) => _replace(
        playlists,
        playlistId,
        (playlist) =>
            playlist.copyWith(items: <PlaybackItem>[...playlist.items, item]),
      ),
    );
  }

  Future<void> removeItem(String playlistId, String itemId) =>
      removeItems(playlistId, <String>{itemId});

  Future<void> toggleFavorite(PlaybackItem item) async {
    final repository = ref.read(playlistRepositoryProvider);
    final wasFavorite = await repository.isFavorite(item.id);
    await repository.toggleFavorite(item);
    if (ref.read(selectedPlaylistIdProvider) ==
        PlaylistRepository.favoritesId) {
      ref.read(selectedPlaylistIdProvider.notifier).showLiked();
    }
    _patch(
      (playlists) => _replace(
        playlists,
        PlaylistRepository.favoritesId,
        (playlist) => playlist.copyWith(
          items: wasFavorite
              ? playlist.items
                    .where((candidate) => candidate.id != item.id)
                    .toList(growable: false)
              : <PlaybackItem>[...playlist.items, item],
        ),
      ),
    );
  }

  Future<void> saveCollectionAsPlaylist({
    required String name,
    required List<PlaybackItem> items,
    required String collectionKey,
    String description = '',
    String? coverUrl,
  }) => createImportedPlaylist(
    id: PlaylistRepository.importedPlaylistId(collectionKey),
    name: name,
    items: items,
    description: description,
    coverUrl: coverUrl,
  );

  Future<void> removeItems(String playlistId, Set<String> itemIds) async {
    if (itemIds.isEmpty) {
      return;
    }
    await ref.read(playlistRepositoryProvider).removeItems(playlistId, itemIds);
    _patch(
      (playlists) => _replace(
        playlists,
        playlistId,
        (playlist) => playlist.copyWith(
          items: playlist.items
              .where((item) => !itemIds.contains(item.id))
              .toList(growable: false),
        ),
      ),
    );
  }
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
