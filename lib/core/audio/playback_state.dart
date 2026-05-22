import 'package:robyne/shared/models/track.dart';

/// 播放状态枚举
enum PlaybackStatus {
  idle,
  loading,
  playing,
  paused,
  completed,
  error,
}

/// 循环模式
enum RepeatMode {
  off,
  one,
  // 不做 random
}

/// 播放状态
class PlaybackState {
  final PlaybackStatus status;
  final Track? currentTrack;
  final Duration? position;
  final Duration? duration;
  final RepeatMode repeatMode;
  final List<QueueItem> queue;
  final int? queueIndex;
  final String? errorMessage;

  const PlaybackState({
    this.status = PlaybackStatus.idle,
    this.currentTrack,
    this.position,
    this.duration,
    this.repeatMode = RepeatMode.off,
    this.queue = const [],
    this.queueIndex,
    this.errorMessage,
  });

  PlaybackState copyWith({
    PlaybackStatus? status,
    Track? currentTrack,
    Duration? position,
    Duration? duration,
    RepeatMode? repeatMode,
    List<QueueItem>? queue,
    int? queueIndex,
    String? errorMessage,
  }) {
    return PlaybackState(
      status: status ?? this.status,
      currentTrack: currentTrack ?? this.currentTrack,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      repeatMode: repeatMode ?? this.repeatMode,
      queue: queue ?? this.queue,
      queueIndex: queueIndex ?? this.queueIndex,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
