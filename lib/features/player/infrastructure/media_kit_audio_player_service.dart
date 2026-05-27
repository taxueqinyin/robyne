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

  media_kit.Player _player;
  final _controller = StreamController<PlayerSnapshot>.broadcast();
  var _subscriptions = <StreamSubscription<Object?>>[];
  PlayerSnapshot _snapshot = const PlayerSnapshot();
  int _operationId = 0;

  @override
  PlayerSnapshot get snapshot => _snapshot;

  @override
  Stream<PlayerSnapshot> get snapshots async* {
    yield _snapshot;
    yield* _controller.stream;
  }

  @override
  Future<Result<void>> play(MediaSource source) async {
    final operationId = _operationId + 1;
    _operationId = operationId;
    try {
      final player = await _replacePlayer();
      if (!_isCurrentOperation(operationId)) {
        return const Ok(null);
      }
      _emit(_snapshot.copyWith(currentSource: source));
      await player.open(
        media_kit.Media(source.url, httpHeaders: source.headers),
        play: true,
      );
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
  Future<Result<void>> stop() async {
    final operationId = _operationId + 1;
    _operationId = operationId;
    try {
      final player = await _replacePlayer();
      if (!_isCurrentOperation(operationId)) {
        return const Ok(null);
      }
      await player.stop();
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
      player.stream.position.listen(
        (position) => _emit(_snapshot.copyWith(position: position)),
      ),
    );
    _subscriptions.add(
      player.stream.duration.listen(
        (duration) => _emit(_snapshot.copyWith(duration: duration)),
      ),
    );
  }

  Future<media_kit.Player> _replacePlayer() async {
    final oldPlayer = _player;
    final oldSubscriptions = _subscriptions;
    final nextPlayer = media_kit.Player();
    _subscriptions = <StreamSubscription<Object?>>[];
    _player = nextPlayer;
    _bindPlayer(nextPlayer);

    for (final subscription in oldSubscriptions) {
      await subscription.cancel();
    }
    await oldPlayer.dispose();
    return nextPlayer;
  }

  bool _isCurrentOperation(int operationId) {
    return _operationId == operationId;
  }

  void _emit(PlayerSnapshot snapshot) {
    _snapshot = snapshot;
    if (!_controller.isClosed) {
      _controller.add(snapshot);
    }
  }
}
