import 'dart:async';

import 'package:media_kit/media_kit.dart' as media_kit;

import '../../../core/errors/app_error.dart';
import '../../../core/result/result.dart';
import '../domain/audio_player_service.dart';
import '../domain/media_source.dart';

class MediaKitAudioPlayerService implements AudioPlayerService {
  MediaKitAudioPlayerService() : _player = media_kit.Player() {
    _subscriptions.add(
      _player.stream.playing.listen(
        (playing) => _emit(_snapshot.copyWith(playing: playing)),
      ),
    );
    _subscriptions.add(
      _player.stream.buffering.listen(
        (buffering) => _emit(_snapshot.copyWith(buffering: buffering)),
      ),
    );
    _subscriptions.add(
      _player.stream.position.listen(
        (position) => _emit(_snapshot.copyWith(position: position)),
      ),
    );
    _subscriptions.add(
      _player.stream.duration.listen(
        (duration) => _emit(_snapshot.copyWith(duration: duration)),
      ),
    );
  }

  final media_kit.Player _player;
  final _controller = StreamController<PlayerSnapshot>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  PlayerSnapshot _snapshot = const PlayerSnapshot();

  @override
  PlayerSnapshot get snapshot => _snapshot;

  @override
  Stream<PlayerSnapshot> get snapshots async* {
    yield _snapshot;
    yield* _controller.stream;
  }

  @override
  Future<Result<void>> play(MediaSource source) async {
    try {
      _emit(_snapshot.copyWith(currentSource: source));
      await _player.open(
        media_kit.Media(source.url, httpHeaders: source.headers),
        play: true,
      );
      return const Ok(null);
    } catch (error, stackTrace) {
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
  Future<Result<void>> stop() async {
    try {
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
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _controller.close();
    await _player.dispose();
  }

  void _emit(PlayerSnapshot snapshot) {
    _snapshot = snapshot;
    if (!_controller.isClosed) {
      _controller.add(snapshot);
    }
  }
}
