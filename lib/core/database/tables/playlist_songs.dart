import 'package:drift/drift.dart';
import 'package:robyne/core/database/tables/playlists.dart';
import 'package:robyne/core/database/tables/songs.dart';

class PlaylistSongs extends Table {
  IntColumn get playlistId => integer().references(Playlists, #id)();
  IntColumn get songId => integer().references(Songs, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {playlistId, songId};
}
