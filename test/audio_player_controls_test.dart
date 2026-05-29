import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/player/domain/audio_player_service.dart';
import 'package:robyne/features/player/domain/media_source.dart';

void main() {
  test('audio service exposes seek, volume, and completion state', () async {
    final service = _RecordingAudioPlayerService();

    await service.seek(const Duration(seconds: 42));
    await service.setVolume(35);
    service.emit(
      const PlayerSnapshot(
        completed: true,
        volume: 35,
        duration: Duration(minutes: 3),
      ),
    );

    expect(service.seekedTo, const Duration(seconds: 42));
    expect(service.volumeSetTo, 35);
    expect(service.snapshot.completed, isTrue);
    expect(service.snapshot.volume, 35);
  });

  test('player snapshot defaults expose volume and completion state', () {
    const snapshot = PlayerSnapshot();

    expect(snapshot.completed, isFalse);
    expect(snapshot.volume, 100);
  });
}

class _RecordingAudioPlayerService implements AudioPlayerService {
  PlayerSnapshot _snapshot = const PlayerSnapshot();
  Duration? seekedTo;
  double? volumeSetTo;

  @override
  PlayerSnapshot get snapshot => _snapshot;

  @override
  Stream<PlayerSnapshot> get snapshots async* {
    yield _snapshot;
  }

  void emit(PlayerSnapshot snapshot) {
    _snapshot = snapshot;
  }

  @override
  Future<Result<void>> play(
    MediaSource source, {
    Duration startPosition = Duration.zero,
    Duration expectedDuration = Duration.zero,
  }) async => const Ok(null);

  @override
  Future<Result<void>> pause() async => const Ok(null);

  @override
  Future<Result<void>> resume() async => const Ok(null);

  @override
  Future<Result<void>> seek(Duration position) async {
    seekedTo = position;
    return const Ok(null);
  }

  @override
  Future<Result<void>> setVolume(double volume) async {
    volumeSetTo = volume;
    return const Ok(null);
  }

  @override
  Future<Result<void>> stop() async => const Ok(null);

  @override
  Future<void> dispose() async {}
}
