import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:robyne/core/database/app_database.dart';
import 'package:robyne/core/database/repositories/plugin_repository.dart';
import 'package:robyne/core/database/repositories/playlist_repository.dart';
import 'package:robyne/core/database/repositories/song_repository.dart';

part 'database_provider.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDatabase(AppDatabaseRef ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
}

@Riverpod(keepAlive: true)
PluginRepository pluginRepository(PluginRepositoryRef ref) {
  return PluginRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
SongRepository songRepository(SongRepositoryRef ref) {
  return SongRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
PlaylistRepository playlistRepository(PlaylistRepositoryRef ref) {
  return PlaylistRepository(ref.watch(appDatabaseProvider));
}
