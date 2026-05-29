import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/storage/local_file_store.dart';
import 'package:robyne/features/player/application/player_state_repository.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/domain/playback_item.dart';

void main() {
  test('persists queue, history, playback mode, and volume', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_player_persistence_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final repository = PlayerStateRepository(
      fileStore: LocalFileStore(baseDirectory: tempDirectory),
    );
    final itemA = PlaybackItem.local(path: '${tempDirectory.path}/A.mp3');
    final itemB = PlaybackItem.plugin(
      platform: 'Test',
      musicId: 'B',
      title: 'B',
      raw: const <String, Object?>{'id': 'B'},
    );
    final state = PlayerControllerState(
      queue: <PlaybackItem>[itemA, itemB],
      history: <PlaybackHistoryEntry>[
        PlaybackHistoryEntry(item: itemA, playedAt: DateTime(2026)),
        PlaybackHistoryEntry(item: itemB, playedAt: DateTime(2026, 1, 2)),
      ],
      currentItem: itemB,
      playbackMode: PlaybackMode.random,
      volume: 42,
      lastPosition: const Duration(seconds: 73),
      lastDuration: const Duration(minutes: 4),
    );

    await repository.save(state);
    final loaded = await repository.load();

    expect(loaded.queue.map((item) => item.id), <String>[itemA.id, itemB.id]);
    expect(loaded.history.map((entry) => entry.item.id), <String>[
      itemA.id,
      itemB.id,
    ]);
    expect(loaded.currentItem?.id, itemB.id);
    expect(loaded.playbackMode, PlaybackMode.random);
    expect(loaded.volume, 42);
    expect(loaded.lastPosition, const Duration(seconds: 73));
    expect(loaded.lastDuration, const Duration(minutes: 4));
  });
}
