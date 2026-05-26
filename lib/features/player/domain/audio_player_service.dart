import '../../../core/result/result.dart';
import 'media_source.dart';

abstract interface class AudioPlayerService {
  Stream<PlayerSnapshot> get snapshots;

  PlayerSnapshot get snapshot;

  Future<Result<void>> play(MediaSource source);

  Future<Result<void>> pause();

  Future<Result<void>> stop();

  Future<void> dispose();
}

class PlayerSnapshot {
  const PlayerSnapshot({
    this.playing = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.currentSource,
  });

  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration duration;
  final MediaSource? currentSource;

  PlayerSnapshot copyWith({
    bool? playing,
    bool? buffering,
    Duration? position,
    Duration? duration,
    MediaSource? currentSource,
  }) {
    return PlayerSnapshot(
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      currentSource: currentSource ?? this.currentSource,
    );
  }
}
