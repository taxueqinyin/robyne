import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/database/app_database.dart' as db;
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/playlists/infrastructure/playlist_repository.dart';

void main() {
  test('creates playlists, dedupes items, and toggles favorites', () async {
    final database = db.AppDatabase.memory();
    addTearDown(database.close);
    final repository = PlaylistRepository(database: database);
    final item = PlaybackItem.plugin(
      platform: 'Test',
      musicId: 'A',
      title: 'A',
      raw: const <String, Object?>{'id': 'A'},
    );

    final playlistId = await repository.createPlaylist('Road');
    await repository.addItem(playlistId, item);
    await repository.addItem(playlistId, item);
    await repository.toggleFavorite(item);

    var playlists = await repository.listPlaylists();
    expect(
      playlists.singleWhere((playlist) => playlist.id == playlistId).items,
      hasLength(1),
    );
    expect(await repository.isFavorite(item.id), isTrue);

    await repository.toggleFavorite(item);
    playlists = await repository.listPlaylists();
    expect(await repository.isFavorite(item.id), isFalse);
    expect(playlists.first.isFavorites, isTrue);
  });
}
