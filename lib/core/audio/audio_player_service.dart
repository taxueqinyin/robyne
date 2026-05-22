import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:robyne/shared/models/track.dart';
import 'package:robyne/core/audio/playback_state.dart';
import 'package:logging/logging.dart';

class AudioPlayerService {
  final AudioPlayer _player;
  final _stateController = StreamController<PlaybackState>.broadcast();
  PlaybackState _state = const PlaybackState();

  final _log = Logger('AudioPlayerService');

  Stream<PlaybackState> get stateStream => _stateController.stream;
  PlaybackState get state => _state;

  AudioPlayerService() : _player = AudioPlayer() {
    // 初始化 media_kit Windows/Linux 支持
    JustAudioMediaKit.ensureInitialized();
    _init();
  }

  void _init() {
    _player.positionStream.listen((position) {
      _state = _state.copyWith(position: position);
      _emitState();
    });

    _player.durationStream.listen((duration) {
      _state = _state.copyWith(duration: duration);
      _emitState();
    });

    _player.playerStateStream.listen((playerState) {
      final status = _mapPlayerState(playerState);
      _state = _state.copyWith(status: status);
      _emitState();
    });

    _player.processingStateStream.listen((processingState) {
      if (processingState == ProcessingState.completed) {
        _onTrackCompleted();
      }
    });

    _player.playbackEventStream.listen((event) {
      // Errors are delivered via playbackEventStream or caught in try-catch
    }, onError: (Object error) {
      _log.warning('Audio player error: $error');
      _state = _state.copyWith(
        status: PlaybackStatus.error,
        errorMessage: error.toString(),
      );
      _emitState();
    });
  }

  PlaybackStatus _mapPlayerState(PlayerState playerState) {
    switch (playerState.processingState) {
      case ProcessingState.idle:
        return PlaybackStatus.idle;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        return PlaybackStatus.loading;
      case ProcessingState.ready:
        return playerState.playing
            ? PlaybackStatus.playing
            : PlaybackStatus.paused;
      case ProcessingState.completed:
        return PlaybackStatus.completed;
    }
  }

  Future<void> playTrack(Track track, {MediaSource? source}) async {
    try {
      _state = _state.copyWith(
        status: PlaybackStatus.loading,
        currentTrack: track,
        errorMessage: null,
      );
      _emitState();

      if (track is LocalTrack) {
        // 使用 Uri.file() 正确处理中文路径
        // Windows 上直接传路径会导致中文被 URL 编码
        final fileUri = Uri.file(track.path, windows: true);
        await _player.setUrl(fileUri.toString());
      } else if (track is RemoteTrack) {
        if (source == null) {
          throw ArgumentError('MediaSource is required for RemoteTrack');
        }
        final audioSource = AudioSource.uri(
          Uri.parse(source.url),
          headers: source.headers,
        );
        await _player.setAudioSource(audioSource);
      }

      await _player.play();
    } catch (e) {
      _log.warning('Failed to play track: $e');
      _state = _state.copyWith(
        status: PlaybackStatus.error,
        errorMessage: e.toString(),
      );
      _emitState();
    }
  }

  Future<void> play() async {
    _player.play();
  }

  Future<void> pause() async {
    _player.pause();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  double get volume => _player.volume;

  Future<void> playNext() async {
    final queue = _state.queue;
    final index = _state.queueIndex;
    if (queue.isEmpty || index == null) return;

    final nextIndex = index + 1;
    if (nextIndex < queue.length) {
      _state = _state.copyWith(queueIndex: nextIndex);
      _emitState();
      await playTrack(queue[nextIndex].track);
    } else if (_state.repeatMode == RepeatMode.off) {
      // Reached end of queue
      await stop();
    } else if (_state.repeatMode == RepeatMode.one) {
      // Repeat one: replay current
      await seek(Duration.zero);
      await play();
    }
  }

  Future<void> playPrevious() async {
    final queue = _state.queue;
    final index = _state.queueIndex;
    if (queue.isEmpty || index == null) return;

    // If more than 3 seconds in, restart current track
    final position = _state.position;
    if (position != null && position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    final prevIndex = index - 1;
    if (prevIndex >= 0) {
      _state = _state.copyWith(queueIndex: prevIndex);
      _emitState();
      await playTrack(queue[prevIndex].track);
    } else {
      await seek(Duration.zero);
    }
  }

  void setQueue(List<QueueItem> items, {int startIndex = 0}) {
    _state = _state.copyWith(
      queue: items,
      queueIndex: startIndex,
    );
    _emitState();
    if (items.isNotEmpty && startIndex < items.length) {
      playTrack(items[startIndex].track);
    }
  }

  void setRepeatMode(RepeatMode mode) {
    _state = _state.copyWith(repeatMode: mode);
    _emitState();
  }

  void _onTrackCompleted() {
    final queue = _state.queue;
    final index = _state.queueIndex;

    if (_state.repeatMode == RepeatMode.one) {
      _player.seek(Duration.zero);
      _player.play();
      return;
    }

    if (queue.isNotEmpty && index != null && index + 1 < queue.length) {
      playNext();
    } else {
      _state = _state.copyWith(status: PlaybackStatus.completed);
      _emitState();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _state = _state.copyWith(
      status: PlaybackStatus.idle,
      position: Duration.zero,
    );
    _emitState();
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _stateController.close();
  }

  void _emitState() {
    _stateController.add(_state);
  }
}
