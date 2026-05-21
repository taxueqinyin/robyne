import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:robyne/core/audio/audio_service_handler.dart';
import 'package:robyne/core/audio/playback_queue.dart';
import 'package:robyne/shared/models/song_model.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

part 'audio_player_service.g.dart';

@Riverpod(keepAlive: true)
class AudioPlayerService extends _$AudioPlayerService {
  late AudioServiceHandler _handler;
  late PlaybackQueue _queue;
  StreamSubscription<dynamic>? _playerStateSub;
  StreamSubscription<dynamic>? _positionSub;
  StreamSubscription<dynamic>? _durationSub;

  @override
  AudioPlayerState build() {
    _queue = PlaybackQueue();
    _initAudioService();

    ref.onDispose(() {
      _playerStateSub?.cancel();
      _positionSub?.cancel();
      _durationSub?.cancel();
      _handler.dispose();
      _saveQueueState();
    });

    return AudioPlayerState.initial();
  }

  Future<void> _initAudioService() async {
    _handler = await AudioService.init<AudioServiceHandler>(
      builder: () => AudioServiceHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.robyne.audio',
        androidNotificationChannelName: 'Robyne Audio',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );

    _playerStateSub = _handler.player.playerStateStream.listen((playerState) {
      state = state.copyWith(
        isPlaying: playerState.playing,
        processingState: _mapProcessingState(playerState.processingState),
      );

      if (playerState.processingState == ProcessingState.completed) {
        _handlePlaybackCompleted();
      }
    });

    _positionSub = _handler.player.positionStream.listen((position) {
      state = state.copyWith(position: position);
    });

    _durationSub = _handler.player.durationStream.listen((duration) {
      if (duration != null) {
        state = state.copyWith(duration: duration);
      }
    });

    await _restoreQueueState();
  }

  AudioProcessingState _mapProcessingState(ProcessingState processingState) {
    switch (processingState) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  void _handlePlaybackCompleted() {
    final nextSong = _queue.next();
    if (nextSong != null) {
      playSong(nextSong);
    } else {
      state = state.copyWith(isPlaying: false);
    }
  }

  Future<void> playSong(SongModel song) async {
    state = state.copyWith(
      currentSong: song,
      processingState: AudioProcessingState.loading,
    );

    try {
      if (song.isLocal && song.localPath != null) {
        await _handler.setFilePath(
          song.localPath!,
          title: song.title,
          artist: song.artist,
          artUri: song.coverLocal ?? song.coverUrl,
        );
      } else if (song.audioUrl != null) {
        await _handler.setUrl(
          song.audioUrl!,
          title: song.title,
          artist: song.artist,
          artUri: song.coverUrl,
        );
      } else {
        state = state.copyWith(
          processingState: AudioProcessingState.idle,
          error: 'No audio source available',
        );
        return;
      }

      await _handler.play();
      _saveQueueState();
    } catch (e) {
      state = state.copyWith(
        processingState: AudioProcessingState.idle,
        error: e.toString(),
      );
    }
  }

  Future<void> play() async {
    await _handler.play();
  }

  Future<void> pause() async {
    await _handler.pause();
  }

  Future<void> stop() async {
    await _handler.stop();
    state = state.copyWith(
      isPlaying: false,
      position: Duration.zero,
    );
  }

  Future<void> seek(Duration position) async {
    await _handler.seek(position);
  }

  Future<void> setVolume(double volume) async {
    await _handler.player.setVolume(volume.clamp(0.0, 1.0));
    state = state.copyWith(volume: volume.clamp(0.0, 1.0));
  }

  Future<void> skipToNext() async {
    final nextSong = _queue.next();
    if (nextSong != null) {
      await playSong(nextSong);
    }
  }

  Future<void> skipToPrevious() async {
    final prevSong = _queue.previous();
    if (prevSong != null) {
      await playSong(prevSong);
    }
  }

  void setQueue(List<SongModel> songs, {int startIndex = 0}) {
    _queue.setQueue(songs, startIndex: startIndex);
    state = state.copyWith(queue: _queue.queue);
    _saveQueueState();
  }

  void addToQueue(SongModel song) {
    _queue.addToQueue(song);
    state = state.copyWith(queue: _queue.queue);
    _saveQueueState();
  }

  void insertNext(SongModel song) {
    _queue.insertNext(song);
    state = state.copyWith(queue: _queue.queue);
    _saveQueueState();
  }

  void removeFromQueue(int index) {
    _queue.removeAt(index);
    state = state.copyWith(
      queue: _queue.queue,
      currentIndex: _queue.currentIndex,
    );
    _saveQueueState();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    _queue.reorder(oldIndex, newIndex);
    state = state.copyWith(
      queue: _queue.queue,
      currentIndex: _queue.currentIndex,
    );
    _saveQueueState();
  }

  void clearQueue() {
    _queue.clear();
    state = state.copyWith(
      queue: [],
      currentIndex: -1,
      currentSong: null,
    );
    _saveQueueState();
  }

  void setPlaybackMode(PlaybackMode mode) {
    _queue.setMode(mode);
    state = state.copyWith(playbackMode: mode);
    _saveQueueState();
  }

  Future<void> _saveQueueState() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'robyne', 'queue_state.json'));
      await file.create(recursive: true);
      await file.writeAsString(jsonEncode(_queue.toJson()));
    } catch (_) {}
  }

  Future<void> _restoreQueueState() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'robyne', 'queue_state.json'));
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _queue.fromJson(json);
        state = state.copyWith(
          queue: _queue.queue,
          currentIndex: _queue.currentIndex,
          currentSong: _queue.currentSong,
          playbackMode: _queue.mode,
        );
      }
    } catch (_) {}
  }

  PlaybackQueue get queue => _queue;
}

enum AudioProcessingState {
  idle,
  loading,
  buffering,
  ready,
  completed,
}

class AudioPlayerState {
  final SongModel? currentSong;
  final List<SongModel> queue;
  final int currentIndex;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final AudioProcessingState processingState;
  final PlaybackMode playbackMode;
  final double volume;
  final String? error;

  const AudioPlayerState({
    this.currentSong,
    this.queue = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.processingState = AudioProcessingState.idle,
    this.playbackMode = PlaybackMode.sequential,
    this.volume = 1.0,
    this.error,
  });

  AudioPlayerState copyWith({
    SongModel? currentSong,
    List<SongModel>? queue,
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    AudioProcessingState? processingState,
    PlaybackMode? playbackMode,
    double? volume,
    String? error,
  }) {
    return AudioPlayerState(
      currentSong: currentSong ?? this.currentSong,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      processingState: processingState ?? this.processingState,
      playbackMode: playbackMode ?? this.playbackMode,
      volume: volume ?? this.volume,
      error: error,
    );
  }

  factory AudioPlayerState.initial() => const AudioPlayerState();
}
