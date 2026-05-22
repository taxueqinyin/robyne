import 'package:robyne/shared/models/track.dart';
import 'package:robyne/core/audio/audio_player_service.dart';
import 'package:robyne/core/audio/playback_state.dart';
import 'package:robyne/core/plugin/plugin_registry.dart';
import 'package:logging/logging.dart';

final _log = Logger('PlaybackService');

/// 播放应用服务 - 协调音频播放与插件媒体源解析
class PlaybackService {
  final AudioPlayerService _audioService;
  final PluginRegistry _registry;

  PlaybackService(this._audioService, this._registry);

  Stream<PlaybackState> get stateStream => _audioService.stateStream;
  PlaybackState get state => _audioService.state;

  /// 播放曲目（自动解析远程曲目的媒体源）
  Future<void> play(Track track) async {
    try {
      if (track is LocalTrack) {
        _log.info('Playing local track: ${track.title}');
        await _audioService.playTrack(track);
      } else if (track is RemoteTrack) {
        _log.info('Playing remote track: ${track.title} (plugin: ${track.pluginId})');

        final plugin = _registry.get(track.pluginId);
        if (plugin == null) {
          _log.severe('Plugin not found: ${track.pluginId}');
          throw Exception('Plugin not found: ${track.pluginId}');
        }

        final source = await plugin.getMediaSource(track);
        _log.info('Media source resolved for ${track.title}: ${source.url}');
        await _audioService.playTrack(track, source: source);
      }
    } catch (e) {
      _log.severe('Failed to play track "${track.title}": $e');
      rethrow;
    }
  }

  Future<void> pause() => _audioService.pause();
  Future<void> resume() => _audioService.play();
  Future<void> seek(Duration position) => _audioService.seek(position);
  Future<void> setVolume(double volume) => _audioService.setVolume(volume);
  double get volume => _audioService.volume;
  Future<void> playNext() => _audioService.playNext();
  Future<void> playPrevious() => _audioService.playPrevious();

  void setQueue(List<QueueItem> items, {int startIndex = 0}) =>
      _audioService.setQueue(items, startIndex: startIndex);

  void setRepeatMode(RepeatMode mode) => _audioService.setRepeatMode(mode);
}
