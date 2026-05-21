import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:robyne/core/database/tables/playlist_songs.dart';
import 'package:robyne/core/database/tables/playlists.dart';
import 'package:robyne/core/database/tables/plugins.dart';
import 'package:robyne/core/database/tables/songs.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Plugins, Songs, Playlists, PlaylistSongs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Add migration logic here as schema evolves
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'robyne', 'robyne.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
