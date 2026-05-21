import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class AudioServiceHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;

  AudioServiceHandler() {
    _player.playbackEventStream.listen(_broadcastState);
    _player.durationStream.listen((duration) {
      if (duration != null) {
        mediaItem.add(mediaItem.value!.copyWith(duration: duration));
      }
    });
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });
  }

  void _broadcastState(PlaybackEvent event) {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    ));
  }

  Future<void> setUrl(String url, {String? title, String? artist, String? artUri}) async {
    mediaItem.add(MediaItem(
      id: url,
      title: title ?? 'Unknown',
      artist: artist ?? 'Unknown',
      artUri: artUri != null ? Uri.parse(artUri) : null,
    ));
    await _player.setUrl(url);
  }

  Future<void> setFilePath(String path, {String? title, String? artist, String? artUri}) async {
    mediaItem.add(MediaItem(
      id: path,
      title: title ?? 'Unknown',
      artist: artist ?? 'Unknown',
      artUri: artUri != null ? Uri.parse(artUri) : null,
    ));

    // Check if path contains non-ASCII characters
    final hasNonAscii = path.codeUnits.any((code) => code > 127);

    if (!hasNonAscii) {
      // Simple ASCII path - use directly
      await _player.setFilePath(path);
      return;
    }

    // For paths with Chinese/special characters, copy to temp with ASCII name
    print('Path contains non-ASCII chars, copying to temp...');
    final tempDir = Directory.systemTemp;
    final ext = path.split('.').last;
    final tempFile = File('${tempDir.path}\\robyne_temp_${DateTime.now().millisecondsSinceEpoch}.$ext');

    try {
      await File(path).copy(tempFile.path);
      print('Copied to temp: ${tempFile.path}');
      await _player.setFilePath(tempFile.path);
    } catch (e) {
      print('Error copying/playing temp file: $e');
      rethrow;
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    // Handled by AudioPlayerService
  }

  @override
  Future<void> skipToPrevious() async {
    // Handled by AudioPlayerService
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }

  void dispose() {
    _player.dispose();
  }
}
