import '../../../core/result/result.dart';
import 'media_source.dart';

abstract interface class AudioPlayerService {
  Stream<PlayerSnapshot> get snapshots;

  PlayerSnapshot get snapshot;

  Future<Result<void>> play(
    MediaSource source, {
    Duration startPosition = Duration.zero,
    Duration expectedDuration = Duration.zero,
  });

  Future<Result<void>> pause();

  Future<Result<void>> resume();

  Future<Result<void>> seek(Duration position);

  Future<Result<void>> setVolume(double volume);

  Future<Result<void>> stop();

  Future<void> dispose();
}

class PlayerSnapshot {
  const PlayerSnapshot({
    this.playing = false,
    this.buffering = false,
    this.completed = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 100,
    this.currentSource,
  });

  final bool playing;
  final bool buffering;
  final bool completed;
  final Duration position;
  final Duration duration;
  final double volume;
  final MediaSource? currentSource;

  PlayerSnapshot copyWith({
    bool? playing,
    bool? buffering,
    bool? completed,
    Duration? position,
    Duration? duration,
    double? volume,
    MediaSource? currentSource,
  }) {
    return PlayerSnapshot(
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      completed: completed ?? this.completed,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      currentSource: currentSource ?? this.currentSource,
    );
  }
}
