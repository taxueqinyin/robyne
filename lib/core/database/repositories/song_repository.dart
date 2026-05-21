import 'package:drift/drift.dart';
import 'package:robyne/core/database/app_database.dart';
import 'package:robyne/core/database/tables/songs.dart';

part 'song_repository.g.dart';

@DriftAccessor(tables: [Songs])
class SongRepository extends DatabaseAccessor<AppDatabase>
    with _$SongRepositoryMixin {
  SongRepository(super.db);

  Future<List<Song>> getAllSongs() => select(songs).get();

  Stream<List<Song>> watchAllSongs() => select(songs).watch();

  Future<Song?> getSongById(int id) =>
      (select(songs)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Song>> getSongsByPluginId(int pluginId) =>
      (select(songs)..where((t) => t.pluginId.equals(pluginId))).get();

  Future<List<Song>> getLocalSongs() =>
      (select(songs)..where((t) => t.isLocal.equals(true))).get();

  Stream<List<Song>> watchLocalSongs() =>
      (select(songs)..where((t) => t.isLocal.equals(true))).watch();

  Future<int> insertSong(SongsCompanion song) => into(songs).insert(song);

  Future<void> insertSongs(List<SongsCompanion> songList) =>
      batch((batch) => batch.insertAll(songs, songList));

  Future<bool> updateSong(SongsCompanion song) =>
      update(songs).replace(song);

  Future<int> deleteSong(int id) =>
      (delete(songs)..where((t) => t.id.equals(id))).go();

  Future<List<Song>> searchSongs(String query) => (select(songs)
        ..where(
          (t) =>
              t.title.like('%$query%') |
              t.artist.like('%$query%') |
              t.album.like('%$query%'),
        ))
      .get();
}
