import 'dart:async';

import 'package:media_kit/media_kit.dart' as media_kit;

import '../../../core/errors/app_error.dart';
import '../../../core/result/result.dart';
import '../domain/audio_player_service.dart';
import '../domain/media_source.dart';

class MediaKitAudioPlayerService implements AudioPlayerService {
  MediaKitAudioPlayerService() : _player = media_kit.Player() {
    _bindPlayer(_player);
  }

  final media_kit.Player _player;
  final _controller = StreamController<PlayerSnapshot>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  PlayerSnapshot _snapshot = const PlayerSnapshot();
  int _operationId = 0;
  RestoreSnapshotFilter? _restoreFilter;
  double? _queuedVolume;
  bool _volumeWriteInFlight = false;

  @override
  PlayerSnapshot get snapshot => _snapshot;

  @override
  Stream<PlayerSnapshot> get snapshots async* {
    yield _snapshot;
    yield* _controller.stream;
  }

  @override
  Future<Result<void>> play(
    MediaSource source, {
    Duration startPosition = Duration.zero,
    Duration expectedDuration = Duration.zero,
  }) async {
    final operationId = _operationId + 1;
    _operationId = operationId;
    try {
      final player = _player;
      if (!_isCurrentOperation(operationId)) {
        return const Ok(null);
      }
      _restoreFilter = RestoreSnapshotFilter(
        source: source,
        startPosition: startPosition,
        expectedDuration: expectedDuration,
      );
      _emit(
        _snapshot.copyWith(
          currentSource: source,
          completed: false,
          position: startPosition,
        ),
      );
      await player.open(
        media_kit.Media(source.url, httpHeaders: source.headers),
        play: startPosition <= Duration.zero,
      );
      if (!_isCurrentOperation(operationId)) {
        return const Ok(null);
      }
      if (startPosition > Duration.zero) {
        await _seekWhenReady(player, startPosition, operationId);
        if (!_isCurrentOperation(operationId)) {
          return const Ok(null);
        }
        _restoreFilter?.markSeekCompleted();
        _emit(_snapshot.copyWith(position: startPosition, completed: false));
        await player.play();
        _emit(_snapshot.copyWith(playing: true));
      }
      return const Ok(null);
    } catch (error, stackTrace) {
      if (!_isCurrentOperation(operationId)) {
        return const Ok(null);
      }
      return Failure(
        AppError(
          code: 'player.play_failed',
          message: 'Failed to play media source.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> pause() async {
    try {
      await _player.pause();
      _emit(_snapshot.copyWith(playing: false));
      return const Ok(null);
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'player.play_failed',
          message: 'Failed to pause playback.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> resume() async {
    try {
      await _player.play();
      _emit(_snapshot.copyWith(playing: true));
      return const Ok(null);
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'player.play_failed',
          message: 'Failed to resume playback.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> seek(Duration position) async {
    try {
      await _player.seek(position);
      _emit(_snapshot.copyWith(position: position, completed: false));
      return const Ok(null);
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'player.play_failed',
          message: 'Failed to seek playback.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> setVolume(double volume) async {
    final normalized = volume.clamp(0, 100).toDouble();
    if (_volumeWriteInFlight) {
      // Latest value wins: dropping intermediate frames keeps a fast drag
      // from queueing one platform round trip per pointer event.
      _queuedVolume = normalized;
      return const Ok(null);
    }
    _volumeWriteInFlight = true;
    try {
      var next = normalized;
      while (true) {
        await _player.setVolume(next);
        if (_snapshot.volume != next) {
          _emit(_snapshot.copyWith(volume: next));
        }
        final queued = _queuedVolume;
        _queuedVolume = null;
        if (queued == null || queued == next) {
          break;
        }
        next = queued;
      }
      return const Ok(null);
    } catch (error, stackTrace) {
      _queuedVolume = null;
      return Failure(
        AppError(
          code: 'player.play_failed',
          message: 'Failed to set playback volume.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      _volumeWriteInFlight = false;
    }
  }

  @override
  Future<Result<void>> stop() async {
    final operationId = _operationId + 1;
    _operationId = operationId;
    try {
      _restoreFilter = null;
      if (!_isCurrentOperation(operationId)) {
        return const Ok(null);
      }
      await _player.stop();
      _emit(const PlayerSnapshot());
      return const Ok(null);
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'player.play_failed',
          message: 'Failed to stop playback.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<void> dispose() async {
    _operationId += 1;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _controller.close();
    await _player.dispose();
  }

  void _bindPlayer(media_kit.Player player) {
    _subscriptions.add(
      player.stream.playing.listen(
        (playing) => _emit(_snapshot.copyWith(playing: playing)),
      ),
    );
    _subscriptions.add(
      player.stream.buffering.listen(
        (buffering) => _emit(_snapshot.copyWith(buffering: buffering)),
      ),
    );
    _subscriptions.add(
      player.stream.completed.listen(
        (completed) => _emit(_snapshot.copyWith(completed: completed)),
      ),
    );
    _subscriptions.add(
      player.stream.position.listen(
        (position) => _emit(_snapshot.copyWith(position: position)),
      ),
    );
    _subscriptions.add(
      player.stream.duration.listen(
        (duration) => _emit(_snapshot.copyWith(duration: duration)),
      ),
    );
    _subscriptions.add(
      player.stream.volume.listen(
        (volume) => _emit(_snapshot.copyWith(volume: volume)),
      ),
    );
  }

  Future<void> _seekWhenReady(
    media_kit.Player player,
    Duration position,
    int operationId,
  ) async {
    for (var attempt = 0; attempt < 20; attempt += 1) {
      if (!_isCurrentOperation(operationId)) {
        return;
      }
      if (player.state.duration > Duration.zero || attempt >= 2) {
        await player.seek(position);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await player.seek(position);
  }

  bool _isCurrentOperation(int operationId) {
    return _operationId == operationId;
  }

  void _emit(PlayerSnapshot snapshot) {
    final nextSnapshot = _restoreFilter?.apply(snapshot) ?? snapshot;
    _snapshot = nextSnapshot;
    if (!_controller.isClosed) {
      _controller.add(nextSnapshot);
    }
  }
}

class RestoreSnapshotFilter {
  RestoreSnapshotFilter({
    required this.source,
    required this.startPosition,
    required this.expectedDuration,
  }) : _waitingForRestoredPosition = startPosition > Duration.zero;

  final MediaSource source;
  final Duration startPosition;
  final Duration expectedDuration;
  bool _waitingForRestoredPosition;

  void markSeekCompleted() {
    _waitingForRestoredPosition = false;
  }

  PlayerSnapshot apply(PlayerSnapshot snapshot) {
    final duration =
        snapshot.duration > Duration.zero || expectedDuration <= Duration.zero
        ? snapshot.duration
        : expectedDuration;
    var position = snapshot.position;
    if (_waitingForRestoredPosition) {
      position = startPosition;
    }
    return snapshot.copyWith(
      currentSource: snapshot.currentSource ?? source,
      position: position,
      duration: duration,
    );
  }
}
