import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/domain/audio_player_service.dart';
import 'package:robyne/features/player/domain/media_source.dart';
import 'package:robyne/features/player/domain/playback_item.dart';

import 'support/fake_audio_player_service.dart';

/// Guards the "play next" menu action: queueing a track behind the current
/// one must never restart what is playing.
void main() {
  late Directory tempDirectory;
  late ProviderContainer container;
  late FakeAudioPlayerService audio;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('robyne_play_next_');
    audio = FakeAudioPlayerService();
    container = ProviderContainer(
      overrides: [audioPlayerServiceProvider.overrideWithValue(audio)],
    );
    addTearDown(() async {
      container.dispose();
      await tempDirectory.delete(recursive: true);
    });
  });

  Future<PlaybackItem> item(String name) async {
    final file = File('${tempDirectory.path}/$name.mp3');
    await file.writeAsBytes(<int>[1, 2, 3]);
    return PlaybackItem.local(path: file.path);
  }

  test(
    'insertAfterCurrent queues the next track without restarting playback',
    () async {
      final controller = container.read(playerControllerProvider.notifier);
      final first = await item('a');
      final second = await item('b');
      final third = await item('c');
      await controller.replaceQueueWithItems(<PlaybackItem>[first, second]);
      audio.emit(
        const PlayerSnapshot(
          currentSource: MediaSource(url: 'stub://a'),
          playing: true,
          position: Duration(seconds: 30),
          duration: Duration(minutes: 4),
        ),
      );
      await controller.insertAfterCurrent(third);

      final state = container.read(playerControllerProvider).value!;
      expect(state.queue.map((entry) => entry.title), <String>['a', 'c', 'b']);
      expect(state.currentItem?.title, 'a');
      // The audio engine never saw a stop/reload: only a queue write happened.
      expect(audio.stopCount, 1);
      expect(audio.playedUrls, hasLength(1));
    },
  );
}
