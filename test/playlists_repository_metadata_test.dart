import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/database/app_database.dart' show AppDatabase;
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/playlists/infrastructure/playlist_repository.dart';

void main() {
  test('playlist metadata is saved and returned from the database', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = PlaylistRepository(database: database);
    final id = await repository.createImportedPlaylist(
      name: '原名',
      description: '原简介',
      coverUrl: ' https://example.test/cover.png ',
      items: <PlaybackItem>[
        PlaybackItem.plugin(
          platform: 'Test',
          musicId: 'A',
          title: '第一首',
          raw: const <String, Object?>{'id': 'A'},
        ),
      ],
    );

    await repository.updatePlaylistInfo(
      id,
      name: '新名字',
      description: '新简介',
      coverUrl: 'https://example.test/new.png',
    );

    final playlist = (await repository.listPlaylists()).singleWhere(
      (candidate) => candidate.id == id,
    );
    expect(playlist.name, '新名字');
    expect(playlist.description, '新简介');
    expect(playlist.coverUrl, 'https://example.test/new.png');
    expect(playlist.items, hasLength(1));
  });
}
