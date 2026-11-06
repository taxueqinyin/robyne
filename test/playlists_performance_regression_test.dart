import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/database/app_database.dart' show AppDatabase;
import 'package:robyne/core/database/legacy_storage_migration.dart';
import 'package:robyne/core/storage/local_file_store.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/core/theme/domain/theme_layout_override.dart';
import 'package:robyne/features/downloads/domain/download_audio_format.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/playlists/application/playlist_providers.dart';
import 'package:robyne/features/playlists/domain/music_playlist.dart';
import 'package:robyne/features/playlists/infrastructure/playlist_repository.dart';
import 'package:robyne/features/playlists/presentation/playlists_page.dart';
import 'package:robyne/features/plugin/application/plugin_providers.dart';
import 'package:robyne/features/settings/application/settings_providers.dart';
import 'package:robyne/features/settings/domain/lyric_settings.dart';
import 'package:robyne/features/settings/domain/shortcut_settings.dart';
import 'package:robyne/features/settings/domain/user_settings.dart';

import 'support/xuan_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('one full list read preserves order and shared decoded songs', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = PlaylistRepository(database: database);
    final first = _song('first', 'First');
    final second = _song('second', 'Second');
    final third = _song('third', 'Third');

    final left = await repository.createImportedPlaylist(
      id: 'playlist:left',
      name: 'Left',
      items: <PlaybackItem>[second, first, third],
    );
    final right = await repository.createImportedPlaylist(
      id: 'playlist:right',
      name: 'Right',
      items: <PlaybackItem>[third, second],
    );

    final playlists = await repository.listPlaylists();
    final leftItems = playlists
        .singleWhere((playlist) => playlist.id == left)
        .items;
    final rightItems = playlists
        .singleWhere((playlist) => playlist.id == right)
        .items;
    expect(leftItems.map((item) => item.id).toList(), <String>[
      second.id,
      first.id,
      third.id,
    ]);
    expect(rightItems.map((item) => item.id).toList(), <String>[
      third.id,
      second.id,
    ]);
    expect(leftItems.first.raw, isA<Map<String, Object?>>());
    expect(await repository.itemsForPlaylist(left), hasLength(3));

    final manySongs = <PlaybackItem>[
      for (var index = 0; index < 1100; index++)
        _song('bulk-$index', 'Bulk $index'),
    ];
    final bulk = await repository.createImportedPlaylist(
      id: 'playlist:bulk',
      name: 'Bulk',
      items: manySongs,
    );
    final bulkItems = (await repository.listPlaylists())
        .singleWhere((playlist) => playlist.id == bulk)
        .items;
    expect(bulkItems, hasLength(manySongs.length));
    expect(bulkItems.last.id, manySongs.last.id);
    expect(
      await repository.itemsForPlaylist(bulk),
      hasLength(manySongs.length),
    );
  });

  test('controller mutations patch the loaded snapshot', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = PlaylistRepository(database: database);
    final migration = LegacyStorageMigration(
      database: database,
      fileStore: LocalFileStore(),
      preferences: null,
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        legacyStorageMigrationProvider.overrideWithValue(migration),
        playlistRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final item = _song('cache-item', 'Cache item');
    final playlistId = await repository.createImportedPlaylist(
      id: 'playlist:cache',
      name: 'Before',
      description: 'Old description',
      items: <PlaybackItem>[item],
    );
    await container.read(playlistControllerProvider.future);
    final controller = container.read(playlistControllerProvider.notifier);

    await controller.updatePlaylistInfo(
      playlistId,
      name: ' After ',
      description: ' New description ',
      coverUrl: ' https://example.test/cover.png ',
    );
    var playlist = container
        .read(playlistControllerProvider)
        .requireValue
        .singleWhere((candidate) => candidate.id == playlistId);
    expect(playlist.name, 'After');
    expect(playlist.description, 'New description');
    expect(playlist.coverUrl, 'https://example.test/cover.png');

    final added = _song('added', 'Added');
    await controller.addItem(playlistId, added);
    playlist = container
        .read(playlistControllerProvider)
        .requireValue
        .singleWhere((candidate) => candidate.id == playlistId);
    expect(playlist.items.map((candidate) => candidate.id), <String>[
      item.id,
      added.id,
    ]);

    await controller.removeItems(playlistId, <String>{item.id});
    playlist = container
        .read(playlistControllerProvider)
        .requireValue
        .singleWhere((candidate) => candidate.id == playlistId);
    expect(playlist.items.map((candidate) => candidate.id), <String>[added.id]);

    final stored = (await repository.listPlaylists()).singleWhere(
      (candidate) => candidate.id == playlistId,
    );
    expect(stored.name, 'After');
    expect(stored.description, 'New description');
    expect(stored.items.map((candidate) => candidate.id), <String>[added.id]);
  });

  testWidgets('detail rows are built lazily for a large playlist', (
    tester,
  ) async {
    const int count = 1200;
    final items = <PlaybackItem>[
      for (var index = 0; index < count; index++)
        _song('song-$index', 'Song $index'),
    ];
    final playlist = MusicPlaylist(
      id: 'playlist:large',
      name: 'Large playlist',
      isFavorites: false,
      items: items,
    );
    final container = ProviderContainer(
      overrides: [
        baseThemePackageProvider.overrideWithValue(xuanFixture()),
        settingsControllerProvider.overrideWith(_FakeSettingsController.new),
        playlistControllerProvider.overrideWith(
          () => _SeededController(<MusicPlaylist>[playlist]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: PlaylistsPage())),
      ),
    );
    container
        .read(selectedPlaylistIdProvider.notifier)
        .select('playlist:large');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final mountedRows = <String>{};
    for (final widget in tester.allWidgets) {
      final key = widget.key;
      if (key is ValueKey<String> &&
          key.value.startsWith(playlistTrackKeyPrefix)) {
        mountedRows.add(key.value);
      }
    }
    expect(mountedRows.length, greaterThan(0));
    expect(mountedRows.length, lessThan(30));
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

PlaybackItem _song(String musicId, String title) {
  return PlaybackItem.plugin(
    platform: 'Test',
    musicId: musicId,
    title: title,
    raw: <String, Object?>{'id': musicId, 'title': title},
  );
}

class _SeededController extends PlaylistController {
  _SeededController(this._playlists);

  final List<MusicPlaylist> _playlists;

  @override
  Future<List<MusicPlaylist>> build() async => _playlists;
}

class _FakeSettingsController extends SettingsController {
  @override
  Future<UserSettings> build() async => UserSettings(
    cacheSizeBytes: 0,
    cacheDirectoryPath: 'cache',
    downloadsDirectoryPath: 'downloads',
    downloadAudioFormat: DownloadAudioFormat.original,
    shortcuts: ShortcutSettings.defaults(),
    lyricSettings: const LyricSettings.defaults(),
    activeThemeId: 'xuan',
    themeModeOverrideName: 'system',
    themeSettingValues: const <String, Object>{},
    themeLayoutOverrides: const <String, ThemeLayoutOverride>{},
  );
}
