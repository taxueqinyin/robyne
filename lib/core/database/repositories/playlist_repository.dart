import 'package:drift/drift.dart';
import 'package:robyne/core/database/app_database.dart';
import 'package:robyne/core/database/tables/playlist_songs.dart';
import 'package:robyne/core/database/tables/playlists.dart';
import 'package:robyne/core/database/tables/songs.dart';

part 'playlist_repository.g.dart';

@DriftAccessor(tables: [Playlists, PlaylistSongs, Songs])
class PlaylistRepository extends DatabaseAccessor<AppDatabase>
    with _$PlaylistRepositoryMixin {
  PlaylistRepository(super.db);

  Future<List<Playlist>> getAllPlaylists() => select(playlists).get();

  Stream<List<Playlist>> watchAllPlaylists() => select(playlists).watch();

  Future<Playlist?> getPlaylistById(int id) =>
      (select(playlists)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertPlaylist(PlaylistsCompanion playlist) =>
      into(playlists).insert(playlist);

  Future<bool> updatePlaylist(PlaylistsCompanion playlist) =>
      update(playlists).replace(playlist);

  Future<int> deletePlaylist(int id) =>
      (delete(playlists)..where((t) => t.id.equals(id))).go();

  // Playlist Songs operations
  Future<List<Song>> getPlaylistSongs(int playlistId) async {
    final query = select(playlistSongs).join([
      innerJoin(songs, songs.id.equalsExp(playlistSongs.songId)),
    ])
      ..where(playlistSongs.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm.asc(playlistSongs.sortOrder)]);

    final results = await query.get();
    return results.map((row) => row.readTable(songs)).toList();
  }

  Future<int> addSongToPlaylist(int playlistId, int songId,
      {int sortOrder = 0}) {
    return into(playlistSongs).insert(PlaylistSongsCompanion(
      playlistId: Value(playlistId),
      songId: Value(songId),
      sortOrder: Value(sortOrder),
    ));
  }

  Future<int> removeSongFromPlaylist(int playlistId, int songId) {
    return (delete(playlistSongs)
          ..where(
            (t) =>
                t.playlistId.equals(playlistId) & t.songId.equals(songId),
          ))
        .go();
  }

  Future<int> clearPlaylist(int playlistId) {
    return (delete(playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId)))
        .go();
  }

  Future<int> reorderPlaylistSong(
      int playlistId, int songId, int newOrder) {
    return (update(playlistSongs)
          ..where(
            (t) =>
                t.playlistId.equals(playlistId) & t.songId.equals(songId),
          ))
        .write(PlaylistSongsCompanion(sortOrder: Value(newOrder)));
  }
}
