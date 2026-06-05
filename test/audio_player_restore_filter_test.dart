import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/features/player/domain/audio_player_service.dart';
import 'package:robyne/features/player/domain/media_source.dart';
import 'package:robyne/features/player/infrastructure/media_kit_audio_player_service.dart';

void main() {
  test(
    'restore filter keeps expected duration during zero duration events',
    () {
      const source = MediaSource(url: 'cached.mp3');
      final filter = RestoreSnapshotFilter(
        source: source,
        startPosition: const Duration(seconds: 50),
        expectedDuration: const Duration(minutes: 3),
      );

      final initial = filter.apply(const PlayerSnapshot());
      expect(initial.currentSource, source);
      expect(initial.position, const Duration(seconds: 50));
      expect(initial.duration, const Duration(minutes: 3));

      final zeroDuration = filter.apply(
        const PlayerSnapshot(
          currentSource: source,
          position: Duration(seconds: 51),
        ),
      );
      expect(zeroDuration.position, const Duration(seconds: 50));
      expect(zeroDuration.duration, const Duration(minutes: 3));
    },
  );

  test('restore filter holds saved position until seek completes', () {
    const source = MediaSource(url: 'cached.mp3');
    final filter = RestoreSnapshotFilter(
      source: source,
      startPosition: const Duration(seconds: 50),
      expectedDuration: const Duration(minutes: 3),
    );

    final earlyForwardEvent = filter.apply(
      const PlayerSnapshot(
        currentSource: source,
        position: Duration(seconds: 51),
        duration: Duration(minutes: 3),
      ),
    );
    expect(earlyForwardEvent.position, const Duration(seconds: 50));

    filter.markSeekCompleted();
    final playingEvent = filter.apply(
      const PlayerSnapshot(
        currentSource: source,
        position: Duration(seconds: 51),
        duration: Duration(minutes: 3),
      ),
    );
    expect(playingEvent.position, const Duration(seconds: 51));
  });
}
