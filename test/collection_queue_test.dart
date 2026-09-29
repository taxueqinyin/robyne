import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robyne/core/database/app_database.dart' as db;
import 'package:robyne/features/discover/domain/online_collection.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/playlists/infrastructure/playlist_repository.dart';

import 'support/fake_audio_player_service.dart';

/// Guards the "play a whole collection" behaviour: appending must keep what is
/// playing, replacing must drop it, and both must land the whole track list in
/// the queue rather than only the first track.
void main() {
  late Directory tempDirectory;
  late ProviderContainer container;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('robyne_queue_');
    container = ProviderContainer(
      overrides: [
        audioPlayerServiceProvider.overrideWithValue(FakeAudioPlayerService()),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await tempDirectory.delete(recursive: true);
    });
  });

  /// Local items resolve without a plugin, so these tests exercise the queue
  /// arithmetic rather than the plugin runtime.
  Future<PlaybackItem> item(String name) async {
    final file = File('${tempDirectory.path}/$name.mp3');
    await file.writeAsBytes(<int>[1, 2, 3]);
    return PlaybackItem.local(path: file.path);
  }

  test('enqueueItems appends without disturbing the current queue', () async {
    final controller = container.read(playerControllerProvider.notifier);
    await controller.replaceQueueWithItems(<PlaybackItem>[
      await item('a'),
      await item('b'),
    ]);
    await controller.enqueueItems(<PlaybackItem>[
      await item('c'),
      await item('d'),
    ]);

    final queue = container.read(playerControllerProvider).value!.queue;
    expect(queue.map((entry) => entry.title).toList(), <String>[
      'a',
      'b',
      'c',
      'd',
    ]);
  });

  test('replaceQueueWithItems drops the previous queue', () async {
    final controller = container.read(playerControllerProvider.notifier);
    await controller.replaceQueueWithItems(<PlaybackItem>[
      await item('a'),
      await item('b'),
    ]);
    await controller.replaceQueueWithItems(<PlaybackItem>[
      await item('c'),
      await item('d'),
    ]);

    final state = container.read(playerControllerProvider).value!;
    expect(state.queue.map((entry) => entry.title).toList(), <String>[
      'c',
      'd',
    ]);
    expect(state.currentItem?.title, 'c');
  });

  test('enqueueItems starts playback when the queue was empty', () async {
    final controller = container.read(playerControllerProvider.notifier);
    await controller.enqueueItems(<PlaybackItem>[await item('a')]);

    final state = container.read(playerControllerProvider).value!;
    // An append into an empty queue is the one case where nothing would play
    // afterwards if the first track were not selected.
    expect(state.queue.length, 1);
    expect(state.currentItem?.title, 'a');
  });

  test(
    'a favourited collection is stored as an ordinary local playlist',
    () async {
      final database = db.AppDatabase.memory();
      addTearDown(database.close);
      final playlists = PlaylistRepository(database: database);
      final collection = OnlineCollectionItem(
        id: 'sheet-1',
        pluginId: 'plugin-a',
        platform: 'Source',
        kind: OnlineCollectionKind.musicSheet,
        title: 'Saved sheet',
        raw: const <String, Object?>{'id': 'sheet-1'},
      );
      final items = <PlaybackItem>[
        PlaybackItem.plugin(
          platform: 'Source',
          musicId: 'one',
          title: 'One',
          raw: const <String, Object?>{'id': 'one'},
        ),
        PlaybackItem.plugin(
          platform: 'Source',
          musicId: 'two',
          title: 'Two',
          raw: const <String, Object?>{'id': 'two'},
        ),
      ];

      await playlists.createImportedPlaylist(
        id: PlaylistRepository.importedPlaylistId(collection.uniqueKey),
        name: collection.title,
        items: items,
      );

      final stored = (await playlists.listPlaylists()).singleWhere(
        (playlist) =>
            playlist.id ==
            PlaylistRepository.importedPlaylistId(collection.uniqueKey),
      );
      expect(stored.name, 'Saved sheet');
      expect(stored.isFavorites, isFalse);
      expect(stored.items.map((item) => item.id), items.map((item) => item.id));
    },
  );
}
